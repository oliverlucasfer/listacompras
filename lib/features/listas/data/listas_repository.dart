import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../drift/database.dart';
import '../domain/item.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';
import '../domain/unidade.dart';

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

  Stream<List<ListaComContagem>> watchListasComContagem() {
    return _db
        .customSelect(
          '''
    SELECT l.id, l.titulo, l.dono_id, l.created_at, l.updated_at,
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

  Future<Item> adicionarItem({
    required String listaId,
    required String nome,
    double quantidade = 1.0,
    Unidade unidade = Unidade.un,
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
      concluido: false,
      ordem: ordem,
      criadoEm: agora,
      atualizadoEm: agora,
    );
  }

  Future<void> editarItem(
    String id, {
    String? nome,
    double? quantidade,
    Unidade? unidade,
    bool? concluido,
  }) async {
    if (quantidade != null && quantidade <= 0) {
      throw ArgumentError('quantidade deve ser maior que zero');
    }
    final agora = DateTime.now().toUtc();
    await (_db.update(_db.itemLocal)..where((i) => i.id.equals(id))).write(
      ItemLocalCompanion(
        nome: nome == null ? const Value.absent() : Value(nome),
        quantidade: quantidade == null
            ? const Value.absent()
            : Value(quantidade),
        unidade: unidade == null ? const Value.absent() : Value(unidade.valor),
        concluido: concluido == null ? const Value.absent() : Value(concluido),
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

  Future<void> limparConcluidos(String listaId) async {
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
  }

  // ---- Internos ----

  Future<Map<String, Object?>> _payloadLista(String id) async {
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
      'concluido': i.concluido,
      'ordem': i.ordem,
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
