import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/login_screen.dart';
import 'package:lista_compras/features/auth/ui/registro_screen.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/domain/convite.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/entrar_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/fakes.dart';

const _listaId = '11111111-1111-2222-3333-444444444444';
const _token = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';

class _SessaoFakeRepository extends SupabaseAuthRepository {
  _SessaoFakeRepository() : super(Supabase.instance.client);

  bool logado = false;
  Future<AuthResponse> Function(String email, String senha)? onEntrar;

  @override
  Session? get sessaoAtual => logado
      ? Session(
          accessToken: 'a.b.c',
          tokenType: 'bearer',
          user: const User(
            id: 'U1',
            appMetadata: {},
            userMetadata: null,
            aud: 'authenticated',
            createdAt: '2026-01-01T00:00:00.000Z',
          ),
        )
      : super.sessaoAtual;

  @override
  Future<AuthResponse> entrar({
    required String email,
    required String senha,
  }) async {
    final fn = onEntrar;
    if (fn == null) throw StateError('onEntrar nao configurado');
    return fn(email, senha);
  }
}

class _ConvitesFake extends ConvitesRepository {
  _ConvitesFake() : super(Supabase.instance.client);

  bool aceitarChamado = false;
  int chamadas = 0;
  String? tokenRecebido;
  String? retorno;
  ErroConvite? erro;

  @override
  Future<String> aceitar(String token) async {
    aceitarChamado = true;
    chamadas++;
    tokenRecebido = token;
    final e = erro;
    if (e != null) throw e;
    return retorno!;
  }
}

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> abrir(
    WidgetTester tester,
    _SessaoFakeRepository authRepo,
    _ConvitesFake convitesRepo, {
    String token = _token,
  }) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/entrar?token=$token',
      routes: [
        GoRoute(
          path: '/entrar',
          builder: (_, state) =>
              EntrarScreen(token: state.uri.queryParameters['token']),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) =>
              LoginScreen(next: state.uri.queryParameters['next']),
        ),
        GoRoute(path: '/registro', builder: (_, _) => const RegistroScreen()),
        GoRoute(
          path: '/listas',
          builder: (_, _) => const Scaffold(body: Text('painel-listas')),
        ),
        GoRoute(
          path: '/listas/:id',
          builder: (_, state) =>
              Scaffold(body: Text('lista-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          convitesRepositoryProvider.overrideWithValue(convitesRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_aceitar_e_navegar_quando_token_valido_e_autenticado', (
    tester,
  ) async {
    final auth = _SessaoFakeRepository()..logado = true;
    final convites = _ConvitesFake()..retorno = _listaId;
    await abrir(tester, auth, convites);

    expect(convites.aceitarChamado, isTrue);
    expect(convites.tokenRecebido, _token);
    expect(find.text('lista-$_listaId'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_convite_invalido_quando_erro', (tester) async {
    final auth = _SessaoFakeRepository()..logado = true;
    final convites = _ConvitesFake()
      ..erro = const ErroConvite(
        'convite_invalido',
        AppStrings.conviteInvalido,
      );
    await abrir(tester, auth, convites);

    expect(find.text(AppStrings.conviteInvalido), findsOneWidget);
    expect(find.text('lista-$_listaId'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
    await tester.pumpAndSettle();

    expect(convites.chamadas, 2);
    expect(find.text(AppStrings.conviteInvalido), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_contexto_convidado_quando_sem_sessao', (
    tester,
  ) async {
    final auth = _SessaoFakeRepository();
    final convites = _ConvitesFake()..retorno = _listaId;
    await abrir(tester, auth, convites);

    expect(find.text(AppStrings.conviteConvidadoTitulo), findsOneWidget);
    expect(find.text(AppStrings.conviteConvidadoMensagem), findsOneWidget);
    expect(convites.aceitarChamado, isFalse);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_aceitar_quando_volta_do_login_pelo_next', (tester) async {
    final auth = _SessaoFakeRepository();
    auth.onEntrar = (email, senha) async {
      auth.logado = true;
      return AuthResponse(session: null, user: null);
    };
    final convites = _ConvitesFake()..retorno = _listaId;
    await abrir(tester, auth, convites);

    expect(convites.aceitarChamado, isFalse);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      'a@b.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.senha),
      '123456',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(auth.logado, isTrue);
    expect(convites.aceitarChamado, isTrue);
    expect(convites.tokenRecebido, _token);
    expect(find.text('lista-$_listaId'), findsOneWidget);

    await fechar(tester);
  });
}
