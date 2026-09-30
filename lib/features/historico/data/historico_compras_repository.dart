import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../drift/database.dart';
import '../domain/ida.dart';

class HistoricoComprasRepository {
  HistoricoComprasRepository(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<Ida> finalizar(String listaId) {
    return _db.transaction(() async {
      final lista = await (_db.select(
        _db.listaLocal,
      )..where((l) => l.id.equals(listaId))).getSingle();
      final concluidos =
          await (_db.select(_db.itemLocal)
                ..where(
                  (i) =>
                      i.listaId.equals(listaId) &
                      i.concluido.equals(true) &
                      i.deletadoEm.isNull(),
                )
                ..orderBy([
                  (i) => OrderingTerm.asc(i.ordem),
                  (i) => OrderingTerm.asc(i.id),
                ]))
              .get();
      if (concluidos.isEmpty) {
        throw StateError('Nenhum item concluído para finalizar');
      }
      final agora = DateTime.now().toUtc();
      final idaId = _uuid.v4();
      var total = 0;
      for (final i in concluidos) {
        final preco = i.precoCentavos;
        if (preco != null) total += (i.quantidade * preco).round();
      }
      await _db
          .into(_db.idaCompra)
          .insert(
            IdaCompraCompanion.insert(
              id: idaId,
              listaId: Value(listaId),
              titulo: lista.titulo,
              finalizadaEm: agora,
              totalCentavos: Value(total),
              itensCount: Value(concluidos.length),
            ),
          );
      for (final i in concluidos) {
        await _db
            .into(_db.itemIda)
            .insert(
              ItemIdaCompanion.insert(
                id: _uuid.v4(),
                idaId: idaId,
                nome: i.nome,
                quantidade: Value(i.quantidade),
                unidade: Value(i.unidade),
                categoria: Value(i.categoria),
                precoCentavos: Value(i.precoCentavos),
              ),
            );
      }
      return Ida(
        id: idaId,
        listaId: listaId,
        titulo: lista.titulo,
        finalizadaEm: agora,
        totalCentavos: total,
        itensCount: concluidos.length,
      );
    });
  }

  Stream<List<Ida>> watchIdas() =>
      (_db.select(_db.idaCompra)
            ..orderBy([(t) => OrderingTerm.desc(t.finalizadaEm)]))
          .watch()
          .map((rows) => rows.map(Ida.fromLocal).toList());

  Future<Ida?> ida(String id) async {
    final row = await (_db.select(
      _db.idaCompra,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : Ida.fromLocal(row);
  }

  Future<List<ItemDaIda>> itensDaIda(String idaId) async {
    final rows =
        await (_db.select(_db.itemIda)
              ..where((t) => t.idaId.equals(idaId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.nome),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(ItemDaIda.fromLocal).toList();
  }

  Future<ResumoHistorico> resumo() async {
    final idas = await _db.select(_db.idaCompra).get();
    final total = idas.fold<int>(0, (s, i) => s + i.totalCentavos);
    final n = idas.length;
    return ResumoHistorico(
      totalGeralCentavos: total,
      ticketMedioCentavos: n == 0 ? 0 : (total / n).round(),
      nIdas: n,
    );
  }
}
