import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> ida(String mercado, List<(String, int, Unidade)> itens) async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    for (final (nome, preco, un) in itens) {
      final i = await listas.itens.adicionarItem(
        listaId: l.id,
        nome: nome,
        unidade: un,
        precoCentavos: preco,
      );
      await listas.itens.editarItem(i.id, concluido: true);
    }
    await historico.finalizar(l.id, mercado: mercado);
  }

  test('deve_listar_mercados_usados_sem_repetir', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('mercado a', [('Arroz', 600, Unidade.kg)]);
    await ida('Mercado B', [('Leite', 400, Unidade.l)]);
    expect(await historico.mercadosUsados(), ['Mercado A', 'Mercado B']);
  });

  test('deve_derivar_ultimo_preco_por_mercado_quando_ha_compras', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado A', [('Arroz', 550, Unidade.kg)]);
    await ida('Mercado B', [('Arroz', 700, Unidade.kg)]);
    final precos = await historico.precosPorMercado('arroz', Unidade.kg);
    expect(precos.map((p) => p.mercado), ['Mercado A', 'Mercado B']);
    expect(precos.first.precoCentavos, 550); // último do A
    expect(precos.last.precoCentavos, 700);
  });

  test('deve_ignorar_outra_unidade_quando_deriva_preco', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado B', [('Arroz', 900, Unidade.un)]);
    final precos = await historico.precosPorMercado('arroz', Unidade.kg);
    expect(precos.map((p) => p.mercado), ['Mercado A']);
  });

  test('deve_agrupar_gasto_por_mercado_incluindo_sem_mercado', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado B', [('Leite', 400, Unidade.l)]);
    await ida('', [('Pao', 300, Unidade.un)]);
    final gasto = await historico.gastoPorMercado();
    expect(
      gasto.firstWhere((g) => g.mercado == 'Mercado A').totalCentavos,
      500,
    );
    expect(gasto.firstWhere((g) => g.mercado == null).totalCentavos, 300);
  });

  test('deve_normalizar_mercado_ao_agrupar_gasto', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('mercado a', [('Leite', 400, Unidade.l)]);
    final gasto = await historico.gastoPorMercado();
    expect(gasto.length, 1);
    expect(gasto.single.mercado, 'Mercado A');
    expect(gasto.single.totalCentavos, 900);
  });
}
