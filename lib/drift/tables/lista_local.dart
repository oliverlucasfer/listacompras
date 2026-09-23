import 'package:drift/drift.dart';

/// Espelha `listas` do Postgres (doc 01 §4.1).
/// IDs gerados no cliente (UUID v4, ADR-006).
class ListaLocal extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get titulo => text().withLength(min: 1, max: 120)();
  TextColumn get donoId => text()();
  DateTimeColumn get deletadoEm => dateTime().nullable()();
  DateTimeColumn get arquivadaEm => dateTime().nullable()();
  IntColumn get orcamentoCentavos => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (orcamento_centavos IS NULL OR '
        '(orcamento_centavos >= 0 AND orcamento_centavos <= 99999999))',
  ];
}
