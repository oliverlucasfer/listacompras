import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/utils/router_refresh_stream.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/recuperar_senha_screen.dart';
import 'features/auth/ui/registro_screen.dart';
import 'features/configuracoes/ui/configuracoes_screen.dart';
import 'features/convites/ui/entrar_screen.dart';
import 'features/convites/ui/tela_membros_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_screen.dart';

/// Rotas (doc 05 §4): /login, /registro, /recuperar-senha e /entrar são
/// públicas; as demais exigem autenticação. Redirect global nas duas
/// direções (a tela /entrar decide por si quando há/ não há sessão).
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshStream(repo.onAuthStateChange),
    redirect: (context, state) {
      final autenticado = repo.sessaoAtual != null;
      final rota = state.matchedLocation;
      final publica =
          rota == '/login' ||
          rota == '/registro' ||
          rota == '/recuperar-senha' ||
          rota == '/entrar';

      if (!autenticado && !publica) return '/login';
      // /entrar permanece pública também autenticado — a tela aceita o
      // convite por si (doc 08 §3.1).
      if (autenticado && publica && rota != '/entrar') return '/listas';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            repo.sessaoAtual != null ? '/listas' : '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/registro',
        builder: (context, state) =>
            RegistroScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, state) => const RecuperarSenhaScreen(),
      ),
      GoRoute(
        path: '/entrar',
        builder: (context, state) =>
            EntrarScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/listas',
        builder: (context, state) => const MinhasListasScreen(),
      ),
      GoRoute(
        path: '/lista/:listaId',
        builder: (context, state) =>
            TelaListaScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/membros/:listaId',
        builder: (context, state) =>
            TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/configuracoes',
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
    ],
  );
});
