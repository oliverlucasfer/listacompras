import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/listas/ui/sheet_titulo_lista.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester, {
    ValueChanged<String>? onSalvar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => abrirSheetTitulo(
                  context,
                  titulo: AppStrings.novaLista,
                  rotuloBotao: AppStrings.criarLista,
                  onSalvar: (nome) async => onSalvar?.call(nome),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('deve_limitar_titulo_a_120_quando_digitar_200', (tester) async {
    await abrir(tester);

    await tester.enterText(find.byType(TextField), 'x' * 200);
    await tester.pump();

    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.controller!.text.length, 120);
    expect(find.text('120/120'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_salvar_titulo_limitado_quando_confirmar', (tester) async {
    String? salvo;
    await abrir(tester, onSalvar: (nome) => salvo = nome);

    await tester.enterText(find.byType(TextField), 'a' * 200);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();

    expect(salvo, isNotNull);
    expect(salvo!.length, 120);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_atualizar_contador_quando_digitar', (tester) async {
    await abrir(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.text('3/120'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
