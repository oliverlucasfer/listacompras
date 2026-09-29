import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/usuario_local.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  Future<void> montar(
    WidgetTester tester, {
    required Size tamanho,
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (seed != null) await seed(db);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
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
    expect(find.text(AppStrings.configuracoes), findsOneWidget);

    await tester.tap(find.text(AppStrings.configuracoes));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.aparencia), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_usar_navigation_rail_em_tela_larga', (tester) async {
    await montar(tester, tamanho: const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_voltar_para_aba_de_origem_quando_abrir_lista', (
    tester,
  ) async {
    await montar(
      tester,
      tamanho: const Size(500, 800),
      seed: (db) async {
        final repo = ListasRepository(db);
        await repo.criarLista(titulo: 'Minha lista', donoId: idLocal);
      },
    );

    await tester.tap(find.text('Minha lista'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.abaMinhas), findsOneWidget);

    await fechar(tester);
  });
}
