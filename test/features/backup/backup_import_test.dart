import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/data/orcamento_categoria_repository.dart';

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

  test('deve_lancar_erro_sem_alterar_banco_quando_campos_invalidos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await expectLater(
      BackupRepository(db).importarJson(
        '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z",'
        '"listas":"nao-e-lista","itens":[],"historicoPrecos":[]}',
      ),
      throwsA(isA<BackupInvalidoException>()),
    );
    expect(await db.select(db.listaLocal).get(), isEmpty);
  });

  test('deve_restaurar_orcamento_por_categoria_quando_backup', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    await LimitesCategoriaRepository(
      origem,
    ).definir(CategoriaItem.bebidas, centavos: 5000);
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    final limites = await LimitesCategoriaRepository(destino).limites();
    expect(limites[CategoriaItem.bebidas], 5000);
  });

  test(
    'deve_importar_backup_sem_orcamento_categoria_quando_retrocompat',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await BackupRepository(db).importarJson(
        '{"versao":2,"exportadoEm":"2026-01-01T00:00:00Z","listas":[],"itens":[],'
        '"historicoPrecos":[],"idas":[],"itensIda":[]}',
      );
      expect(await db.select(db.orcamentoCategoria).get(), isEmpty);
    },
  );

  test('deve_forcar_dono_local_quando_importar', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    await ListasRepository(
      origem,
    ).criarLista(titulo: 'Mercado', donoId: 'user-x');
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    final listas = await destino.select(destino.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.donoId, 'local');
  });

  test(
    'deve_lancar_erro_sem_alterar_banco_quando_campo_de_registro_faltando',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await expectLater(
        BackupRepository(db).importarJson(
          '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z",'
          '"listas":[{"titulo":"x"}],"itens":[],"historicoPrecos":[]}',
        ),
        throwsA(isA<BackupInvalidoException>()),
      );
      expect(await db.select(db.listaLocal).get(), isEmpty);
    },
  );

  test('deve_manter_versao_mais_nova_quando_lww', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Local', donoId: 'local');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'LocalItem');

    String jsonCom(String titulo, String nomeItem, String updatedAt) =>
        '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z",'
        '"listas":[{"id":"${lista.id}","titulo":"$titulo","dono_id":"local",'
        '"created_at":"2026-01-01T00:00:00Z","updated_at":"$updatedAt",'
        '"deletado_em":null,"arquivada_em":null,"orcamento_centavos":null}],'
        '"itens":[{"id":"${item.id}","lista_id":"${lista.id}",'
        '"nome":"$nomeItem","quantidade":1.0,"unidade":"un",'
        '"categoria":"outros","preco_centavos":null,"concluido":false,'
        '"ordem":0,"created_at":"2026-01-01T00:00:00Z",'
        '"updated_at":"$updatedAt","deletado_em":null}],'
        '"historicoPrecos":[]}';

    await BackupRepository(db).importarJson(
      jsonCom('BackupAntigo', 'ItemAntigo', '2000-01-01T00:00:00Z'),
    );
    expect(
      (await db.select(db.listaLocal).get()).single.titulo,
      'Local',
      reason: 'backup mais antigo não deve sobrescrever o local',
    );
    expect(
      (await db.select(db.itemLocal).get()).single.nome,
      'LocalItem',
      reason: 'backup mais antigo não deve sobrescrever o local',
    );

    await BackupRepository(
      db,
    ).importarJson(jsonCom('BackupNovo', 'ItemNovo', '2100-01-01T00:00:00Z'));
    expect(
      (await db.select(db.listaLocal).get()).single.titulo,
      'BackupNovo',
      reason: 'backup mais novo deve sobrescrever o local',
    );
    expect(
      (await db.select(db.itemLocal).get()).single.nome,
      'ItemNovo',
      reason: 'backup mais novo deve sobrescrever o local',
    );
  });

  test(
    'deve_restaurar_backup_com_lista_excluida_quando_export_completo',
    () async {
      final origem = AppDatabase(NativeDatabase.memory());
      addTearDown(origem.close);
      final repoOrigem = ListasRepository(origem);
      final lista = await repoOrigem.criarLista(
        titulo: 'Mercado',
        donoId: 'local',
      );
      await repoOrigem.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await repoOrigem.excluirLista(lista.id);
      final json = await BackupRepository(origem).exportarJson();

      final destino = AppDatabase(NativeDatabase.memory());
      addTearDown(destino.close);
      await BackupRepository(destino).importarJson(json);

      expect(await destino.select(destino.listaLocal).get(), hasLength(1));
      expect(await destino.select(destino.itemLocal).get(), hasLength(1));
    },
  );

  test('deve_lancar_restauracao_quando_item_sem_lista', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const json =
        '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z","listas":[],'
        '"itens":[{"id":"i1","lista_id":"l1","nome":"Arroz","quantidade":1.0,'
        '"unidade":"un","categoria":"outros","preco_centavos":null,'
        '"concluido":false,"ordem":0,"created_at":"2026-01-01T00:00:00Z",'
        '"updated_at":"2026-01-01T00:00:00Z","deletado_em":null}],'
        '"historicoPrecos":[]}';
    await expectLater(
      BackupRepository(db).importarJson(json),
      throwsA(isA<BackupRestauracaoException>()),
    );
    expect(await db.select(db.itemLocal).get(), isEmpty);
  });
}
