import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/recuperar_senha_screen.dart';

import 'fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> abrirTela(WidgetTester tester, FakeAuthRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RecuperarSenhaScreen()),
      ),
    );
  }

  testWidgets('deve_exibir_erro_email_invalido_quando_email_malformado', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      'sem-arroba',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.erroEmailInvalido), findsOneWidget);
    expect(repo.recuperacaoChamada, isFalse);
  });

  testWidgets('deve_exibir_confirmacao_quando_link_enviado', (tester) async {
    final repo = FakeAuthRepository();
    repo.onEnviarRecuperacao = (email) => Future.value();
    await abrirTela(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      'a@b.com',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.linkEnviado), findsOneWidget);
    expect(repo.recuperacaoChamada, isTrue);
  });

  testWidgets('deve_exibir_confirmacao_neutra_quando_envio_falha', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    repo.onEnviarRecuperacao = (email) async => throw Exception('offline');
    await abrirTela(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.email),
      'a@b.com',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.linkEnviado), findsOneWidget);
  });
}
