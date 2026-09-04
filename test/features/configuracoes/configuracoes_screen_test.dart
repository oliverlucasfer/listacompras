import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';

void main() {
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
}
