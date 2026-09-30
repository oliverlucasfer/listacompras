import 'package:drift/drift.dart';
import 'ida_compra.dart';

/// Item (snapshot) de uma ida (RF-34). A ida não referencia `item_local`.
class ItemIda extends Table {
  TextColumn get id => text()();
  TextColumn get idaId =>
      text().references(IdaCompra, #id, onDelete: KeyAction.cascade)();
  TextColumn get nome => text()();
  RealColumn get quantidade => real().withDefault(const Constant(1.0))();
  TextColumn get unidade => text().withDefault(const Constant('un'))();
  TextColumn get categoria => text().withDefault(const Constant('outros'))();
  IntColumn get precoCentavos => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (quantidade > 0)',
    "CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz'))",
    "CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios','congelados',"
        "'padaria','bebidas','pet','limpeza','higiene','outros'))",
  ];
}
