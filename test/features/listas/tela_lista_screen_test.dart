import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/ia/data/parse_lista_client.dart';
import 'package:lista_compras/features/ia/providers/ia_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> listaComItens(
    WidgetTester tester, {
    bool comConcluido = false,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    if (comConcluido) {
      final detergente = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Detergente',
      );
      await repo.editarItem(detergente.id, concluido: true);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_exibir_titulo_itens_e_secao_concluidos_quando_abrir', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    expect(find.text('Compras da Semana'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('1 kg'), findsNothing);
    expect(find.text('1 un'), findsNWidgets(2));
    expect(find.text('${AppStrings.itens} (2)'), findsOneWidget);
    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Detergente'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_adicionar_item_quando_enter_no_campo', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Café'), findsOneWidget);
    expect(find.text('${AppStrings.itens} (3)'), findsOneWidget);
    expect(find.text('1 un'), findsNWidgets(3));

    await fechar(tester);
  });

  testWidgets('deve_somar_quantidade_quando_adicionar_item_duplicado', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Arroz',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('2 un'), findsOneWidget);
    expect(find.textContaining('já está na lista'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mover_para_concluidos_e_voltar_quando_marcar_checkbox', (
    tester,
  ) async {
    await listaComItens(tester);

    final checkboxArroz = find.descendant(
      of: find.widgetWithText(ListTile, 'Arroz'),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkboxArroz);
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itens} (1)'), findsOneWidget);
    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itens} (2)'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_remover_item_e_desfazer_quando_swipe_esquerda', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsNothing);
    expect(find.text('${AppStrings.itens} (1)'), findsOneWidget);
    expect(find.text(AppStrings.itemRemovido), findsOneWidget);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('${AppStrings.itens} (2)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_editar_quantidade_e_unidade_quando_swipe_direita', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '3',
    );
    await tester.tap(find.byType(DropdownButtonFormField<Unidade>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('3 kg'), findsOneWidget);
    expect(find.text(AppStrings.editarItem), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_desmarcar_todos_quando_menu', (tester) async {
    await listaComItens(tester);
    final repo = ListasRepository(db);
    final itens = (await (db.select(
      db.itemLocal,
    )).get()).where((i) => !i.concluido).toList();
    await repo.editarItem(itens.first.id, concluido: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.desmarcarTodos));
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itens} (2)'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_limpar_concluidos_quando_confirmar_dialogo', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.limparConcluidosMensagem), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itens} (2)'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Detergente'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_excluir_lista_e_voltar_ao_painel_quando_confirmar', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final router = GoRouter(
      initialLocation: '/lista/${lista.id}',
      routes: [
        GoRoute(
          path: '/lista/:listaId',
          builder: (_, state) =>
              TelaListaScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.excluirLista));
    await tester.pumpAndSettle();
    expect(find.text('Excluir "Compras da Semana"?'), findsOneWidget);
    expect(find.text('O item será removido.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.excluir));
    await tester.pumpAndSettle();

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.deletadoEm, isNotNull);
    expect(find.text(AppStrings.minhasListas), findsOneWidget);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_menu', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.renomearLista));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Churrasco',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_abrir_modal_importar_ia_quando_tocar_botao', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    final clienteIa = ParseListaClient(
      obterToken: () => 'jwt-teste',
      obterUri: () =>
          Uri.parse('https://projeto.supabase.co/functions/v1/parse-lista'),
      httpClient: MockClient(
        (_) async => http.Response('{"itens": [], "aviso": null}', 200),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          parseListaClientProvider.overrideWithValue(clienteIa),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.importarPorIa));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.iaColeOuDigite), findsOneWidget);
    expect(find.text(AppStrings.iaExtrairItens), findsOneWidget);

    await fechar(tester);
  });
}
