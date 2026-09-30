import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('deve_ter_schema_v12_quando_abre', () {
    expect(db.schemaVersion, 12);
  });

  test('deve_gravar_ida_e_item_quando_insere', () async {
    await db
        .into(db.idaCompra)
        .insert(
          IdaCompraCompanion.insert(
            id: 'ida-1',
            titulo: 'Semana',
            finalizadaEm: DateTime.utc(2026, 9, 30),
          ),
        );
    await db
        .into(db.itemIda)
        .insert(
          ItemIdaCompanion.insert(
            id: 'item-1',
            idaId: 'ida-1',
            nome: 'Arroz',
            precoCentavos: const Value(549),
          ),
        );
    final itens = await db.select(db.itemIda).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 1.0);
    expect(itens.single.unidade, 'un');
    expect(itens.single.categoria, 'outros');
    expect(itens.single.precoCentavos, 549);
  });

  test('deve_apagar_itens_quando_apaga_a_ida', () async {
    await db
        .into(db.idaCompra)
        .insert(
          IdaCompraCompanion.insert(
            id: 'ida-1',
            titulo: 'X',
            finalizadaEm: DateTime.utc(2026, 9, 30),
          ),
        );
    await db
        .into(db.itemIda)
        .insert(
          ItemIdaCompanion.insert(id: 'item-1', idaId: 'ida-1', nome: 'Leite'),
        );
    await (db.delete(db.idaCompra)..where((t) => t.id.equals('ida-1'))).go();
    expect(await db.select(db.itemIda).get(), isEmpty);
  });
}
