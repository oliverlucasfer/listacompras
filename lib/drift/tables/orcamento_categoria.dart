import 'package:drift/drift.dart';

/// Limite de orçamento por categoria (RF-36, F53). Local-only.
///
/// `categoria` guarda o `valor` do enum fechado `CategoriaItem`; `null` em
/// `limiteCentavos` significa categoria sem limite. A PK é a própria
/// categoria — um único limite por categoria.
class OrcamentoCategoria extends Table {
  TextColumn get categoria => text()();
  IntColumn get limiteCentavos => integer().nullable()();

  @override
  Set<Column> get primaryKey => {categoria};

  @override
  List<String> get customConstraints => [
    'CHECK (limite_centavos IS NULL OR '
        '(limite_centavos >= 0 AND limite_centavos <= 99999999))',
  ];
}
