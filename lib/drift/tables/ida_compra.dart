import 'package:drift/drift.dart';

/// Snapshot imutável de uma compra finalizada (RF-34). Local-only.
class IdaCompra extends Table {
  TextColumn get id => text()();
  TextColumn get listaId => text().nullable()();
  TextColumn get titulo => text()();
  DateTimeColumn get finalizadaEm => dateTime()();
  IntColumn get totalCentavos => integer().withDefault(const Constant(0))();
  IntColumn get itensCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
