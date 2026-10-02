import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_ordenar_categorias.dart';
import 'package:lista_compras/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const ConfiguracoesScreen(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirComCategorias(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/configuracoes',
      routes: [
        GoRoute(
          path: '/configuracoes',
          builder: (_, _) => const ConfiguracoesScreen(),
        ),
        GoRoute(
          path: '/categorias',
          builder: (_, _) => const TelaOrdenarCategorias(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_abrir_ordenar_categorias_quando_toca', (tester) async {
    await abrirComCategorias(tester);
    await tester.tap(find.text(AppStrings.ordenarCategorias));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.restaurarPadrao), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_secoes_quando_abrir', (tester) async {
    await abrir(tester);

    expect(find.text(AppStrings.aparencia), findsOneWidget);
    expect(find.text(AppStrings.sobre), findsOneWidget);
    expect(find.text(AppStrings.politicaPrivacidade), findsOneWidget);
    expect(find.text(AppStrings.versao), findsOneWidget);

    await tester.scrollUntilVisible(find.text(AppStrings.backup), 300);
    expect(find.text(AppStrings.backup), findsOneWidget);

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
}
