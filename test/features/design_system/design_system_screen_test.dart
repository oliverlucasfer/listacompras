import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/features/design_system/ui/design_system_screen.dart';

void main() {
  testWidgets('deve_renderizar_secoes_de_tokens_e_componentes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const DesignSystemScreen()),
    );
    await tester.pump();
    expect(find.text('Tokens'), findsOneWidget);
    expect(find.text('Botões'), findsOneWidget);
    expect(find.text('Banners'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
