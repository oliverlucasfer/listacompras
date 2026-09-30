import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/providers/backup_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  test('deve_construir_repositorio_de_backup_local_quando_provider', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final json = await container.read(backupRepositoryProvider).exportarJson();
    expect(jsonDecode(json), containsPair('versao', 2));
  });
}
