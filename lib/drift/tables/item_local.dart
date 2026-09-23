import 'package:drift/drift.dart';

import 'lista_local.dart';

/// Espelha `itens_lista` do Postgres (doc 01 §4.3).
/// `unidade` e `categoria` restritas aos enums fechados e `quantidade > 0` —
/// barreiras espelhadas do Postgres (`0001_init.sql`, `0006`, `0017`), F39.
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
  IntColumn get precoCentavos => integer().nullable()();
  BoolColumn get concluido => boolean().withDefault(const Constant(false))();
  IntColumn get ordem => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletadoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (quantidade > 0)',
    "CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','dz'))",
    "CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',"
        "'congelados','padaria','bebidas','pet','limpeza','higiene','outros'))",
    'CHECK (preco_centavos IS NULL OR '
        '(preco_centavos >= 0 AND preco_centavos <= 99999999))',
  ];
}
