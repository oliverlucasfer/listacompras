import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_shell.dart';
import 'core/utils/router_refresh_stream.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/redefinir_senha_screen.dart';
import 'features/auth/ui/recuperar_senha_screen.dart';
import 'features/auth/ui/registro_screen.dart';
import 'features/configuracoes/ui/configuracoes_screen.dart';
import 'features/convites/ui/entrar_screen.dart';
import 'features/convites/ui/tela_membros_screen.dart';
import 'features/design_system/ui/design_system_screen.dart';
import 'features/listas/ui/compartilhadas_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_screen.dart';

/// Rotas (doc 05 §4): /login, /registro, /recuperar-senha e /entrar são
/// públicas; as demais exigem autenticação. Redirect global nas duas
/// direções (a tela /entrar decide por si quando há/ não há sessão).
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);

  // Constrói/assina a flag do fluxo de recuperação ANTES do refresh do
  // router: no evento passwordRecovery o estado precisa estar true quando o
  // redirect roda (F14-T03, RF-01).
  ref.listen(redefinindoSenhaProvider, (_, _) {});

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
          rota == '/redefinir-senha' ||
          rota == '/entrar' ||
          rota == '/login-callback' ||
          (kDebugMode && rota == '/design');

      // Fluxo do link de recuperação (F14-T03, RF-01): enquanto a nova senha
      // não é definida, toda navegação passa pela tela de redefinição.
      if (ref.read(redefinindoSenhaProvider)) {
        return rota == '/redefinir-senha' ? null : '/redefinir-senha';
      }

      if (!autenticado && !publica) return '/login';
      // /entrar permanece pública também autenticado — a tela aceita o
      // convite por si (doc 08 §3.1).
      if (autenticado &&
          publica &&
          rota != '/entrar' &&
          rota != '/redefinir-senha') {
        return '/listas';
      }
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
        path: '/redefinir-senha',
        builder: (context, state) => const RedefinirSenhaScreen(),
      ),
      GoRoute(
        path: '/entrar',
        builder: (context, state) =>
            EntrarScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/login-callback',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
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
                path: '/compartilhadas',
                builder: (context, state) => const CompartilhadasScreen(),
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
        path: '/membros/:listaId',
        builder: (context, state) =>
            TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignSystemScreen(),
        ),
    ],
  );
});
