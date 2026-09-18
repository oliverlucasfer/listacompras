import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';

void main() {
  testWidgets('deve_ser_decorativo_quando_renderiza_o_logo', (tester) async {
    // doc 15 §4: o logo é decorativo — o título ao lado já anuncia a tela;
    // anunciá-lo de novo polui o leitor de tela (R-20).
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppLogo())));

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
}
