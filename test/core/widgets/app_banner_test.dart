import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_banner.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('deve_exibir_mensagem_e_icone_quando_offline', (tester) async {
    await tester.pumpWidget(
      _app(const AppBanner(tipo: AppBannerTipo.offline, mensagem: 'Sem rede')),
    );
    expect(find.text('Sem rede'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('deve_usar_onContainer_quando_erro', (tester) async {
    await tester.pumpWidget(
      _app(const AppBanner(tipo: AppBannerTipo.erro, mensagem: 'Falhou')),
    );
    final texto = tester.widget<Text>(find.text('Falhou'));
    final contexto = tester.element(find.text('Falhou'));
    final cores = Theme.of(contexto).colorScheme;
    expect(texto.style?.color, cores.onErrorContainer);
  });
}
