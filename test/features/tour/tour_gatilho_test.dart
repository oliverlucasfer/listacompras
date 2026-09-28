import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/onboarding/providers/onboarding_provider.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:lista_compras/features/tour/tour_keys.dart';
import 'package:lista_compras/features/tour/ui/tour_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Espelha `lib/app.dart`: o overlay do tour vive na raiz, ocupando a tela
/// inteira (contrato full-screen do `Spotlight`).
Widget _app(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: home,
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
            child: const Text(AppStrings.comecar),
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
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        appDatabaseProvider.overrideWithValue(db),
        donoAtualIdProvider.overrideWithValue('user-a'),
        emailUsuarioProvider.overrideWithValue('user@exemplo.com'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('deve_iniciar_tour_etapa1_quando_flag_falsa', (tester) async {
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, const MinhasListasScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
  });

  testWidgets('nao_deve_iniciar_tour_etapa1_quando_flag_vista', (tester) async {
    final c = container(
      prefs: {'onboarding_visto': true, 'tour_etapa1_visto': true},
    );

    await tester.pumpWidget(_app(c, const MinhasListasScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
    expect(find.text(AppStrings.tourNovaListaTitulo), findsNothing);
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

    await tester.tap(find.text(AppStrings.comecar));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
  });

  testWidgets('deve_iniciar_tour_etapa2_quando_lista_tem_item', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text(AppStrings.tourMarcarTitulo), findsOneWidget);
  });

  testWidgets('nao_deve_iniciar_tour_etapa2_quando_flag_vista', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final c = container(
      prefs: {'onboarding_visto': true, 'tour_etapa2_visto': true},
    );

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
    expect(find.text(AppStrings.tourMarcarTitulo), findsNothing);
  });

  testWidgets('nao_deve_iniciar_tour_etapa2_quando_lista_sem_item', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Vazia', donoId: 'user-a');
    final c = container(prefs: {'onboarding_visto': true});

    await tester.pumpWidget(_app(c, TelaListaScreen(listaId: lista.id)));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
  });

  testWidgets('deve_abrir_tour_quando_toca_ver_tutorial', (tester) async {
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
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(AppStrings.tourAbrir), 200);
    await tester.tap(find.text(AppStrings.tourAbrir));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
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

  testWidgets('deve_encadear_etapa2_quando_concluir_etapa1_reaberta', (
    tester,
  ) async {
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
            Positioned(
              key: TourKeys.novaLista,
              left: 40,
              top: 96,
              width: 120,
              height: 48,
              child: const SizedBox(),
            ),
            Positioned(
              key: TourKeys.itemLista,
              left: 40,
              top: 300,
              width: 300,
              height: 48,
              child: const SizedBox(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tour = c.read(tourControllerProvider.notifier);
    // Reabre forçando o encadeamento primeira → recursos (ambos com alvo).
    expect(tour.iniciar(TourEtapa.primeira, encadear: true), isTrue);
    expect(c.read(tourControllerProvider).etapa, TourEtapa.primeira);

    // Conclui todos os passos visíveis da etapa 1.
    while (c.read(tourControllerProvider).etapa == TourEtapa.primeira) {
      await tour.proximo();
    }

    expect(c.read(tourControllerProvider).etapa, TourEtapa.recursos);
    expect(c.read(tourControllerProvider).ativo, isTrue);
  });
}
