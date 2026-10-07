import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';

import '../../support/app_teste.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orçamento por lista na tela da lista (RF-28, F36-T03, doc 05 §6.3).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async {
    await db.close();
  });

  /// Abre a tela da lista, opcionalmente já com um orçamento definido; devolve
  /// o id da lista.
  Future<String> abrirLista(
    WidgetTester tester, {
    int? orcamentoCentavos,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    if (orcamentoCentavos != null) {
      await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> abrirDialogoOrcamento(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orçamento'));
    await tester.pumpAndSettle();
  }

  Future<int?> orcamentoNoBanco(String listaId) async {
    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(listaId))).getSingle();
    return local.orcamentoCentavos;
  }

  testWidgets('deve_definir_orcamento_quando_salvar', (tester) async {
    final listaId = await abrirLista(tester);

    await abrirDialogoOrcamento(tester);
    expect(find.text('Orçamento (R\$)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Orçamento (R\$)'),
      '150,00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Orçamento salvo.'), findsOneWidget);
    expect(await orcamentoNoBanco(listaId), 15000);

    await fechar(tester);
  });

  testWidgets('deve_remover_orcamento_quando_tocar_remover', (tester) async {
    final listaId = await abrirLista(tester, orcamentoCentavos: 3000);

    await abrirDialogoOrcamento(tester);
    // Campo pré-preenchido com o orçamento atual (formatarReais).
    expect(find.text('R\$ 30,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Remover orçamento'));
    await tester.pumpAndSettle();

    expect(find.text('Orçamento removido.'), findsOneWidget);
    expect(await orcamentoNoBanco(listaId), isNull);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_inline_quando_valor_invalido', (tester) async {
    final listaId = await abrirLista(tester);

    await abrirDialogoOrcamento(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Orçamento (R\$)'),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Valor de orçamento inválido.'), findsOneWidget);
    // Diálogo permanece aberto e nada foi persistido.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Orçamento salvo.'), findsNothing);
    expect(await orcamentoNoBanco(listaId), isNull);

    await fechar(tester);
  });
}
