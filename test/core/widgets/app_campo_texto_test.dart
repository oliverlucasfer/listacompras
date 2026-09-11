import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_campo_texto.dart';

void main() {
  testWidgets('deve_exibir_erro_e_disparar_onChanged', (tester) async {
    String? digitado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(
            label: 'E-mail',
            erro: 'Inválido',
            onChanged: (v) => digitado = v,
          ),
        ),
      ),
    );
    expect(find.text('Inválido'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a@b.com');
    expect(digitado, 'a@b.com');
  });
}
