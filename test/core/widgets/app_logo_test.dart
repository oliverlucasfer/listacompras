import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';

Widget _app(AppCapacidades capacidades) => ProviderScope(
  overrides: [capacidadesProvider.overrideWithValue(capacidades)],
  child: MaterialApp(
    theme: AppTheme.claroDe(
      capacidades.nuvem ? IdentidadeVisual.colaborativo : IdentidadeVisual.lite,
    ),
    home: const Scaffold(body: Center(child: AppLogo())),
  ),
);

void main() {
  testWidgets('deve_ser_decorativo_quando_renderiza_o_logo', (tester) async {
    // doc 15 §4: o logo é decorativo — o título ao lado já anuncia a tela;
    // anunciá-lo de novo polui o leitor de tela (R-20).
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AppLogo())),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    final imagem = tester.widget<Image>(find.byType(Image));
    expect(imagem.semanticLabel, isNull);
    expect(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });

  testWidgets('deve_carregar_o_asset_do_logo', (tester) async {
    // Garante que o PNG está declarado no pubspec e empacotado.
    final bytes = await rootBundle.load('assets/branding/logo.png');
    expect(bytes.lengthInBytes, greaterThan(0));
  });

  testWidgets('deve_carregar_o_asset_do_lite_quando_empacotado', (
    tester,
  ) async {
    // Garante que o PNG do Lite está declarado no pubspec e empacotado.
    final bytes = await rootBundle.load('assets/branding/logo_lite.png');
    expect(bytes.lengthInBytes, greaterThan(0));
  });

  testWidgets('deve_usar_asset_do_lite_quando_identidade_lite', (tester) async {
    await tester.pumpWidget(_app(AppCapacidades.lite));
    await tester.pumpAndSettle();

    final imagem = tester.widget<Image>(find.byType(Image));
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/branding/logo_lite.png',
    );
  });

  testWidgets('deve_usar_asset_atual_quando_colaborativo', (tester) async {
    await tester.pumpWidget(_app(AppCapacidades.colaborativo));
    await tester.pumpAndSettle();

    final imagem = tester.widget<Image>(find.byType(Image));
    expect((imagem.image as AssetImage).assetName, 'assets/branding/logo.png');
  });
}
