import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/fakes.dart';

class _AuthAutenticado extends SupabaseAuthRepository {
  _AuthAutenticado() : super(Supabase.instance.client);

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();

  @override
  Session? get sessaoAtual => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    refreshToken: 'refresh',
    expiresIn: 3600,
    user: User(
      id: 'user-a',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

void main() {
  setUpAll(inicializarSupabaseTeste);

  Future<void> montar(WidgetTester tester, {required Size tamanho}) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_AuthAutenticado()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_usar_navigation_bar_em_tela_estreita_e_trocar_aba', (
    tester,
  ) async {
    await montar(tester, tamanho: const Size(500, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.abaMinhas), findsOneWidget);
    expect(find.text(AppStrings.compartilhadas), findsOneWidget);
    expect(find.text(AppStrings.abaAjustes), findsOneWidget);

    await tester.tap(find.text(AppStrings.abaAjustes));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.configuracoes), findsWidgets);
    expect(find.text(AppStrings.sair), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_usar_navigation_rail_em_tela_larga', (tester) async {
    await montar(tester, tamanho: const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await fechar(tester);
  });
}
