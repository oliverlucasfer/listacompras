import '../../../core/texto/normalizar.dart';
import '../../../drift/database.dart';
import '../domain/historico_preco.dart';
import '../../../core/dominio/unidade.dart';

/// Histórico local de preços (RF-29). Local-only: não enfileira mutação.
class HistoricoPrecosRepository {
  HistoricoPrecosRepository(this._db);

  final AppDatabase _db;

  Future<void> registrar({
    required String nome,
    required int precoCentavos,
    required Unidade unidade,
    DateTime? quando,
  }) async {
    await _db
        .into(_db.historicoPrecoLocal)
        .insertOnConflictUpdate(
          HistoricoPrecoLocalCompanion.insert(
            nomeNormalizado: normalizarTexto(nome),
            precoCentavos: precoCentavos,
            unidade: unidade.valor,
            registradoEm: quando ?? DateTime.now().toUtc(),
          ),
        );
  }

  Future<HistoricoPreco?> porNome(String nome) async {
    final row =
        await (_db.select(_db.historicoPrecoLocal)
              ..where((h) => h.nomeNormalizado.equals(normalizarTexto(nome))))
            .getSingleOrNull();
    return row == null ? null : HistoricoPreco.fromLocal(row);
  }
}
