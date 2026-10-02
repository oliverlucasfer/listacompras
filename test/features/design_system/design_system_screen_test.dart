import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/features/design_system/ui/design_system_screen.dart';

import '../../support/app_teste.dart';

void main() {
  testWidgets('deve_renderizar_secoes_de_tokens_e_componentes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: appTeste(const DesignSystemScreen(), theme: AppTheme.claro),
      ),
    );
    await tester.pump();
    expect(find.text('Tokens'), findsOneWidget);
    expect(find.text('Botões'), findsOneWidget);
    expect(find.text('Banners'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
