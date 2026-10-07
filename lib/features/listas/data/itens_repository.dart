import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../core/texto/normalizar.dart';
import '../../../drift/database.dart';
import '../domain/item.dart';
import '../domain/resultado_dedup.dart';
import '../domain/sugestao_item.dart';
import 'historico_precos_repository.dart';
import 'mappers.dart';

/// Repositório dos **itens** de uma lista (RF-03, doc 05 §6.3): toda escrita
/// aplica no Drift (fonte de verdade local) e a leitura expõe Streams — UI
/// reativa, nunca bloqueia em rede. Independente de [ListasRepository]; a UI o
/// consome via `itensRepositoryProvider`.
class ItensRepository {
  ItensRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // ---- Leitura (Streams do Drift) ----

  Stream<List<Item>> watchItensDaLista(String listaId) {
    return (_db.select(_db.itemLocal)
          ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
          ..orderBy([
            (i) => OrderingTerm.asc(i.ordem),
            (i) => OrderingTerm.asc(i.id),
          ]))
        .watch()
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  /// Sugestões de itens frequentes (RF-19): ranking derivado do histórico
  /// local. Peso 2 para a lista aberta, 1 para as demais; apenas nomes
  /// **pendentes** da lista aberta são excluídos (concluídos contam com peso
  /// 2); limiar >= 2 e limite de 8. Zero rede.
  ///
  /// O agrupamento é feito em Dart com [normalizarTexto] (remove acento pt-BR,
  /// caixa e colapsa espaços): o `lower()` do SQLite é ASCII-only e não
  /// colapsaria variantes acentuadas como `Café`/`CAFÉ`. O `customSelect`
  /// apenas lê as linhas candidatas e o `.watch()` mantém a reatividade.
  Stream<List<SugestaoItem>> watchItensFrequentes(String listaId) {
    return _db
        .customSelect(
          '''
    SELECT i.nome AS nome, i.lista_id AS lista_id, i.concluido AS concluido
    FROM item_local i
    JOIN lista_local l ON l.id = i.lista_id AND l.deletado_em IS NULL
    WHERE i.deletado_em IS NULL
  ''',
          readsFrom: {_db.itemLocal, _db.listaLocal},
        )
        .watch()
        .map((rows) {
          final pendentesNaListaAberta = <String>{};
          final pesos = <String, int>{};
          final representantes = <String, String>{};
          for (final row in rows) {
            final nome = row.read<String>('nome');
            final chave = normalizarTexto(nome);
            final naListaAberta = row.read<String>('lista_id') == listaId;
            final concluido = row.read<bool>('concluido');
            if (naListaAberta && !concluido) {
              pendentesNaListaAberta.add(chave);
            }
            pesos[chave] = (pesos[chave] ?? 0) + (naListaAberta ? 2 : 1);
            representantes.putIfAbsent(chave, () => nome);
          }
          final sugestoes = <SugestaoItem>[];
          for (final entry in pesos.entries) {
            if (pendentesNaListaAberta.contains(entry.key)) continue;
            if (entry.value < 2) continue;
            sugestoes.add(
              SugestaoItem(nome: representantes[entry.key]!, peso: entry.value),
            );
          }
          sugestoes.sort((a, b) {
            final porPeso = b.peso.compareTo(a.peso);
            if (porPeso != 0) return porPeso;
            return normalizarTexto(a.nome).compareTo(normalizarTexto(b.nome));
          });
          return sugestoes.take(8).toList();
        });
  }

  // ---- Escritas (o Drift local é a fonte de verdade) ----

  Future<Item> adicionarItem({
    required String listaId,
    required String nome,
    double quantidade = 1.0,
    Unidade unidade = Unidade.un,
    CategoriaItem categoria = CategoriaItem.outros,
    int? precoCentavos,
  }) async {
    if (quantidade <= 0) {
      throw ArgumentError('quantidade deve ser maior que zero');
    }
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      final id = _uuid.v4();
      final ordem = await _proximaOrdem(listaId);
      await _db
          .into(_db.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: id,
              createdAt: agora,
              updatedAt: agora,
              listaId: listaId,
              nome: nome,
              quantidade: Value(quantidade),
              unidade: Value(unidade.valor),
              categoria: Value(categoria.valor),
              precoCentavos: Value(precoCentavos),
              ordem: Value(ordem),
            ),
          );
      return Item(
        id: id,
        listaId: listaId,
        nome: nome,
        quantidade: quantidade,
        unidade: unidade,
        categoria: categoria,
        concluido: false,
        ordem: ordem,
        criadoEm: agora,
        atualizadoEm: agora,
        precoCentavos: precoCentavos,
      );
    });
  }

  /// Adiciona um item aplicando a dedup do app (RF-10): compara o nome
  /// **normalizado** com os itens ativos da lista; mesmo nome e mesma unidade
  /// → soma a quantidade; unidade diferente → substitui quantidade/unidade.
  /// Sem existente → insere com a `categoria` recebida.
  Future<ResultadoDedup> adicionarItemDedup({
    required String listaId,
    required String nome,
    required double quantidade,
    required Unidade unidade,
    required CategoriaItem categoria,
    int? precoCentavos,
  }) {
    // RF-10: a leitura dos itens ativos e a escrita devem ser atômicas; sem a
    // transação, duas chamadas concorrentes poderiam não achar o nome e inserir,
    // violando `uq_item_ativo`. `editarItem`/`adicionarItem` abrem transações
    // aninhadas (savepoints) do Drift.
    return _db.transaction<ResultadoDedup>(() async {
      final itens =
          await (_db.select(_db.itemLocal)
                ..where(
                  (i) => i.listaId.equals(listaId) & i.deletadoEm.isNull(),
                )
                ..orderBy([
                  (i) => OrderingTerm.asc(i.ordem),
                  (i) => OrderingTerm.asc(i.id),
                ]))
              .get();
      final alvo = normalizarTexto(nome);
      ItemLocalData? existente;
      for (final i in itens) {
        if (normalizarTexto(i.nome) == alvo) {
          existente = i;
          break;
        }
      }
      if (existente != null) {
        if (existente.unidade == unidade.valor) {
          await editarItem(
            existente.id,
            quantidade: existente.quantidade + quantidade,
            precoCentavos: precoCentavos,
          );
          return ResultadoDedup.somado;
        }
        await editarItem(
          existente.id,
          quantidade: quantidade,
          unidade: unidade,
          precoCentavos: precoCentavos,
        );
        return ResultadoDedup.substituido;
      }
      await adicionarItem(
        listaId: listaId,
        nome: nome,
        quantidade: quantidade,
        unidade: unidade,
        categoria: categoria,
        precoCentavos: precoCentavos,
      );
      return ResultadoDedup.adicionado;
    });
  }

  /// Adiciona um lote de itens (RF-23), um a um pela dedup, em **uma** leitura
  /// e **uma** transação. Copia nome/quantidade/unidade/categoria; ignora
  /// preço e concluído.
  Future<void> adicionarItensDedup(String listaId, Iterable<Item> itens) {
    return _db.transaction(() async {
      final ativos =
          await (_db.select(_db.itemLocal)
                ..where(
                  (i) => i.listaId.equals(listaId) & i.deletadoEm.isNull(),
                )
                ..orderBy([
                  (i) => OrderingTerm.asc(i.ordem),
                  (i) => OrderingTerm.asc(i.id),
                ]))
              .get();
      final porNome = <String, ({String id, double qtd, String unidade})>{
        for (final i in ativos)
          normalizarTexto(i.nome): (
            id: i.id,
            qtd: i.quantidade,
            unidade: i.unidade,
          ),
      };
      var proxima = ativos.fold<int>(
        0,
        (maior, i) => i.ordem >= maior ? i.ordem + 1 : maior,
      );
      final agora = DateTime.now().toUtc();
      for (final item in itens) {
        if (item.quantidade <= 0) {
          throw ArgumentError('quantidade deve ser maior que zero');
        }
        final chave = normalizarTexto(item.nome);
        final existente = porNome[chave];
        if (existente != null) {
          final mesmaUnidade = existente.unidade == item.unidade.valor;
          final qtd = mesmaUnidade
              ? existente.qtd + item.quantidade
              : item.quantidade;
          await (_db.update(
            _db.itemLocal,
          )..where((i) => i.id.equals(existente.id))).write(
            ItemLocalCompanion(
              quantidade: Value(qtd),
              unidade: Value(item.unidade.valor),
              updatedAt: Value(agora),
            ),
          );
          porNome[chave] = (
            id: existente.id,
            qtd: qtd,
            unidade: item.unidade.valor,
          );
          continue;
        }
        final id = _uuid.v4();
        await _db
            .into(_db.itemLocal)
            .insert(
              ItemLocalCompanion.insert(
                id: id,
                createdAt: agora,
                updatedAt: agora,
                listaId: listaId,
                nome: item.nome,
                quantidade: Value(item.quantidade),
                unidade: Value(item.unidade.valor),
                categoria: Value(item.categoria.valor),
                ordem: Value(proxima++),
              ),
            );
        porNome[chave] = (
          id: id,
          qtd: item.quantidade,
          unidade: item.unidade.valor,
        );
      }
    });
  }

  Future<void> editarItem(
    String id, {
    String? nome,
    double? quantidade,
    Unidade? unidade,
    CategoriaItem? categoria,
    bool? concluido,
    int? precoCentavos,
    bool limparPreco = false,
  }) async {
    if (quantidade != null && quantidade <= 0) {
      throw ArgumentError('quantidade deve ser maior que zero');
    }
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      final anterior = await _lerItem(id);
      await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
        ItemLocalCompanion(
          nome: nome == null ? const Value.absent() : Value(nome),
          quantidade: quantidade == null
              ? const Value.absent()
              : Value(quantidade),
          unidade: unidade == null
              ? const Value.absent()
              : Value(unidade.valor),
          categoria: categoria == null
              ? const Value.absent()
              : Value(categoria.valor),
          concluido: concluido == null
              ? const Value.absent()
              : Value(concluido),
          precoCentavos: precoCentavos != null
              ? Value(precoCentavos)
              : (limparPreco ? const Value(null) : const Value.absent()),
          updatedAt: Value(agora),
        ),
      );
      final item = await _lerItem(id);
      // Histórico local de preços (RF-29, F37): registra na transição para
      // concluído com preço, ou quando o preço muda com o item já concluído.
      // Evita atualizar `registradoEm` em edições não relacionadas (ex.: merge
      // de dedup, mudança de quantidade). Marcar sem preço não registra e
      // desmarcar não apaga.
      if (item.concluido &&
          item.precoCentavos != null &&
          (!anterior.concluido ||
              anterior.precoCentavos != item.precoCentavos)) {
        await HistoricoPrecosRepository(_db).registrar(
          nome: item.nome,
          precoCentavos: item.precoCentavos!,
          unidade: Unidade.fromValor(item.unidade),
          quando: agora,
        );
      }
    });
  }

  /// Remove (soft delete) o item por id. Idempotente: id inexistente afeta 0
  /// linhas e não lança.
  Future<void> removerItem(String id) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
        ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
    });
  }

  /// Restaura um item removido por id. Idempotente (id inexistente = no-op).
  Future<void> restaurarItem(String id) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
        ItemLocalCompanion(
          deletadoEm: const Value(null),
          updatedAt: Value(agora),
        ),
      );
    });
  }

  /// Reordena os itens ativos (doc 05 §6.3, RF-05): grava a nova `ordem`
  /// apenas para as linhas que mudaram de posição.
  Future<void> reordenarItens(String listaId, List<String> idsOrdenados) {
    return _db.transaction(() async {
      final itens = await (_db.select(
        _db.itemLocal,
      )..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())).get();
      final ordemAtual = {for (final i in itens) i.id: i.ordem};
      final agora = DateTime.now().toUtc();
      final mudancas = <(String, int)>[];
      for (var posicao = 0; posicao < idsOrdenados.length; posicao++) {
        final id = idsOrdenados[posicao];
        if (ordemAtual[id] == null || ordemAtual[id] == posicao) continue;
        mudancas.add((id, posicao));
      }
      if (mudancas.isEmpty) return;
      await _db.batch((b) {
        for (final (id, ordem) in mudancas) {
          b.update(
            _db.itemLocal,
            ItemLocalCompanion(ordem: Value(ordem), updatedAt: Value(agora)),
            where: (i) => i.id.equals(id),
          );
        }
      });
    });
  }

  Future<void> desmarcarTodos(String listaId) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.itemLocal)..where(
            (i) =>
                i.listaId.equals(listaId) &
                i.deletadoEm.isNull() &
                i.concluido.equals(true),
          ))
          .write(
            ItemLocalCompanion(
              concluido: const Value(false),
              updatedAt: Value(agora),
            ),
          );
    });
  }

  /// Remove (soft delete) os concluídos e devolve os itens removidos para o
  /// undo da UI restaurar sem perder `id`/`ordem` (F14-T05).
  Future<List<Item>> limparConcluidos(String listaId) {
    return _db.transaction(() async {
      final concluidos =
          await (_db.select(_db.itemLocal)..where(
                (i) =>
                    i.listaId.equals(listaId) &
                    i.deletadoEm.isNull() &
                    i.concluido.equals(true),
              ))
              .get();
      if (concluidos.isEmpty) return const <Item>[];
      final agora = DateTime.now().toUtc();
      final ids = [for (final i in concluidos) i.id];
      await (_db.update(_db.itemLocal)..where((i) => i.id.isIn(ids))).write(
        ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
      return concluidos.map((r) => r.toDomain()).toList();
    });
  }

  // ---- Internos ----

  Future<int> _proximaOrdem(String listaId) async {
    final query = _db.selectOnly(_db.itemLocal)
      ..addColumns([_db.itemLocal.ordem.max()])
      ..where(
        _db.itemLocal.listaId.equals(listaId) &
            _db.itemLocal.deletadoEm.isNull(),
      );
    final row = await query.getSingle();
    return (row.read(_db.itemLocal.ordem.max()) ?? -1) + 1;
  }

  Future<ItemLocalData> _lerItem(String id) =>
      (_db.select(_db.itemLocal)..where((i) => i.id.equals(id))).getSingle();
}
