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

  testWidgets('deve_aplicar_hint_readonly_linhas_e_action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(
            hint: 'Exemplo',
            readOnly: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 10,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ),
    );
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.readOnly, isTrue);
    expect(campo.minLines, 3);
    expect(campo.maxLines, 5);
    expect(campo.maxLength, 10);
    expect(campo.textInputAction, TextInputAction.newline);
    expect(find.text('Exemplo'), findsOneWidget);
    // Contador embutido oculto: o app usa o próprio (ex.: importação).
    expect(find.text('0/10'), findsNothing);
  });

  testWidgets('deve_permitir_exceder_max_length_quando_informado', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(controller: controller, maxLength: 3),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();
    expect(controller.text, 'abcdefgh');
  });
}
