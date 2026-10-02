import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/app.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_visto': true,
      'idioma_app': 'pt',
    });
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
    expect(find.text('Minhas Listas'), findsOneWidget);
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
    final context = tester.element(find.text('Minhas Listas'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('deve_nao_expor_rotas_de_conta_quando_app_e_local', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final caminhos = _caminhosDeRotas(
      container.read(routerProvider).configuration.routes,
    );
    const proibidas = [
      '/login',
      '/registro',
      '/recuperar-senha',
      '/entrar',
      '/compartilhadas',
      '/membros',
    ];
    for (final proibida in proibidas) {
      expect(
        caminhos,
        isNot(contains(proibida)),
        reason: 'rota $proibida não deve existir no app local',
      );
    }
  });
}

/// Achata recursivamente os `path` de todas as rotas do `GoRouter`, incluindo
/// sub-rotas de `GoRoute` e as ramificações de `ShellRoute`/`StatefulShellRoute`.
List<String> _caminhosDeRotas(List<RouteBase> rotas) {
  final caminhos = <String>[];
  void visitar(RouteBase rota) {
    if (rota is GoRoute) {
      caminhos.add(rota.path);
      for (final filha in rota.routes) {
        visitar(filha);
      }
    } else if (rota is ShellRoute) {
      for (final filha in rota.routes) {
        visitar(filha);
      }
    } else if (rota is StatefulShellRoute) {
      for (final ramo in rota.branches) {
        for (final filha in ramo.routes) {
          visitar(filha);
        }
      }
    }
  }

  for (final rota in rotas) {
    visitar(rota);
  }
  return caminhos;
}
