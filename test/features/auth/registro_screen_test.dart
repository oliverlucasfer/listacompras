import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/registro_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> abrirTela(WidgetTester tester, FakeAuthRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RegistroScreen()),
      ),
    );
  }

  Future<void> preencherFormulario(
    WidgetTester tester,
    String email,
    String senha,
    String confirmar,
  ) async {
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.senha),
      senha,
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.confirmarSenha),
      confirmar,
    );
  }

  Future<void> aceitarPolitica(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  testWidgets('deve_exibir_erro_senha_curta_quando_senha_menor_que_6', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123', '123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroSenhaCurta), findsOneWidget);
    expect(repo.registrarChamado, isFalse);
  });

  testWidgets('deve_exibir_erro_senhas_diferentes_quando_confirmacao_diverge', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', 'abcdef');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroSenhasDiferentes), findsOneWidget);
    expect(repo.registrarChamado, isFalse);
  });

  testWidgets('deve_exibir_erro_politica_quando_aceite_ausente', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroPoliticaPrivacidade), findsOneWidget);
    expect(repo.registrarChamado, isFalse);
  });

  testWidgets('deve_exibir_tela_verificacao_quando_registro_bem_sucedido', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.verificarSeuEmail), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
  });

  testWidgets('deve_exibir_email_ja_cadastrado_quando_supabase_rejeita', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) async =>
        throw AuthException('User already registered');
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroEmailJaCadastrado), findsOneWidget);
  });

  testWidgets('deve_exibir_erro_generico_quando_falha_inesperada', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) async => throw Exception('offline');
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroGenerico), findsOneWidget);
  });
}
