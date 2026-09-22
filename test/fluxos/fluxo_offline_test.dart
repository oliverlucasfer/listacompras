import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_manter_item_quando_adiciona_offline', (tester) async {
    final app = await montarApp(
      tester,
      sync: const Offline(),
      seed: (db) async {
        await ListasRepository(
          db,
        ).criarLista(titulo: 'Compras', donoId: 'user-a');
      },
    );

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Arroz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    final mutacoes = await app.db.select(app.db.mutacaoPendente).get();
    expect(
      mutacoes.where(
        (m) => m.tabela == 'itens_lista' && m.operacao == 'INSERT',
      ),
      isNotEmpty,
    );

    await fechar(tester);
  });
}
