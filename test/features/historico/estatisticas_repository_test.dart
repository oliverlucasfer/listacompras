import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late HistoricoComprasRepository historico;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    historico = HistoricoComprasRepository(db);
  });
  tearDown(() => db.close());

  Future<void> idaCom(
    List<(String, double, Unidade, CategoriaItem, int?)> itens,
  ) async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    for (final (nome, qtd, un, cat, preco) in itens) {
      final i = await listas.adicionarItem(
        listaId: l.id,
        nome: nome,
        quantidade: qtd,
        unidade: un,
        categoria: cat,
        precoCentavos: preco,
      );
      await listas.editarItem(i.id, concluido: true);
    }
    await historico.finalizar(l.id);
  }

  test('deve_somar_gasto_por_categoria_quando_ha_precos', () async {
    await idaCom([
      ('Arroz', 2, Unidade.kg, CategoriaItem.mercearia, 500),
      ('Queijo', 1, Unidade.un, CategoriaItem.frios, 1200),
      ('Sem preço', 1, Unidade.un, CategoriaItem.frios, null),
    ]);
    final porCategoria = await historico.gastoPorCategoria();
    final frios = porCategoria.firstWhere(
      (g) => g.categoria == CategoriaItem.frios,
    );
    expect(frios.totalCentavos, 1200); // 'Sem preço' não soma
    final mercearia = porCategoria.firstWhere(
      (g) => g.categoria == CategoriaItem.mercearia,
    );
    expect(mercearia.totalCentavos, 1000);
  });

  test('deve_contar_itens_mais_comprados_por_nome_normalizado', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('arroz', 3, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Leite', 1, Unidade.l, CategoriaItem.laticinios, 400)]);
    final top = await historico.itensMaisComprados();
    expect(top.first.nome.toLowerCase(), 'arroz');
    expect(top.first.vezes, 2);
  });

  test('deve_serie_de_evolucao_somente_mesma_unidade', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 600)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, 900)]);
    final serie = await historico.evolucaoPreco('arroz', Unidade.kg);
    expect(serie.map((p) => p.precoCentavos), [500, 600]);
    expect(serie.map((p) => p.unidade).toSet(), {Unidade.kg});
  });

  test('deve_agrupar_gasto_por_mes', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Leite', 1, Unidade.l, CategoriaItem.laticinios, 400)]);
    final porMes = await historico.gastoPorMes();
    expect(porMes, hasLength(1)); // ambas as idas no mês corrente
    expect(porMes.single.totalCentavos, 900);
  });

  test('deve_listar_nomes_comprados_uma_vez_quando_repete', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    expect(await historico.nomesComprados(), ['arroz']);
  });

  test('deve_retornar_unidade_mais_recente_quando_ha_compras', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, 900)]);
    expect(await historico.unidadeRecenteComprada('arroz'), Unidade.un);
    expect(await historico.unidadeRecenteComprada('inexistente'), isNull);
  });
}
