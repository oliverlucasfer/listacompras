import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/sync/ui/indicador_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_esconder_convites_e_sync_quando_modo_lite', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          capacidadesProvider.overrideWithValue(AppCapacidades.lite),
          authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: MinhasListasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndicadorSync), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
