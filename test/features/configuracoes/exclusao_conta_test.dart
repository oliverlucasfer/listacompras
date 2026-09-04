import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(() async {
    await inicializarSupabaseTeste();
  });

  late FakeAuthRepository repo;

  setUp(() {
    repo = FakeAuthRepository();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirDialogoExclusao(WidgetTester tester) async {
    await abrir(tester);
    await tester.tap(find.text(AppStrings.excluirMinhaConta));
    await tester.pumpAndSettle();
  }

  testWidgets('deve_pedir_senha_quando_tocar_excluir_minha_conta', (
    tester,
  ) async {
    await abrirDialogoExclusao(tester);

    // "Excluir minha conta" aparece 2x: botão da tela + título do diálogo.
    expect(find.text(AppStrings.excluirMinhaConta), findsNWidgets(2));
    final dialogo = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialogo,
        matching: find.text(AppStrings.excluirContaSenhaMensagem),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialogo,
        matching: find.widgetWithText(FilledButton, AppStrings.continuar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialogo,
        matching: find.text(AppStrings.excluirContaMensagemFinal),
      ),
      findsNothing,
    );
    expect(repo.excluirContaChamado, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_senha_incorreta_e_nao_excluir_quando_senha_errada', (
    tester,
  ) async {
    repo.onEntrar = (email, senha) async =>
        throw AuthException('invalid credentials', statusCode: '400');
    await abrirDialogoExclusao(tester);

    await tester.enterText(find.byType(TextField), 'errada');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.continuar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.senhaIncorreta), findsOneWidget);
    expect(repo.excluirContaChamado, isFalse);

    await tester.tap(find.text(AppStrings.cancelar));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_mostrar_confirmacao_final_quando_senha_correta', (
    tester,
  ) async {
    repo.onEntrar = (email, senha) async => AuthResponse();
    await abrirDialogoExclusao(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.continuar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.excluirContaMensagemFinal), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, AppStrings.excluirConta),
      findsOneWidget,
    );
    expect(repo.excluirContaChamado, isFalse);

    await tester.tap(find.text(AppStrings.cancelar));
    await tester.pumpAndSettle();
    expect(repo.excluirContaChamado, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_excluir_conta_quando_confirmar_passo_final', (
    tester,
  ) async {
    repo.onEntrar = (email, senha) async => AuthResponse();
    await abrirDialogoExclusao(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.continuar));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.excluirConta),
    );
    await tester.pumpAndSettle();

    expect(repo.excluirContaChamado, isTrue);
    expect(find.text(AppStrings.excluirContaMensagemFinal), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_fazer_nada_quando_cancelar_no_passo_da_senha', (
    tester,
  ) async {
    await abrirDialogoExclusao(tester);

    await tester.tap(find.text(AppStrings.cancelar));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.excluirContaChamado, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
