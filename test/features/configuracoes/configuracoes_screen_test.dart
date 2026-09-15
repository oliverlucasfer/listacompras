import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirComRouter(
    WidgetTester tester,
    FakeAuthRepository repo,
  ) async {
    final router = GoRouter(
      initialLocation: '/configuracoes',
      routes: [
        GoRoute(
          path: '/configuracoes',
          builder: (_, _) => const ConfiguracoesScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_exibir_email_secoes_versao_e_exclusao_quando_abrir', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('oliveira@exemplo.com'), findsOneWidget);
    expect(find.text(AppStrings.conta), findsOneWidget);
    expect(find.text(AppStrings.sobre), findsOneWidget);
    expect(find.text(AppStrings.politicaPrivacidade), findsOneWidget);
    expect(find.text(AppStrings.versao), findsOneWidget);
    expect(find.text(AppStrings.excluirMinhaConta), findsOneWidget);
    expect(find.text(AppStrings.excluirMinhaContaAviso), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_abrir_politica_privacidade_quando_tocar', (tester) async {
    await abrir(tester);

    await tester.tap(find.text(AppStrings.politicaPrivacidade));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dados que coletamos'), findsOneWidget);
    expect(find.textContaining('Por quanto tempo guardamos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_ter_excluir_em_vermelho_quando_abrir', (tester) async {
    await abrir(tester);

    final botao = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.excluirMinhaConta),
    );
    final estilo = botao.style?.backgroundColor?.resolve({});
    final contexto = tester.element(find.text(AppStrings.excluirMinhaConta));
    expect(estilo, Theme.of(contexto).colorScheme.error);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_pedir_confirmacao_quando_sair', (tester) async {
    final repo = FakeAuthRepository();
    await abrirComRouter(tester, repo);

    await tester.tap(find.text(AppStrings.sair));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sairContaMensagem), findsOneWidget);
    expect(repo.sairChamado, isFalse);
  });

  testWidgets('deve_sair_da_conta_quando_confirma', (tester) async {
    final repo = FakeAuthRepository();
    await abrirComRouter(tester, repo);

    await tester.tap(find.text(AppStrings.sair));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.sair));
    await tester.pumpAndSettle();

    expect(repo.sairChamado, isTrue);
    expect(find.text('login'), findsOneWidget);
  });
}
