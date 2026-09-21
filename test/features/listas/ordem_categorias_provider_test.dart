import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/ordem_categorias.dart';
import 'package:lista_compras/features/listas/providers/ordem_categorias_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_carregar_ordem_salva_quando_build', () async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias':
          '${CategoriaItem.bebidas.valor},${CategoriaItem.frios.valor}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ordem = await container.read(ordemCategoriasProvider.future);

    expect(ordem.first, CategoriaItem.bebidas);
    expect(ordem[1], CategoriaItem.frios);
    expect(ordem.length, CategoriaItem.values.length);
  });

  test('deve_gravar_ordem_quando_definir', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(ordemCategoriasProvider.future);

    final nova = [
      CategoriaItem.limpeza,
      ...CategoriaItem.values.where((c) => c != CategoriaItem.limpeza),
    ];
    await container.read(ordemCategoriasProvider.notifier).definir(nova);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ordem_categorias'), serializarOrdem(nova));
  });

  test('deve_voltar_ao_enum_quando_restaurar_padrao', () async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias': CategoriaItem.bebidas.valor,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(ordemCategoriasProvider.future);

    await container.read(ordemCategoriasProvider.notifier).restaurarPadrao();

    expect(container.read(ordemCategoriasProvider).value, CategoriaItem.values);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ordem_categorias'), isNull);
  });
}
