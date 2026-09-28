import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';

void main() {
  test('deve_gerar_paleta_distinta_quando_identidade_lite', () {
    final lite = AppTheme.claroDe(IdentidadeVisual.lite);
    final prod = AppTheme.claroDe(IdentidadeVisual.colaborativo);
    expect(lite.colorScheme.primary, isNot(equals(prod.colorScheme.primary)));
  });

  test('deve_manter_prod_verde_quando_getter_padrao', () {
    expect(
      AppTheme.claro.colorScheme.primary,
      AppTheme.claroDe(IdentidadeVisual.colaborativo).colorScheme.primary,
    );
  });

  testWidgets('deve_manter_contraste_quando_tema_lite', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claroDe(IdentidadeVisual.lite),
        home: const Scaffold(body: Center(child: Text('Minhas listas'))),
      ),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
