import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/redefinir_senha_screen.dart';
import 'package:lista_compras/features/convites/domain/convite_pendente.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

class _SessaoFake extends SupabaseAuthRepository {
  _SessaoFake() : super(Supabase.instance.client);

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();

  @override
  Session? get sessaoAtual => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    refreshToken: 'refresh',
    expiresIn: 3600,
    user: User(
      id: 'user-a',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

class _RepoRecuperacao extends FakeAuthRepository {
  final eventos = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get onAuthStateChange => eventos.stream;

  @override
  Session? get sessaoAtual => _SessaoFake().sessaoAtual;
}

void main() {
  setUpAll(inicializarSupabaseTeste);

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  Future<void> abrirTela(WidgetTester tester, FakeAuthRepository repo) async {
    // Router mínimo: a tela navega com go_router (sucesso → /listas;
    // falha → /recuperar-senha).
    final router = GoRouter(
      initialLocation: '/redefinir-senha',
      routes: [
        GoRoute(
          path: '/redefinir-senha',
          builder: (_, _) => const RedefinirSenhaScreen(),
        ),
        GoRoute(
          path: '/listas',
          builder: (_, _) =>
              Scaffold(body: Center(child: Text(AppStrings.abaMinhas))),
        ),
        GoRoute(
          path: '/recuperar-senha',
          builder: (_, _) =>
              Scaffold(body: Center(child: Text(AppStrings.recuperarSenha))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preencher(WidgetTester tester, String senha) async {
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.novaSenha),
      senha,
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.confirmarSenha),
      senha,
    );
  }

  testWidgets('deve_exibir_erros_quando_senha_curta_ou_diferente', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.novaSenha),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.confirmarSenha),
      '456',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroSenhaCurta), findsOneWidget);
    expect(find.text(AppStrings.erroSenhasDiferentes), findsOneWidget);
    expect(repo.senhaAlterada, isFalse);
  });

  testWidgets('deve_salvar_senha_e_mostrar_confirmacao_quando_valida', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);

    await preencher(tester, 'senha123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(repo.senhaAlterada, isTrue);
    expect(find.text(AppStrings.senhaAlterada), findsOneWidget);
    expect(find.text(AppStrings.abaMinhas), findsOneWidget);
  });

  testWidgets('deve_mostrar_erro_com_pedir_novo_link_quando_falha', (
    tester,
  ) async {
    final repo = FakeAuthRepository()..erroAtualizarSenha = 'link expirado';
    await abrirTela(tester, repo);

    await preencher(tester, 'senha123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(repo.senhaAlterada, isFalse);
    expect(find.text(AppStrings.erroRedefinirSenha), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.pedirNovoLink),
      findsOneWidget,
    );

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recuperarSenha), findsOneWidget);
  });

  testWidgets('deve_redirecionar_e_concluir_quando_senha_redefinida', (
    tester,
  ) async {
    final repo = _RepoRecuperacao();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        appDatabaseProvider.overrideWithValue(db),
        syncStatusProvider.overrideWith(
          (ref) => Stream<SyncStatus>.value(const Sincronizado()),
        ),
        meusConvitesPendentesProvider.overrideWith(
          (ref) async => const <ConvitePendente>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O link de recuperação abre o app: o redirect leva à tela de nova senha
    // mesmo autenticado (doc 05 §4, F14-T03).
    repo.eventos.add(const AuthState(AuthChangeEvent.passwordRecovery, null));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.definirNovaSenha), findsOneWidget);

    await preencher(tester, 'senha123');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.abaMinhas), findsOneWidget);
    expect(container.read(redefinindoSenhaProvider), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
