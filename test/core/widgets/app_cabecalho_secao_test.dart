import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_cabecalho_secao.dart';

void main() {
  testWidgets('deve_exibir_contagem_quando_informada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: const Scaffold(body: AppCabecalhoSecao('Frios', contagem: 3)),
      ),
    );
    expect(find.text('Frios (3)'), findsOneWidget);
  });
}
