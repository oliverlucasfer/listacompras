import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/onboarding/ui/boas_vindas_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_mostrar_destaques_quando_boas_vindas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: const BoasVindasScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.boasVindasOffline), findsOneWidget);
    expect(find.text(AppStrings.boasVindasCompartilhar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasImportar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasDitar), findsOneWidget);
    expect(find.text(AppStrings.comecar), findsOneWidget);
  });

  testWidgets('deve_ocultar_destaque_de_voz_quando_sem_suporte', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: const BoasVindasScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.boasVindasOffline), findsOneWidget);
    expect(find.text(AppStrings.boasVindasCompartilhar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasImportar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasDitar), findsNothing);
    expect(find.text(AppStrings.comecar), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_omitir_compartilhar_e_mostrar_backup_quando_modo_lite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [capacidadesProvider.overrideWithValue(AppCapacidades.lite)],
        child: MaterialApp(home: const BoasVindasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.boasVindasCompartilhar), findsNothing);
    expect(find.text(AppStrings.boasVindasCompartilharDica), findsNothing);
    expect(find.text(AppStrings.boasVindasSubtitulo), findsNothing);

    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(textos.any((t) => t.toLowerCase().contains('compartilh')), isFalse);

    expect(find.text(AppStrings.boasVindasBackup), findsOneWidget);
    expect(find.text(AppStrings.boasVindasBackupDica), findsOneWidget);
  });

  testWidgets(
    'deve_mostrar_compartilhar_e_omitir_backup_quando_modo_colaborativo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: const BoasVindasScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.boasVindasCompartilhar), findsOneWidget);
      expect(find.text(AppStrings.boasVindasCompartilharDica), findsOneWidget);
      expect(find.text(AppStrings.boasVindasBackup), findsNothing);
    },
  );

  testWidgets('deve_marcar_visto_e_navegar_quando_comecar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/boas-vindas',
      routes: [
        GoRoute(
          path: '/boas-vindas',
          builder: (_, _) => const BoasVindasScreen(),
        ),
        GoRoute(path: '/listas', builder: (_, _) => const Text('listas')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.comecar));
    await tester.pumpAndSettle();

    expect(find.text('listas'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_visto'), isTrue);
  });
}
