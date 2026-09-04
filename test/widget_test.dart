import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

var _supabaseInicializado = false;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    if (!_supabaseInicializado) {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        publishableKey: 'test-key',
      );
      _supabaseInicializado = true;
    }
  });

  testWidgets('deve_exibir_login_quando_nao_autenticado', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ListaComprasApp()));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.entrar), findsOneWidget);
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
    await tester.pumpAndSettle();
    final context = tester.element(find.text(AppStrings.entrar));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
