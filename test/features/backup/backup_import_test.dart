import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_restaurar_listas_e_itens_quando_backup_valido', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    final repoOrigem = ListasRepository(origem);
    final lista = await repoOrigem.criarLista(
      titulo: 'Mercado',
      donoId: 'local',
    );
    await repoOrigem.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    final listas = await destino.select(destino.listaLocal).get();
    final itens = await destino.select(destino.itemLocal).get();
    expect(listas, hasLength(1));
    expect(itens, hasLength(1));
    expect(itens.single.nome, 'Arroz');
  });

  test(
    'deve_lancar_erro_sem_alterar_banco_quando_versao_desconhecida',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await expectLater(
        BackupRepository(db).importarJson(
          '{"versao":99,"listas":[],"itens":[],"historicoPrecos":[]}',
        ),
        throwsA(isA<BackupInvalidoException>()),
      );
      expect(await db.select(db.listaLocal).get(), isEmpty);
    },
  );

  test('deve_forcar_dono_local_quando_donoLocal', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    await ListasRepository(
      origem,
    ).criarLista(titulo: 'Mercado', donoId: 'user-x');
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino, donoLocal: true).importarJson(json);

    final listas = await destino.select(destino.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.donoId, 'local');
  });
}
