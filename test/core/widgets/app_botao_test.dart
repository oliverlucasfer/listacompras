import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_botao.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('deve_disparar_callback_quando_tocado', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      _app(AppBotao(rotulo: 'Salvar', onPressed: () => tocado = true)),
    );
    await tester.tap(find.text('Salvar'));
    expect(tocado, isTrue);
  });

  testWidgets('deve_exibir_spinner_e_bloquear_quando_carregando', (
    tester,
  ) async {
    var tocado = false;
    await tester.pumpWidget(
      _app(
        AppBotao(
          rotulo: 'Salvar',
          carregando: true,
          onPressed: () => tocado = true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    expect(tocado, isFalse);
  });

  testWidgets('deve_usar_cores_de_erro_quando_variante_destrutiva', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppBotao(
          rotulo: AppStrings.excluir,
          variante: AppBotaoVariante.destrutivo,
          onPressed: () {},
        ),
      ),
    );
    final botao = tester.widget<FilledButton>(find.byType(FilledButton));
    final contexto = tester.element(find.byType(FilledButton));
    final cores = Theme.of(contexto).colorScheme;
    expect(botao.style?.foregroundColor?.resolve({}), cores.onError);
  });
}
