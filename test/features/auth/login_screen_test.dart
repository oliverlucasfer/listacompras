import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> abrirTela(WidgetTester tester, FakeAuthRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  Future<void> preencher(
    WidgetTester tester,
    String email,
    String senha,
  ) async {
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.senha),
      senha,
    );
  }

  testWidgets('deve_exibir_erro_email_invalido_quando_email_malformado', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await preencher(tester, 'sem-arroba', '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroEmailInvalido), findsOneWidget);
    expect(repo.entrarChamado, isFalse);
  });

  testWidgets('deve_exibir_erro_senha_obrigatoria_quando_senha_vazia', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await preencher(tester, 'a@b.com', '');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroCamposVazios), findsOneWidget);
    expect(repo.entrarChamado, isFalse);
  });

  testWidgets('deve_exibir_erro_autenticacao_quando_credenciais_invalidas', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onEntrar = (email, senha) async =>
        throw AuthException('Invalid login credentials');
    await abrirTela(tester, repo);
    await preencher(tester, 'a@b.com', 'errada');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroAutenticacao), findsOneWidget);
  });

  testWidgets('deve_exibir_erro_generico_quando_falha_inesperada', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onEntrar = (email, senha) async => throw Exception('offline');
    await abrirTela(tester, repo);
    await preencher(tester, 'a@b.com', '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroGenerico), findsOneWidget);
  });

  testWidgets('deve_exibir_spinner_e_desabilitar_botao_quando_login_pendente', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final pendente = Completer<AuthResponse>();
    repo.onEntrar = (email, senha) => pendente.future;
    await abrirTela(tester, repo);
    await preencher(tester, 'a@b.com', '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final botao = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(botao.onPressed, isNull);
  });

  testWidgets('deve_alternar_visibilidade_da_senha_quando_toca_no_olho', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    final campoSenha = find.widgetWithText(TextField, AppStrings.senha);
    TextField widgetCampo() => tester.widget<TextField>(campoSenha);
    expect(widgetCampo().obscureText, isTrue);
    await tester.tap(
      find.descendant(of: campoSenha, matching: find.byType(IconButton)),
    );
    await tester.pump();
    expect(widgetCampo().obscureText, isFalse);
  });
}
