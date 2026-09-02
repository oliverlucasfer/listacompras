import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/main.dart';

void main() {
  testWidgets('deve_exibir_titulo_do_app_quando_abre_placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ListaComprasApp()));
    expect(find.text(AppStrings.appNome), findsOneWidget);
    expect(find.text(AppStrings.minhasListas), findsOneWidget);
  });

  testWidgets('deve_aplicar_tema_escuro_quando_sistema_esta_escuro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: const ProviderScope(child: ListaComprasApp()),
      ),
    );
    final context = tester.element(find.text(AppStrings.minhasListas));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
