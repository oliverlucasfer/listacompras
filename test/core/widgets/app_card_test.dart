import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_card.dart';

void main() {
  testWidgets('deve_disparar_onTap_quando_tocado', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCard(
            child: const Text('Conteúdo'),
            onTap: () => tocado = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Conteúdo'));
    expect(tocado, isTrue);
  });
}
