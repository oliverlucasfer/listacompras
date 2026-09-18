import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> lista(String id) async {
    final agora = DateTime.now().toUtc();
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: id,
            createdAt: agora,
            updatedAt: agora,
            titulo: id,
            donoId: 'user-a',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> item(String listaId, String nome) async {
    await lista(listaId);
    await repo.adicionarItem(listaId: listaId, nome: nome);
  }

  test(
    'deve_agrupar_por_nome_normalizado_quando_acento_e_caixa_diferem',
    () async {
      await item('l1', 'Leite');
      await item('l2', 'leite');
      await item('l2', 'LEITE');
      final s = await repo.watchItensFrequentes('l3').first;
      expect(s.single.nome, 'Leite');
      expect(s.single.peso, 3);
    },
  );

  test('deve_ignorar_item_removido_quando_tombstone', () async {
    await item('l1', 'Arroz');
    final id = (await db.select(db.itemLocal).get()).single.id;
    await repo.removerItem(id);
    final s = await repo.watchItensFrequentes('l3').first;
    expect(s, isEmpty);
  });

  test('deve_excluir_itens_ativos_da_lista_aberta_quando_sugere', () async {
    await item('l1', 'Feijao');
    await item('l1', 'Arroz');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.map((e) => e.nome), isNot(contains('Feijao')));
  });

  test('deve_pesar_2_na_lista_aberta_e_1_nas_demais_quando_ordena', () async {
    await lista('l1');
    final cafe = await repo.adicionarItem(listaId: 'l1', nome: 'Cafe');
    await repo.editarItem(cafe.id, concluido: true);
    await item('l2', 'Leite');
    await item('l3', 'Leite');
    await item('l2', 'Arroz');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.map((e) => e.nome), ['Cafe', 'Leite']);
    expect(s.map((e) => e.peso), [2, 2]);
    expect(s.map((e) => e.nome), isNot(contains('Arroz')));
  });

  test(
    'deve_excluir_pendentes_mas_manter_concluidos_da_lista_aberta_quando_sugere',
    () async {
      await item('l1', 'Feijao');
      final cafe = await repo.adicionarItem(listaId: 'l1', nome: 'Cafe');
      await repo.editarItem(cafe.id, concluido: true);
      final s = await repo.watchItensFrequentes('l1').first;
      expect(s.map((e) => e.nome), isNot(contains('Feijao')));
      expect(s.map((e) => e.nome), contains('Cafe'));
    },
  );

  test(
    'deve_descartar_nome_abaixo_do_limiar_quando_peso_menor_que_2',
    () async {
      await item('l2', 'Unico');
      final s = await repo.watchItensFrequentes('l1').first;
      expect(s, isEmpty);
    },
  );

  test('deve_limitar_a_8_sugestoes_quando_ha_mais_candidatos', () async {
    for (var i = 0; i < 12; i++) {
      await item('l2', 'Item $i');
      await item('l3', 'Item $i');
    }
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.length, 8);
  });

  test('deve_desempatar_por_nome_quando_pesos_iguais', () async {
    await item('l2', 'Zebra');
    await item('l3', 'Zebra');
    await item('l2', 'Abacate');
    await item('l3', 'Abacate');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.map((e) => e.nome), ['Abacate', 'Zebra']);
  });
}
