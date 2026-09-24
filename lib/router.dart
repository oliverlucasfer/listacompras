import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_modo.dart';
import 'core/l10n/app_strings.dart';
import 'core/navigation/app_shell.dart';
import 'core/theme/tokens/app_spacing.dart';
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
import 'features/listas/ui/mercado_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_screen.dart';
import 'features/listas/ui/tela_ordenar_categorias.dart';
import 'features/onboarding/ui/boas_vindas_screen.dart';

/// Rotas (doc 05 §4): /login, /registro, /recuperar-senha e /entrar são
/// públicas; as demais exigem autenticação. Redirect global nas duas
/// direções (a tela /entrar decide por si quando há/ não há sessão).
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);

  // No modo Lite (RF-31) a navegação é 100% local: tabela condicional sem
  // conta nem compartilhamento e redirect no-op. O colaborativo mantém a
  // tabela e o redirect originais.
  final cap = ref.watch(capacidadesProvider);

  // Constrói/assina a flag do fluxo de recuperação ANTES do refresh do
  // router: no evento passwordRecovery o estado precisa estar true quando o
  // redirect roda (F14-T03, RF-01). No Lite o stream é vazio, sem eventos.
  ref.listen(redefinindoSenhaProvider, (_, _) {});

  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshStream(repo.onAuthStateChange),
    redirect: (context, state) {
      if (!cap.colaboracao) return null;
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
        redirect: (context, state) => !cap.colaboracao
            ? '/listas'
            : (repo.sessaoAtual != null ? '/listas' : '/login'),
      ),
      if (cap.colaboracao) ...[
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
          builder: (context, state) => const _CallbackLoginScreen(),
        ),
      ],
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
          // Compartilhamento é colaborativo: no Lite sobram Minhas e Config.
          if (cap.colaboracao)
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
      if (cap.colaboracao)
        GoRoute(
          path: '/membros/:listaId',
          builder: (context, state) =>
              TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
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
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignSystemScreen(),
        ),
    ],
  );
});

/// Recebe os tokens do fluxo de auth no web; o `supabase_flutter` processa a
/// URL e o redirect global navega. Sem isso, mostra um fallback após 10s.
class _CallbackLoginScreen extends StatefulWidget {
  const _CallbackLoginScreen();

  @override
  State<_CallbackLoginScreen> createState() => _CallbackLoginScreenState();
}

class _CallbackLoginScreenState extends State<_CallbackLoginScreen> {
  bool _demorou = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _demorou = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_demorou) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                AppStrings.callbackLoginFalhou,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text(AppStrings.voltarAoLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
