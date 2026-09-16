import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/core/widgets/app_card.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';
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
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('lista-${state.pathParameters['id']}'),
          ),
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

  testWidgets('deve_separar_cards_com_espaco_vertical_quando_tem_listas', (
    tester,
  ) async {
    // F12-T05: cards empilhados não podem ficar "grudados" (doc 10 §2.1).
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.criarLista(titulo: 'Churrasco', donoId: 'user-a');

    await abrirTela(tester);

    final cards = find.byType(AppCard);
    expect(cards, findsNWidgets(2));
    final primeiro = tester.getRect(cards.at(0));
    final segundo = tester.getRect(cards.at(1));
    expect(segundo.top - primeiro.bottom, greaterThanOrEqualTo(AppSpacing.sm));
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
    expect(find.text(AppStrings.listaCriada), findsOneWidget);
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
    expect(find.text(AppStrings.listaRenomeada), findsOneWidget);
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
    expect(
      find.text(AppStrings.excluirListaMensagem(0, temMembros: false)),
      findsOneWidget,
    );

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

  testWidgets('deve_empilhar_e_voltar_ao_painel_quando_abrir_lista', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Compras'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_exibir_logo_no_cabecalho_quando_tela_de_topo', (
    tester,
  ) async {
    // F13-T02: a marca aparece nas telas de topo (sem botão voltar).
    await abrirTela(tester);

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_painel', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await abrirTela(tester);

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_toca_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Antigo', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
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

  testWidgets('deve_exibir_tooltip_no_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await abrirTela(tester);

    expect(find.byTooltip(AppStrings.menu), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_filtrar_listas_quando_buscar_pelo_titulo', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras da Semana', donoId: 'user-a');
    await repo.criarLista(titulo: 'Churrasco', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'chur',
    );
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_quando_busca_sem_resultado', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.nenhumaListaEncontrada), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_e_restaurar_quando_fechar_busca', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras da Semana', donoId: 'user-a');
    await repo.criarLista(titulo: 'Churrasco', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'chur',
    );
    await tester.pumpAndSettle();
    expect(find.text('Compras da Semana'), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.limparBusca));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      findsNothing,
    );
    expect(find.text('Compras da Semana'), findsOneWidget);

    await fechar(tester);
  });
}
