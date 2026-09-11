import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/seletor_tema.dart';
import 'package:lista_compras/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_definir_modo_escuro_quando_tocar_em_escuro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorTema())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.temaEscuro));
    await tester.pumpAndSettle();

    expect(container.read(temaModoProvider).value, ThemeMode.dark);
  });
}
