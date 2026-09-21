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

  testWidgets('deve_abrir_politica_privacidade_quando_toca_ver_politica', (
    tester,
  ) async {
    // F21-T04: o texto in-app precisa ser alcançável já no cadastro (não só
    // aceito às cegas), sem versão online.
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);

    await tester.tap(find.widgetWithText(TextButton, AppStrings.verPolitica));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dados que coletamos'), findsOneWidget);
    expect(find.textContaining('Por quanto tempo guardamos'), findsOneWidget);
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

  testWidgets('deve_suportar_escala_de_texto_2x_quando_tela_verificacao', (
    tester,
  ) async {
    // R-20: o corpo de _VerificacaoEmail era Center > Column sem scroll e
    // estourava com fonte ampliada.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await tester.ensureVisible(find.byType(Checkbox));
    await aceitarPolitica(tester);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.verificarSeuEmail), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('deve_mostrar_snackbar_quando_reenviar_link', (tester) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    repo.onReenviar = (email) async {};
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.reenviarLink),
    );
    await tester.pumpAndSettle();

    expect(repo.reenvioChamado, isTrue);
    expect(find.text(AppStrings.linkReenviado), findsOneWidget);
  });

  testWidgets('deve_mostrar_erro_quando_reenviar_link_falha', (tester) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    repo.onReenviar = (email) async => throw Exception('offline');
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.reenviarLink),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroGenerico), findsOneWidget);
  });

  testWidgets('deve_alternar_visualizacao_das_senhas_quando_toca_nos_toggles', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);

    TextField campo(String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));
    Finder toggleDe(String label) => find.descendant(
      of: find.widgetWithText(TextField, label),
      matching: find.byType(IconButton),
    );
    Finder tooltipDe(String label, String tooltip) => find.descendant(
      of: find.widgetWithText(TextField, label),
      matching: find.byTooltip(tooltip),
    );

    expect(campo(AppStrings.senha).obscureText, isTrue);
    expect(campo(AppStrings.confirmarSenha).obscureText, isTrue);
    expect(toggleDe(AppStrings.senha), findsOneWidget);
    expect(toggleDe(AppStrings.confirmarSenha), findsOneWidget);

    await tester.tap(toggleDe(AppStrings.senha));
    await tester.pump();

    expect(campo(AppStrings.senha).obscureText, isFalse);
    expect(campo(AppStrings.confirmarSenha).obscureText, isTrue);
    expect(
      tooltipDe(AppStrings.senha, AppStrings.ocultarSenha),
      findsOneWidget,
    );
    expect(
      tooltipDe(AppStrings.confirmarSenha, AppStrings.mostrarSenha),
      findsOneWidget,
    );

    await tester.tap(toggleDe(AppStrings.confirmarSenha));
    await tester.pump();

    expect(campo(AppStrings.confirmarSenha).obscureText, isFalse);
    expect(
      tooltipDe(AppStrings.confirmarSenha, AppStrings.ocultarSenha),
      findsOneWidget,
    );
  });
}
