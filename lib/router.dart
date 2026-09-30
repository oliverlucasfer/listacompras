import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_shell.dart';
import 'features/compartilhamento/ui/receber_lista_screen.dart';
import 'features/configuracoes/ui/configuracoes_screen.dart';
import 'features/design_system/ui/design_system_screen.dart';
import 'features/historico/ui/historico_screen.dart';
import 'features/historico/ui/ida_detalhe_screen.dart';
import 'features/listas/ui/mercado_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_screen.dart';
import 'features/listas/ui/tela_ordenar_categorias.dart';
import 'features/onboarding/ui/boas_vindas_screen.dart';

/// Rotas do app local (RF-31): sem conta, sem compartilhamento, sem sync.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/listas',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/listas'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listas',
                builder: (context, state) => const MinhasListasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/historico',
                builder: (context, state) => const HistoricoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/configuracoes',
                builder: (context, state) => const ConfiguracoesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/lista/:listaId',
        builder: (context, state) =>
            TelaListaScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/historico/ida/:idaId',
        builder: (context, state) =>
            IdaDetalheScreen(idaId: state.pathParameters['idaId']!),
      ),
      GoRoute(
        path: '/mercado/:listaId',
        builder: (context, state) =>
            MercadoScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/boas-vindas',
        builder: (context, state) => const BoasVindasScreen(),
      ),
      GoRoute(
        path: '/categorias',
        builder: (context, state) => const TelaOrdenarCategorias(),
      ),
      GoRoute(
        path: '/receber-lista',
        builder: (context, state) => const ReceberListaScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignSystemScreen(),
        ),
    ],
  );
});
