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
      final app = await montarApp(tester);

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

      // Expandir "Itens concluídos" para o item ficar onstage: sem isso a
      // asserção após limpar seria vácua (já era `findsNothing` offstage).
      await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
      await tester.pumpAndSettle();
      // Escopo no ExpansionTile: o chip de sugestão também mostra "Arroz".
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('Arroz'),
        ),
        findsOneWidget,
      );

      final listaId = (await app.db.select(app.db.listaLocal).get()).single.id;

      // Limpar concluídos (menu ⋮) e desfazer
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.limparConcluidos));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
      await tester.pumpAndSettle();

      // UI: sumiu de fato (estava onstage antes de limpar).
      expect(find.text('Arroz'), findsNothing);
      // Dados: o soft-delete foi realmente gravado (mesma exclusão que o
      // `watchItensDaLista` do app aplica: `deletado_em IS NULL`).
      final linhas = await app.db.select(app.db.itemLocal).get();
      expect(
        linhas.where((i) => i.listaId == listaId && i.deletadoEm == null),
        isEmpty,
      );
      expect(
        linhas.singleWhere((i) => i.nome == 'Arroz').deletadoEm,
        isNotNull,
      );

      await tester.tap(find.text(AppStrings.desfazer));
      await tester.pumpAndSettle();

      // O item restaurado volta concluído, dentro de "Itens concluídos".
      // Recolhido, o ExpansionTile nem constrói os filhos — reabre para
      // provar que o item voltou à lista.
      await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('Arroz'),
        ),
        findsOneWidget,
      );
      final linhasRestauradas = await app.db.select(app.db.itemLocal).get();
      expect(
        linhasRestauradas
            .where((i) => i.listaId == listaId && i.deletadoEm == null)
            .map((i) => i.nome),
        contains('Arroz'),
      );
      expect(
        linhasRestauradas.singleWhere((i) => i.nome == 'Arroz').deletadoEm,
        isNull,
      );

      await fechar(tester);
    },
  );
}
