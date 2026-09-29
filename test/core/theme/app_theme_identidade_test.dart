import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';

void main() {
  test('deve_usar_a_mesma_paleta_quando_getter_padrao', () {
    expect(
      AppTheme.claro.colorScheme.primary,
      AppTheme.claroDe(IdentidadeVisual.lite).colorScheme.primary,
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
