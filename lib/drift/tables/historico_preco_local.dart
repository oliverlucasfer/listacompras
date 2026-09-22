import 'package:drift/drift.dart';

/// Histórico local de preços por item (doc 05 §6.3, RF-29, F37).
/// **Não sincroniza** — por dispositivo.
class HistoricoPrecoLocal extends Table {
  TextColumn get nomeNormalizado => text()();
  IntColumn get precoCentavos => integer()();
  TextColumn get unidade => text()();
  DateTimeColumn get registradoEm => dateTime()();

  @override
  Set<Column> get primaryKey => {nomeNormalizado};
}
