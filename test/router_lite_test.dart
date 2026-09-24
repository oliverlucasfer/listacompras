import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/login_screen.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Confinamento de URL do go_router (18): devolve a lista de rotas casadas
/// para uma URI, sem navegar. É o ponto mais barato para provar que uma rota
/// não existe na tabela.
Iterable<RouteMatchBase> _rotasCasadas(GoRouter router, String location) =>
    router.configuration.findMatch(Uri.parse(location)).matches;

void main() {
  testWidgets('deve_abrir_listas_e_nao_ter_login_quando_modo_lite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    // `routerProvider` é o alvo: o modo Lite não pode sequer CONTER rotas de
    // conta/convite na tabela (não basta redirecionar). Sem as condicionais
    // que esta task introduz, `/login` casa normalmente.
    final router = container.read(routerProvider);
    for (final rota in const [
      '/login',
      '/registro',
      '/recuperar-senha',
      '/redefinir-senha',
      '/entrar',
      '/login-callback',
      '/compartilhadas',
      '/membros/abc',
    ]) {
      expect(
        _rotasCasadas(router, rota),
        isEmpty,
        reason: 'rota $rota não deve existir no modo Lite',
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MinhasListasScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
