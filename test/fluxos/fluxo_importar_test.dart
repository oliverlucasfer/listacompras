import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_importar_quando_cola_texto_e_confirma', (tester) async {
    await montarApp(
      tester,
      seed: (db) async {
        await ListasRepository(
          db,
        ).criarLista(titulo: 'Compras', donoId: 'user-a');
      },
    );

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.importarLista),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '1kg de arroz, 2 leites',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.importConfirmeItens), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importAdicionarN(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leites'), findsOneWidget);

    await fechar(tester);
  });
}
