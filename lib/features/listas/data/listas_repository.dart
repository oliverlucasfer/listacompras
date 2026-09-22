import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/texto/normalizar.dart';
import '../../../drift/database.dart';
import '../domain/categoria.dart';
import '../domain/item.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';
import '../domain/resultado_dedup.dart';
import '../domain/sugestao_item.dart';
import '../domain/unidade.dart';
import 'historico_precos_repository.dart';

/// Repositório de listas/itens (doc 03 §2, RF-02/RF-03/RF-04): toda
/// escrita aplica no Drift (fonte de verdade local) e enfileira a mutação
/// com `ts_local` para o Sync Engine (F4-T03). Leitura expõe Streams do
/// Drift — UI reativa, nunca bloqueia em rede.
class ListasRepository {
  ListasRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // ---- Leitura (Streams do Drift) ----

  Stream<List<Lista>> watchListas() {
    return (_db.select(_db.listaLocal)
          ..where((l) => l.deletadoEm.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.updatedAt)]))
        .watch()
        .map((rows) => rows.map(Lista.fromLocal).toList());
  }

  Stream<Lista?> watchLista(String id) {
    return (_db.select(_db.listaLocal)..where((l) => l.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : Lista.fromLocal(row));
  }

  Stream<List<Item>> watchItensDaLista(String listaId) {
    return (_db.select(_db.itemLocal)
          ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
          ..orderBy([
            (i) => OrderingTerm.asc(i.ordem),
            (i) => OrderingTerm.asc(i.id),
          ]))
        .watch()
        .map((rows) => rows.map(Item.fromLocal).toList());
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

  Stream<List<ListaComContagem>> watchListasComContagem() {
    return _db
        .customSelect(
          '''
    SELECT l.id, l.titulo, l.dono_id, l.created_at, l.updated_at,
           l.arquivada_em,
           COUNT(i.id) AS total_itens,
           COUNT(CASE WHEN i.concluido = 1 THEN 1 END) AS itens_concluidos
    FROM lista_local l
    LEFT JOIN item_local i ON i.lista_id = l.id AND i.deletado_em IS NULL
    WHERE l.deletado_em IS NULL
    GROUP BY l.id
    ORDER BY l.updated_at DESC
  ''',
          readsFrom: {_db.listaLocal, _db.itemLocal},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ListaComContagem(
                  lista: Lista(
                    id: row.read<String>('id'),
                    titulo: row.read<String>('titulo'),
                    donoId: row.read<String>('dono_id'),
                    criadoEm: row.read<DateTime>('created_at'),
                    atualizadoEm: row.read<DateTime>('updated_at'),
                    arquivadaEm: row.read<DateTime?>('arquivada_em'),
                  ),
                  totalItens: row.read<int>('total_itens'),
                  concluidos: row.read<int>('itens_concluidos'),
                ),
              )
              .toList(),
        );
  }

  // ---- Escritas: local primeiro + fila (doc 03 §1/§3) ----

  Future<Lista> criarLista({
    required String titulo,
    required String donoId,
  }) async {
    final agora = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db
        .into(_db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: id,
            createdAt: agora,
            updatedAt: agora,
            titulo: titulo,
            donoId: donoId,
          ),
        );
    await _enfileirar(
      tabela: 'listas',
      operacao: 'INSERT',
      registroId: id,
      listaId: id,
      tsLocal: agora,
      payload: await _payloadLista(id),
    );
    return Lista(
      id: id,
      titulo: titulo,
      donoId: donoId,
      criadoEm: agora,
      atualizadoEm: agora,
    );
  }

  Future<void> renomearLista({
    required String id,
    required String titulo,
  }) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
      ListaLocalCompanion(titulo: Value(titulo), updatedAt: Value(agora)),
    );
    await _enfileirar(
      tabela: 'listas',
      operacao: 'UPDATE',
      registroId: id,
      listaId: id,
      tsLocal: agora,
      payload: await _payloadLista(id),
    );
  }

  Future<void> excluirLista(String id) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
      ListaLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
    );
    await _enfileirar(
      tabela: 'listas',
      operacao: 'DELETE_SOFT',
      registroId: id,
      listaId: id,
      tsLocal: agora,
      payload: await _payloadLista(id),
    );
  }

  /// Arquiva/desarquiva a lista (RF-22): estado global, só o dono (o
  /// trigger do servidor garante). Offline-first: Drift + fila.
  Future<void> definirArquivada(String id, {required bool arquivada}) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
      ListaLocalCompanion(
        arquivadaEm: Value(arquivada ? agora : null),
        updatedAt: Value(agora),
      ),
    );
    await _enfileirar(
      tabela: 'listas',
      operacao: 'UPDATE',
      registroId: id,
      listaId: id,
      tsLocal: agora,
      payload: await _payloadLista(id, incluirArquivo: true),
    );
  }

  /// Define/limpa o orçamento da lista (RF-28, F36). Offline-first: Drift +
  /// fila. `centavos == null` remove o orçamento; `0` é um orçamento válido.
  Future<void> definirOrcamento(String id, {required int? centavos}) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
      ListaLocalCompanion(
        orcamentoCentavos: Value(centavos),
        updatedAt: Value(agora),
      ),
    );
    await _enfileirar(
      tabela: 'listas',
      operacao: 'UPDATE',
      registroId: id,
      listaId: id,
      tsLocal: agora,
      payload: await _payloadLista(id),
    );
  }

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
    await _enfileirar(
      tabela: 'itens_lista',
      operacao: 'INSERT',
      registroId: id,
      listaId: listaId,
      tsLocal: agora,
      payload: await _payloadItem(id),
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
  }) async {
    final itens =
        await (_db.select(_db.itemLocal)
              ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
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
        );
        return ResultadoDedup.somado;
      }
      await editarItem(existente.id, quantidade: quantidade, unidade: unidade);
      return ResultadoDedup.substituido;
    }
    await adicionarItem(
      listaId: listaId,
      nome: nome,
      quantidade: quantidade,
      unidade: unidade,
      categoria: categoria,
    );
    return ResultadoDedup.adicionado;
  }

  /// Adiciona um lote de itens (RF-23), um a um pela dedup. Copia nome/
  /// quantidade/unidade/categoria; **ignora preço e concluído**.
  Future<void> adicionarItensDedup(String listaId, Iterable<Item> itens) async {
    for (final item in itens) {
      await adicionarItemDedup(
        listaId: listaId,
        nome: item.nome,
        quantidade: item.quantidade,
        unidade: item.unidade,
        categoria: item.categoria,
      );
    }
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
    final agora = DateTime.now().toUtc();
    final anterior = await _lerItem(id);
    await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
      ItemLocalCompanion(
        nome: nome == null ? const Value.absent() : Value(nome),
        quantidade: quantidade == null
            ? const Value.absent()
            : Value(quantidade),
        unidade: unidade == null ? const Value.absent() : Value(unidade.valor),
        categoria: categoria == null
            ? const Value.absent()
            : Value(categoria.valor),
        concluido: concluido == null ? const Value.absent() : Value(concluido),
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
    // de dedup, mudança de quantidade). Local-only — não enfileira mutação;
    // marcar sem preço não registra e desmarcar não apaga.
    if (item.concluido &&
        item.precoCentavos != null &&
        (!anterior.concluido || anterior.precoCentavos != item.precoCentavos)) {
      await HistoricoPrecosRepository(_db).registrar(
        nome: item.nome,
        precoCentavos: item.precoCentavos!,
        unidade: Unidade.fromValor(item.unidade),
        quando: agora,
      );
    }
    await _enfileirar(
      tabela: 'itens_lista',
      operacao: 'UPDATE',
      registroId: id,
      listaId: item.listaId,
      tsLocal: agora,
      payload: await _payloadItem(id),
    );
  }

  Future<void> removerItem(String id) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
      ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
    );
    final item = await _lerItem(id);
    await _enfileirar(
      tabela: 'itens_lista',
      operacao: 'DELETE_SOFT',
      registroId: id,
      listaId: item.listaId,
      tsLocal: agora,
      payload: await _payloadItem(id),
    );
  }

  Future<void> restaurarItem(String id) async {
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
      ItemLocalCompanion(
        deletadoEm: const Value(null),
        updatedAt: Value(agora),
      ),
    );
    final item = await _lerItem(id);
    await _enfileirar(
      tabela: 'itens_lista',
      operacao: 'UPDATE',
      registroId: id,
      listaId: item.listaId,
      tsLocal: agora,
      payload: await _payloadItem(id),
    );
  }

  /// Reordena os itens ativos (doc 05 §6.3, RF-05): grava a nova `ordem`
  /// e enfileira UPDATE apenas para as linhas que mudaram de posição.
  Future<void> reordenarItens(String listaId, List<String> idsOrdenados) async {
    final itens = await (_db.select(
      _db.itemLocal,
    )..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())).get();
    final agora = DateTime.now().toUtc();
    for (var posicao = 0; posicao < idsOrdenados.length; posicao++) {
      final id = idsOrdenados[posicao];
      final item = itens.where((i) => i.id == id).firstOrNull;
      if (item == null || item.ordem == posicao) continue;
      await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
        ItemLocalCompanion(ordem: Value(posicao), updatedAt: Value(agora)),
      );
      await _enfileirar(
        tabela: 'itens_lista',
        operacao: 'UPDATE',
        registroId: id,
        listaId: listaId,
        tsLocal: agora,
        payload: await _payloadItem(id),
      );
    }
  }

  Future<void> desmarcarTodos(String listaId) async {
    final concluidos =
        await (_db.select(_db.itemLocal)..where(
              (i) =>
                  i.listaId.equals(listaId) &
                  i.deletadoEm.isNull() &
                  i.concluido.equals(true),
            ))
            .get();
    final agora = DateTime.now().toUtc();
    for (final item in concluidos) {
      await (_db.update(
        _db.itemLocal,
      )..where((i) => i.id.equals(item.id))).write(
        ItemLocalCompanion(
          concluido: const Value(false),
          updatedAt: Value(agora),
        ),
      );
      await _enfileirar(
        tabela: 'itens_lista',
        operacao: 'UPDATE',
        registroId: item.id,
        listaId: listaId,
        tsLocal: agora,
        payload: await _payloadItem(item.id),
      );
    }
  }

  /// Remove (soft delete) os concluídos e devolve os itens removidos para o
  /// undo da UI restaurar sem perder `id`/`ordem` (F14-T05).
  Future<List<Item>> limparConcluidos(String listaId) async {
    final concluidos =
        await (_db.select(_db.itemLocal)..where(
              (i) =>
                  i.listaId.equals(listaId) &
                  i.deletadoEm.isNull() &
                  i.concluido.equals(true),
            ))
            .get();
    final agora = DateTime.now().toUtc();
    for (final item in concluidos) {
      await (_db.update(
        _db.itemLocal,
      )..where((i) => i.id.equals(item.id))).write(
        ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
      await _enfileirar(
        tabela: 'itens_lista',
        operacao: 'DELETE_SOFT',
        registroId: item.id,
        listaId: listaId,
        tsLocal: agora,
        payload: await _payloadItem(item.id),
      );
    }
    return concluidos.map(Item.fromLocal).toList();
  }

  /// Duplica uma lista a partir dos itens **pendentes** (RF-20, "comprar de
  /// novo"): cria uma lista nova do `donoId` e copia nome/quantidade/unidade/
  /// categoria de cada pendente, na ordem original; a origem não é tocada.
  /// Offline-first: reusa `criarLista`/`adicionarItem` e a fila de mutações.
  Future<Lista> duplicarLista({
    required String origemId,
    required String titulo,
    required String donoId,
  }) async {
    final pendentes =
        await (_db.select(_db.itemLocal)
              ..where(
                (i) =>
                    i.listaId.equals(origemId) &
                    i.deletadoEm.isNull() &
                    i.concluido.equals(false),
              )
              ..orderBy([
                (i) => OrderingTerm.asc(i.ordem),
                (i) => OrderingTerm.asc(i.id),
              ]))
            .get();
    if (pendentes.isEmpty) {
      throw StateError('não há itens pendentes para duplicar');
    }

    final nova = await criarLista(titulo: titulo, donoId: donoId);
    for (final item in pendentes) {
      await adicionarItem(
        listaId: nova.id,
        nome: item.nome,
        quantidade: item.quantidade,
        unidade: Unidade.fromValor(item.unidade),
        categoria: CategoriaItem.fromValor(item.categoria),
        precoCentavos: item.precoCentavos,
      );
    }
    return nova;
  }

  // ---- Internos ----

  Future<Map<String, Object?>> _payloadLista(
    String id, {
    bool incluirArquivo = false,
  }) async {
    final l = await (_db.select(
      _db.listaLocal,
    )..where((l) => l.id.equals(id))).getSingle();
    return {
      'id': l.id,
      'titulo': l.titulo,
      'dono_id': l.donoId,
      'created_at': _iso(l.createdAt),
      'updated_at': _iso(l.updatedAt),
      'deletado_em': l.deletadoEm == null ? null : _iso(l.deletadoEm!),
      'orcamento_centavos': l.orcamentoCentavos,
      if (incluirArquivo)
        'arquivada_em': l.arquivadaEm == null ? null : _iso(l.arquivadaEm!),
    };
  }

  Future<Map<String, Object?>> _payloadItem(String id) async {
    final i = await _lerItem(id);
    return {
      'id': i.id,
      'lista_id': i.listaId,
      'nome': i.nome,
      'quantidade': i.quantidade,
      'unidade': i.unidade,
      'categoria': i.categoria,
      'concluido': i.concluido,
      'ordem': i.ordem,
      'preco_centavos': i.precoCentavos,
      'created_at': _iso(i.createdAt),
      'updated_at': _iso(i.updatedAt),
      'deletado_em': i.deletadoEm == null ? null : _iso(i.deletadoEm!),
    };
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();

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

  Future<void> _enfileirar({
    required String tabela,
    required String operacao,
    required String registroId,
    required String listaId,
    required DateTime tsLocal,
    required Map<String, Object?> payload,
  }) {
    return _db
        .into(_db.mutacaoPendente)
        .insert(
          MutacaoPendenteCompanion.insert(
            tabela: tabela,
            operacao: operacao,
            registroId: registroId,
            payload: jsonEncode(payload),
            tsLocal: tsLocal,
            listaId: listaId,
          ),
        );
  }
}
