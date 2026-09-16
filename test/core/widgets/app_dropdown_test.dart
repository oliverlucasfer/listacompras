import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';

void main() {
  testWidgets('deve_exibir_label_e_disparar_onChanged_quando_seleciona', (
    tester,
  ) async {
    String? selecionado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppDropdown<String>(
            label: 'Unidade',
            valor: 'a',
            itens: const [
              DropdownMenuItem(value: 'a', child: Text('A')),
              DropdownMenuItem(value: 'b', child: Text('B')),
            ],
            onChanged: (v) => selecionado = v,
          ),
        ),
      ),
    );

    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(selecionado, 'b');
  });

  testWidgets('deve_compactar_quando_compacto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppDropdown<String>(
            valor: 'a',
            compacto: true,
            itens: const [DropdownMenuItem(value: 'a', child: Text('A'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final decoracao = tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .decoration;
    expect(decoracao.isDense, isTrue);
  });
}
