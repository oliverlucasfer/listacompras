import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/providers/backup_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  test('deve_forcar_dono_local_no_provider_quando_modo_lite', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final lite = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(lite.dispose);

    final colaborativo = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.colaborativo),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(colaborativo.dispose);

    expect(lite.read(backupRepositoryProvider).donoLocal, isTrue);
    expect(colaborativo.read(backupRepositoryProvider).donoLocal, isFalse);
  });
}
