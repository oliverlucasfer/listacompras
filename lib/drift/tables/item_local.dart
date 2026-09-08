import 'package:drift/drift.dart';

import 'lista_local.dart';

/// Espelha `itens_lista` do Postgres (doc 01 §4.3).
/// `unidade` restrita ao enum fechado (doc 01 §3.1): un, kg, g, l, ml,
/// caixa, pacote, pct, dz — validação Dart em lib/features/listas/domain.
/// `categoria` restrita ao enum fechado (doc 01 §3.2, ADR-011) — F6-T02.
class ItemLocal extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get listaId =>
      text().references(ListaLocal, #id, onDelete: KeyAction.cascade)();
  TextColumn get nome => text().withLength(min: 1, max: 120)();
  RealColumn get quantidade => real().withDefault(const Constant(1.0))();
  TextColumn get unidade => text().withDefault(const Constant('un'))();
  TextColumn get categoria => text().withDefault(const Constant('outros'))();
  BoolColumn get concluido => boolean().withDefault(const Constant(false))();
  IntColumn get ordem => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletadoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
