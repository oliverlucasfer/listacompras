import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  late AppDatabase db;
  late FakeAuthRepository authRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    authRepo = FakeAuthRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> abrirTela(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/listas',
      routes: [
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
        GoRoute(
          path: '/lista/:id',
          builder: (_, state) =>
              Scaffold(body: Text('lista-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(authRepo),
          donoAtualIdProvider.overrideWithValue('user-a'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Desmonta a árvore dentro do teste: o dispose do StreamProvider cancela
  /// streams do Drift, que agendam um Timer(0) — o pump seguinte o consome,
  /// evitando "Timer is still pending" no teardown do binding.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_exibir_estado_vazio_quando_nenhuma_lista', (tester) async {
    await abrirTela(tester);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);
    expect(find.text(AppStrings.criarPrimeiraLista), findsOneWidget);
    expect(find.text(AppStrings.novaLista), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_exibir_card_com_contagem_quando_tem_listas', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    final arroz = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    await repo.editarItem(arroz.id, concluido: true);

    await abrirTela(tester);
    expect(find.text('Compras da Semana'), findsOneWidget);
    expect(find.text('1/2 itens concluídos'), findsOneWidget);
    expect(find.textContaining(AppStrings.atualizada), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_ocultar_lista_compartilhada_quando_nao_e_dono', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-b');

    await abrirTela(tester);
    expect(find.text('Do parceiro'), findsNothing);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_criar_lista_quando_sheet_preenchido_e_salvo', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Churrasco',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text(AppStrings.nenhumaLista), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_erro_inline_quando_sheet_salvo_sem_nome', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroNomeVazio), findsOneWidget);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_long_press_e_sheet_salvo', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Antigo', donoId: 'user-a');
    await abrirTela(tester);

    await tester.longPress(find.text('Antigo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.renomear));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Novo',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Antigo'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_excluir_lista_quando_confirmar_dialogo', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Para excluir', donoId: 'user-a');
    await abrirTela(tester);

    await tester.longPress(find.text('Para excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.excluir).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.excluirListaMensagem), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.excluir));
    await tester.pumpAndSettle();

    expect(find.text('Para excluir'), findsNothing);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_marcar_dono_quando_cria_lista', (tester) async {
    await abrirTela(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Minha nova',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Minha nova')),
    );
    final registros = await (db.select(db.listaLocal)).get();
    final id = registros.firstWhere((l) => l.titulo == 'Minha nova').id;
    expect(container.read(papelRepositoryProvider).papelDe(id), Papel.dono);

    await fechar(tester);
  });
}
