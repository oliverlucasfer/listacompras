import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/app.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  ProviderContainer montarContainer(AppDatabase db) {
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('deve_abrir_na_home_de_listas_quando_inicia', (tester) async {
    final container = montarContainer(AppDatabase(NativeDatabase.memory()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ListaComprasApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.minhasListas), findsOneWidget);
  });

  testWidgets('deve_aplicar_tema_escuro_quando_sistema_esta_escuro', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final container = montarContainer(AppDatabase(NativeDatabase.memory()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ListaComprasApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text(AppStrings.minhasListas));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
