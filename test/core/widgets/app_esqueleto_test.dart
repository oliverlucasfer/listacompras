import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_esqueleto.dart';

void main() {
  testWidgets('deve_exibir_linhas_estaticas_quando_renderizado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: const Scaffold(body: AppEsqueleto(linhas: 3)),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(AppEsqueleto),
        matching: find.byType(Container),
      ),
      findsNWidgets(3),
    );
    // Placeholder estático: sem spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Rótulo de carregamento exposto ao leitor de tela (sem liveRegion).
    expect(find.bySemanticsLabel(AppStrings.carregando), findsOneWidget);

    handle.dispose();
  });

  testWidgets('deve_usar_defaults_e_cor_do_tema_quando_nao_informado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: const Scaffold(body: AppEsqueleto()),
      ),
    );

    final blocos = find.descendant(
      of: find.byType(AppEsqueleto),
      matching: find.byType(Container),
    );
    expect(blocos, findsNWidgets(4));
    final decoracao =
        tester.widget<Container>(blocos.first).decoration! as BoxDecoration;
    expect(decoracao.color, AppTheme.claro.colorScheme.surfaceContainerHighest);
  });
}
