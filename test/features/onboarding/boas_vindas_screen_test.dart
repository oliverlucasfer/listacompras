import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/features/onboarding/ui/boas_vindas_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_teste.dart';

void main() {
  testWidgets('deve_mostrar_destaques_quando_boas_vindas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: appTeste(const BoasVindasScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Funciona offline'), findsOneWidget);
    expect(find.text('Backup quando quiser'), findsOneWidget);
    expect(find.text('Importe por texto'), findsOneWidget);
    expect(find.text('Dite um item'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });

  testWidgets('deve_ocultar_destaque_de_voz_quando_sem_suporte', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: appTeste(const BoasVindasScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Funciona offline'), findsOneWidget);
    expect(find.text('Backup quando quiser'), findsOneWidget);
    expect(find.text('Importe por texto'), findsOneWidget);
    expect(find.text('Dite um item'), findsNothing);
    expect(find.text('Começar'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_omitir_compartilhar_e_sincronizar_quando_app_local', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(child: appTeste(const BoasVindasScreen())),
    );
    await tester.pumpAndSettle();

    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(textos.any((t) => t.toLowerCase().contains('compartilh')), isFalse);
    expect(textos.any((t) => t.toLowerCase().contains('sincroniz')), isFalse);

    expect(find.text('Backup quando quiser'), findsOneWidget);
    expect(
      find.text('Exporte e restaure suas listas num arquivo.'),
      findsOneWidget,
    );
    expect(find.text('Bem-vindo(a)'), findsOneWidget);
  });

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
    await tester.pumpWidget(ProviderScope(child: appTesteRouter(router)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Começar'));
    await tester.pumpAndSettle();

    expect(find.text('listas'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_visto'), isTrue);
  });
}
