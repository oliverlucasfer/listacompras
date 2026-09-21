import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<ItemLocalData>> itensDe(String listaId) {
    return (db.select(db.itemLocal)
          ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
          ..orderBy([
            (i) => OrderingTerm.asc(i.ordem),
            (i) => OrderingTerm.asc(i.id),
          ]))
        .get();
  }

  test('deve_copiar_somente_pendentes_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'Semana', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    final comprado = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Leite',
    );
    await repo.editarItem(comprado.id, concluido: true);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Semana (2)',
      donoId: 'user-a',
    );

    final itens = await itensDe(nova.id);
    expect(itens.map((i) => i.nome), ['Arroz']);
    expect(itens.single.concluido, isFalse);
  });

  test(
    'deve_preservar_nome_quantidade_unidade_categoria_quando_duplica',
    () async {
      final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      await repo.adicionarItem(
        listaId: origem.id,
        nome: 'Queijo',
        quantidade: 0.5,
        unidade: Unidade.kg,
        categoria: CategoriaItem.frios,
      );

      final nova = await repo.duplicarLista(
        origemId: origem.id,
        titulo: 'Y',
        donoId: 'user-a',
      );

      final item = (await itensDe(nova.id)).single;
      expect(item.nome, 'Queijo');
      expect(item.quantidade, 0.5);
      expect(item.unidade, 'kg');
      expect(item.categoria, 'frios');
    },
  );

  test('deve_preservar_a_ordem_dos_itens_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final arroz = await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    final feijao = await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    final macarrao = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Macarrão',
    );
    await repo.reordenarItens(origem.id, [macarrao.id, arroz.id, feijao.id]);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    expect((await itensDe(nova.id)).map((i) => i.nome), [
      'Macarrão',
      'Arroz',
      'Feijão',
    ]);
  });

  test(
    'deve_enfileirar_mutacao_de_lista_e_de_cada_item_quando_duplica',
    () async {
      final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
      await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');

      final nova = await repo.duplicarLista(
        origemId: origem.id,
        titulo: 'Y',
        donoId: 'user-a',
      );

      final novas = (await db.select(db.mutacaoPendente).get())
          .where((m) => m.listaId == nova.id)
          .toList();
      expect(novas.where((m) => m.tabela == 'listas'), hasLength(1));
      expect(novas.where((m) => m.tabela == 'itens_lista'), hasLength(2));
    },
  );

  test('deve_deixar_a_lista_original_intacta_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');

    await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    final itensOrigem = await itensDe(origem.id);
    expect(itensOrigem, hasLength(1));
    expect(itensOrigem.single.nome, 'Arroz');
  });

  test('deve_atribuir_o_novo_dono_quando_duplica', () async {
    final origem = await repo.criarLista(
      titulo: 'Do parceiro',
      donoId: 'user-b',
    );
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Minha',
      donoId: 'user-a',
    );

    expect(nova.donoId, 'user-a');
    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(nova.id))).getSingle();
    expect(local.donoId, 'user-a');
  });

  test('deve_falhar_quando_nao_ha_pendentes', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    await repo.editarItem(item.id, concluido: true);

    expect(
      () => repo.duplicarLista(
        origemId: origem.id,
        titulo: 'Y',
        donoId: 'user-a',
      ),
      throwsStateError,
    );

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
  });
}
