import 'package:drift/drift.dart';

import '../../../core/dominio/categoria.dart';
import '../../../drift/database.dart';

/// Limites de orçamento por categoria (RF-36, F53). Local-only: não há rede
/// nem sincronização; a fonte da verdade é o Drift.
class LimitesCategoriaRepository {
  LimitesCategoriaRepository(this._db);

  final AppDatabase _db;

  /// Define o limite de [categoria] em centavos; `null` remove o limite.
  Future<void> definir(CategoriaItem categoria, {int? centavos}) async {
    if (centavos == null) {
      await (_db.delete(
        _db.orcamentoCategoria,
      )..where((t) => t.categoria.equals(categoria.valor))).go();
      return;
    }
    await _db
        .into(_db.orcamentoCategoria)
        .insertOnConflictUpdate(
          OrcamentoCategoriaCompanion.insert(
            categoria: categoria.valor,
            limiteCentavos: Value(centavos),
          ),
        );
  }

  /// Limites definidos, por categoria (categorias sem limite ficam de fora).
  Future<Map<CategoriaItem, int>> limites() async {
    final rows = await _db.select(_db.orcamentoCategoria).get();
    return _mapear(rows);
  }

  /// Observa os limites definidos, por categoria.
  Stream<Map<CategoriaItem, int>> watchLimites() =>
      _db.select(_db.orcamentoCategoria).watch().map(_mapear);

  Map<CategoriaItem, int> _mapear(List<OrcamentoCategoriaData> rows) => {
    for (final row in rows)
      if (row.limiteCentavos != null)
        CategoriaItem.fromValor(row.categoria): row.limiteCentavos!,
  };
}
