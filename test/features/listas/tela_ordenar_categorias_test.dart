import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/features/listas/domain/ordem_categorias.dart';
import 'package:lista_compras/features/listas/ui/tela_ordenar_categorias.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TelaOrdenarCategorias())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  double dyDe(WidgetTester tester, CategoriaItem categoria) =>
      tester.getTopLeft(find.text(categoria.rotulo)).dy;

  testWidgets('deve_exibir_categorias_na_ordem_salva_quando_abre', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias':
          '${CategoriaItem.bebidas.valor},'
          '${CategoriaItem.mercearia.valor},'
          '${CategoriaItem.hortifruti.valor}',
    });
    await abrir(tester);

    expect(
      dyDe(tester, CategoriaItem.bebidas),
      lessThan(dyDe(tester, CategoriaItem.mercearia)),
    );
    expect(
      dyDe(tester, CategoriaItem.mercearia),
      lessThan(dyDe(tester, CategoriaItem.hortifruti)),
    );

    await fechar(tester);
  });

  testWidgets('deve_restaurar_padrao_quando_confirma', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias': CategoriaItem.bebidas.valor,
    });
    await abrir(tester);
    expect(
      dyDe(tester, CategoriaItem.bebidas),
      lessThan(dyDe(tester, CategoriaItem.hortifruti)),
    );

    await tester.tap(find.text(AppStrings.restaurarPadrao));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.restaurarPadraoTitulo), findsOneWidget);
    expect(find.text(AppStrings.restaurarPadraoMensagem), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.restaurarPadrao),
    );
    await tester.pumpAndSettle();

    expect(
      dyDe(tester, CategoriaItem.hortifruti),
      lessThan(dyDe(tester, CategoriaItem.bebidas)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ordem_categorias'), isNull);

    await fechar(tester);
  });

  testWidgets('nao_deve_restaurar_quando_cancela', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias': CategoriaItem.bebidas.valor,
    });
    await abrir(tester);

    await tester.tap(find.text(AppStrings.restaurarPadrao));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, AppStrings.cancelar));
    await tester.pumpAndSettle();

    expect(
      dyDe(tester, CategoriaItem.bebidas),
      lessThan(dyDe(tester, CategoriaItem.hortifruti)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ordem_categorias'), isNotNull);

    await fechar(tester);
  });

  testWidgets('deve_persistir_quando_reordena', (tester) async {
    await abrir(tester);
    expect(
      dyDe(tester, CategoriaItem.hortifruti),
      lessThan(dyDe(tester, CategoriaItem.mercearia)),
    );

    // Segura a alça explícita do 1º item e arrasta para baixo (1 posição).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).first),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 130));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    // Arrastar o 1º item para baixo 1 posição: ordem crua (0 → 2).
    final esperada = serializarOrdem(moverItem(CategoriaItem.values, 0, 2));
    expect(prefs.getString('ordem_categorias'), esperada);
    expect(
      dyDe(tester, CategoriaItem.mercearia),
      lessThan(dyDe(tester, CategoriaItem.hortifruti)),
    );

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_tela', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await abrir(tester);

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });
}
