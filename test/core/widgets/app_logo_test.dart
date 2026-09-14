import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';

void main() {
  testWidgets('deve_renderizar_logo_com_semantica_do_nome_do_app', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppLogo())));

    expect(find.byType(AppLogo), findsOneWidget);
    final imagem = tester.widget<Image>(find.byType(Image));
    expect(imagem.semanticLabel, AppStrings.appNome);
  });

  testWidgets('deve_carregar_o_asset_do_logo', (tester) async {
    // Garante que o PNG está declarado no pubspec e empacotado.
    final bytes = await rootBundle.load('assets/branding/logo.png');
    expect(bytes.lengthInBytes, greaterThan(0));
  });
}
