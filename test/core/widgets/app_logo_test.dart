import 'package:flutter/material.dart';
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
