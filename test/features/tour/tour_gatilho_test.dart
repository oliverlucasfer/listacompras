import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/onboarding/providers/onboarding_provider.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:lista_compras/core/navigation/tour_keys.dart';
import 'package:lista_compras/features/tour/ui/tour_overlay.dart';
import 'package:lista_compras/l10n/app_localizations.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Espelha `lib/app.dart`: o overlay do tour vive na raiz, ocupando a tela
/// inteira (contrato full-screen do `Spotlight`).
Widget _app(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: home,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child else const SizedBox.shrink(),
            const TourOverlay(),
          ],
        ),
      ),
    );

Widget _appRouter(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child else const SizedBox.shrink(),
            const TourOverlay(),
          ],
        ),
      ),
    );

class _BoasVindasFake extends ConsumerWidget {
  const _BoasVindasFake();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('boas-vindas-fake'),
          TextButton(
            onPressed: () async {
              await ref.read(onboardingVistoProvider.notifier).marcarVisto();
              if (context.mounted) context.pop();
            },
            child: const Text('Começar'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer container({required Map<String, Object> prefs}) {
    SharedPreferences.setMockInitialValues(prefs);
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('deve_iniciar_tour_etapa1_quando_flag_falsa', (tester) async {
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, const MinhasListasScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);
  });

  testWidgets('nao_deve_iniciar_tour_etapa1_quando_flag_vista', (tester) async {
    final c = container(
      prefs: {'onboarding_visto': true, 'tour_etapa1_visto': true},
    );

    await tester.pumpWidget(_app(c, const MinhasListasScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
    expect(find.text('Criar sua primeira lista'), findsNothing);
  });

  testWidgets('deve_iniciar_tour_etapa1_quando_volta_das_boas_vindas', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/listas',
      routes: [
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
        GoRoute(
          path: '/boas-vindas',
          builder: (_, _) => const _BoasVindasFake(),
        ),
      ],
    );
    final c = container(prefs: {});

    await tester.pumpWidget(_appRouter(c, router));
    await tester.pumpAndSettle();
    expect(find.text('boas-vindas-fake'), findsOneWidget);
    expect(c.read(tourControllerProvider).ativo, isFalse);

    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);
  });

  testWidgets('deve_iniciar_tour_etapa2_quando_lista_tem_item', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(c.read(tourControllerProvider).atual?.id, 'recursos.adicionar');
  });

  testWidgets('nao_deve_iniciar_tour_etapa2_quando_flag_vista', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final c = container(
      prefs: {'onboarding_visto': true, 'tour_etapa2_visto': true},
    );

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
    expect(c.read(tourControllerProvider).atual, isNull);
  });

  testWidgets('nao_deve_iniciar_tour_etapa2_quando_lista_sem_item', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Vazia', donoId: 'local');
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
  });

  testWidgets('deve_iniciar_tour_etapa3_quando_flag_falsa', (tester) async {
    final c = container(
      prefs: {
        'onboarding_visto': true,
        'tour_etapa1_visto': true,
        'tour_etapa2_visto': true,
      },
    );

    await tester.pumpWidget(_app(c, const HistoricoScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(c.read(tourControllerProvider).etapa, TourEtapa.historico);
    expect(c.read(tourControllerProvider).atual?.id, 'historico.resumo');
  });

  testWidgets('nao_deve_iniciar_tour_etapa3_quando_flag_vista', (tester) async {
    final c = container(
      prefs: {
        'onboarding_visto': true,
        'tour_etapa1_visto': true,
        'tour_etapa2_visto': true,
        'tour_etapa3_visto': true,
      },
    );

    await tester.pumpWidget(_app(c, const HistoricoScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
  });

  testWidgets('deve_navegar_para_home_e_rodar_etapa1_quando_reabrir', (
    tester,
  ) async {
    // Shell e rotas de verdade: parte de Configurações (sem alvos da etapa 1
    // montados além da própria aba) e reabre o tour.
    SharedPreferences.setMockInitialValues({
      'onboarding_visto': true,
      'tour_etapa1_visto': true,
      'tour_etapa2_visto': true,
    });
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    final router = c.read(routerProvider);

    await tester.pumpWidget(_appRouter(c, router));
    await tester.pumpAndSettle();
    expect(find.byType(MinhasListasScreen), findsOneWidget);

    await tester.tap(find.text('Configurações').last);
    await tester.pumpAndSettle();
    expect(find.byType(ConfiguracoesScreen), findsOneWidget);
    expect(c.read(tourControllerProvider).ativo, isFalse);

    await tester.scrollUntilVisible(find.text('Ver tutorial'), 200);
    await tester.tap(find.text('Ver tutorial'));
    await tester.pumpAndSettle();

    // Navegou para a home e a etapa 1 abriu lá, com os 4 passos da tela.
    expect(find.byType(MinhasListasScreen), findsOneWidget);
    expect(c.read(tourControllerProvider).etapa, TourEtapa.primeira);
    expect(c.read(tourControllerProvider).passos.length, 4);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);

    // Concluir a etapa 1 encerra o tour — não encadeia a etapa 2.
    final tour = c.read(tourControllerProvider.notifier);
    while (c.read(tourControllerProvider).ativo) {
      await tour.proximo();
    }
    expect(c.read(tourControllerProvider).ativo, isFalse);
  });

  testWidgets('deve_ignorar_alvo_quando_offstage', (tester) async {
    final c = container(
      prefs: {
        'onboarding_visto': true,
        'tour_etapa1_visto': true,
        'tour_etapa2_visto': true,
      },
    );

    await tester.pumpWidget(
      _app(
        c,
        Stack(
          children: [
            const ConfiguracoesScreen(),
            // Alvos da aba "Minhas" escondida (IndexedStack offstage): o tour
            // não pode apontar para eles a partir de Configurações.
            Offstage(
              offstage: true,
              child: Stack(
                children: [
                  Positioned(
                    key: TourKeys.novaLista,
                    left: 40,
                    top: 96,
                    width: 120,
                    height: 48,
                    child: const SizedBox(),
                  ),
                  Positioned(
                    key: TourKeys.lupa,
                    left: 200,
                    top: 96,
                    width: 48,
                    height: 48,
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iniciou = c
        .read(tourControllerProvider.notifier)
        .iniciar(TourEtapa.primeira);

    expect(iniciou, isFalse);
    expect(c.read(tourControllerProvider).ativo, isFalse);
  });
}
