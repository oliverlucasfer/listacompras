import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/usuario_local.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monta o app real (router) com Drift in-memory e a última lista gravada.
Future<ProviderContainer> _montar(
  WidgetTester tester, {
  String? ultimaListaId,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_visto': true,
    'ultima_lista_id': ?ultimaListaId,
  });
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
  return container;
}

Future<void> _semearLista(AppDatabase db, String id, String titulo) async {
  final agora = DateTime.utc(2026, 1, 1);
  await db
      .into(db.listaLocal)
      .insert(
        ListaLocalCompanion.insert(
          id: id,
          createdAt: agora,
          updatedAt: agora,
          titulo: titulo,
          donoId: idLocal,
        ),
      );
}

void main() {
  testWidgets('deve_abrir_ultima_lista_e_focar_campo_quando_rota_adicionar', (
    tester,
  ) async {
    final container = await _montar(
      tester,
      ultimaListaId: 'l1',
      seed: (db) => _semearLista(db, 'l1', 'Minha lista'),
    );
    final router = container.read(routerProvider);

    router.go('/adicionar');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/lista/l1');
    final campos = find.byType(EditableText);
    expect(campos, findsOneWidget);
    expect(tester.widget<EditableText>(campos).focusNode.hasFocus, isTrue);
  });

  testWidgets('deve_ir_para_listas_quando_nao_ha_lista', (tester) async {
    final container = await _montar(tester, ultimaListaId: 'inexistente');
    final router = container.read(routerProvider);

    router.go('/adicionar');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/listas');
  });
}
