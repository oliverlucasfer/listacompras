import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets(
    'deve_criar_lista_adicionar_marcar_e_limpar_quando_fluxo_completo',
    (tester) async {
      await montarApp(tester);

      // Criar lista
      await tester.tap(
        find.widgetWithText(FloatingActionButton, AppStrings.novaLista),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.nomeDaLista),
        'Compras',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.criarLista),
      );
      await tester.pumpAndSettle();
      expect(find.text('Compras'), findsOneWidget);

      // Abrir a lista e adicionar item
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.adicionarItem),
        'Arroz',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Arroz'), findsOneWidget);

      // Marcar (vai para concluídos)
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Limpar concluídos (menu ⋮) e desfazer
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.limparConcluidos));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
      await tester.pumpAndSettle();
      expect(find.text('Arroz'), findsNothing);

      await tester.tap(find.text(AppStrings.desfazer));
      await tester.pumpAndSettle();
      // O item restaurado volta concluído, dentro de "Itens concluídos"
      // recolhido — offstage por padrão, por isso `skipOffstage: false`.
      expect(find.text('Arroz', skipOffstage: false), findsOneWidget);

      await fechar(tester);
    },
  );
}
