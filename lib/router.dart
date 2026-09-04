import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/utils/router_refresh_stream.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/recuperar_senha_screen.dart';
import 'features/auth/ui/registro_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_placeholder.dart';

/// Rotas (doc 05 §4): /login, /registro e /recuperar-senha são públicas;
/// as demais exigem autenticação. Redirect global nas duas direções.
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshStream(repo.onAuthStateChange),
    redirect: (context, state) {
      final autenticado = repo.sessaoAtual != null;
      final rota = state.matchedLocation;
      final publica =
          rota == '/login' || rota == '/registro' || rota == '/recuperar-senha';

      if (!autenticado && !publica) return '/login';
      if (autenticado && publica) return '/listas';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            repo.sessaoAtual != null ? '/listas' : '/login',
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/registro',
        builder: (context, state) => const RegistroScreen(),
      ),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, state) => const RecuperarSenhaScreen(),
      ),
      GoRoute(
        path: '/listas',
        builder: (context, state) => const MinhasListasScreen(),
      ),
      GoRoute(
        path: '/lista/:listaId',
        builder: (context, state) =>
            TelaListaPlaceholder(listaId: state.pathParameters['listaId']!),
      ),
    ],
  );
});
