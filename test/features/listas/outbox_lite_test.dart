import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_nao_enfileirar_mutacao_quando_outbox_desligada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db, enfileirarMutacoes: false);

    await repo.criarLista(titulo: 'Mercado', donoId: 'local');

    final pendentes = await db.select(db.mutacaoPendente).get();
    expect(pendentes, isEmpty);
  });

  test('deve_enfileirar_mutacao_quando_outbox_ligada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await repo.criarLista(titulo: 'Mercado', donoId: 'user-a');

    final pendentes = await db.select(db.mutacaoPendente).get();
    expect(pendentes, isNotEmpty);
  });
}
