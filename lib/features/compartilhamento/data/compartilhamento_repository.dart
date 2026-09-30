import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/usuario_local.dart';
import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';
import '../../listas/domain/lista.dart';
import '../domain/lista_compartilhada.dart';

class CompartilhamentoRepository {
  CompartilhamentoRepository(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<ListaCompartilhada> exportarLista(String listaId) async {
    final lista = await (_db.select(
      _db.listaLocal,
    )..where((l) => l.id.equals(listaId))).getSingle();
    final itens =
        await (_db.select(_db.itemLocal)
              ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
              ..orderBy([
                (i) => OrderingTerm.asc(i.ordem),
                (i) => OrderingTerm.asc(i.id),
              ]))
            .get();
    return ListaCompartilhada(
      titulo: lista.titulo,
      itens: [
        for (final i in itens)
          ItemCompartilhado(
            nome: i.nome,
            quantidade: i.quantidade,
            unidade: Unidade.fromValor(i.unidade),
            categoria: CategoriaItem.fromValor(i.categoria),
            concluido: i.concluido,
            ordem: i.ordem,
            precoCentavos: i.precoCentavos,
          ),
      ],
    );
  }

  Future<Lista> importarLista(
    ListaCompartilhada origem, {
    required String titulo,
  }) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      final listaId = _uuid.v4();
      await _db
          .into(_db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: listaId,
              createdAt: agora,
              updatedAt: agora,
              titulo: titulo,
              donoId: idLocal,
            ),
          );
      var ordem = 0;
      for (final i in origem.itens) {
        await _db
            .into(_db.itemLocal)
            .insert(
              ItemLocalCompanion.insert(
                id: _uuid.v4(),
                createdAt: agora,
                updatedAt: agora,
                listaId: listaId,
                nome: i.nome,
                quantidade: Value(i.quantidade),
                unidade: Value(i.unidade.valor),
                categoria: Value(i.categoria.valor),
                precoCentavos: Value(i.precoCentavos),
                concluido: Value(i.concluido),
                ordem: Value(ordem++),
              ),
            );
      }
      return Lista(
        id: listaId,
        titulo: titulo,
        donoId: idLocal,
        criadoEm: agora,
        atualizadoEm: agora,
      );
    });
  }
}
