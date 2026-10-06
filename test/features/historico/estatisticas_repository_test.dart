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
    // Janela de 12 meses (mês corrente + 11), preenchendo zeros.
    expect(porMes, hasLength(12));
    expect(porMes.fold<int>(0, (s, m) => s + m.totalCentavos), 900);
    expect(porMes.last.totalCentavos, 900); // ambas as idas no mês corrente
  });

  test('deve_retornar_vazio_quando_sem_idas_no_gasto_por_mes', () async {
    expect(await historico.gastoPorMes(), isEmpty);
  });

  test('deve_listar_nomes_comprados_uma_vez_quando_repete', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    expect(await historico.nomesComprados(), ['Arroz']); // nome de exibição
  });

  test('deve_usar_nome_original_no_seletor_quando_acentuado', () async {
    await idaCom([('Açúcar', 1, Unidade.un, CategoriaItem.mercearia, 500)]);
    expect(await historico.nomesComprados(), ['Açúcar']);
    // O nome de exibição é aceito direto na evolução (normaliza internamente).
    final serie = await historico.evolucaoPreco('Açúcar', Unidade.un);
    expect(serie.map((p) => p.precoCentavos), [500]);
  });

  test('deve_usar_unidade_da_compra_com_preco_mais_recente', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, 900)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, null)]);
    expect(
      await historico.unidadeRecenteComprada('arroz'),
      Unidade.un,
      reason: 'ignora a compra sem preço mais recente, usa a com preço',
    );
    expect(await historico.unidadeRecenteComprada('inexistente'), isNull);
  });

  test('deve_ignorar_compra_sem_preco_quando_resolve_unidade', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, null)]);
    expect(
      await historico.unidadeRecenteComprada('arroz'),
      Unidade.kg,
      reason: 'compra sem preço é ignorada; resolve a kg antiga com preço',
    );
  });

  test(
    'deve_desempatar_gasto_por_categoria_por_valor_quando_totais_iguais',
    () async {
      await idaCom([
        ('A', 1, Unidade.un, CategoriaItem.mercearia, 500),
        ('B', 1, Unidade.un, CategoriaItem.frios, 500),
      ]);
      final cats = await historico.gastoPorCategoria();
      expect(
        cats.map((c) => c.categoria.valor).toList(),
        ['frios', 'mercearia'],
        reason: 'empate de total resolve por `valor` da categoria (asc)',
      );
    },
  );

  test(
    'deve_desempatar_gasto_por_mercado_por_rotulo_quando_totais_iguais',
    () async {
      for (final m in ['Zona', 'Aurora']) {
        final l = await listas.criarLista(titulo: m, donoId: 'local');
        final i = await listas.adicionarItem(
          listaId: l.id,
          nome: 'X',
          quantidade: 1,
          precoCentavos: 500,
        );
        await listas.editarItem(i.id, concluido: true);
        await historico.finalizar(l.id, mercado: m);
      }
      final semMercado = await listas.criarLista(
        titulo: 'Sem',
        donoId: 'local',
      );
      final i = await listas.adicionarItem(
        listaId: semMercado.id,
        nome: 'Y',
        quantidade: 1,
        precoCentavos: 500,
      );
      await listas.editarItem(i.id, concluido: true);
      await historico.finalizar(semMercado.id);

      final mercados = await historico.gastoPorMercado();
      expect(
        mercados.map((m) => m.mercado).toList(),
        ['Aurora', 'Zona', null],
        reason:
            'empate resolve por rótulo (asc); "Sem mercado" (null) por último',
      );
    },
  );
}
