import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/item_local.dart';
import 'tables/lista_local.dart';
import 'tables/mutacao_pendente.dart';

part 'database.g.dart';

/// Fonte de verdade local (doc 03 §1). Espelha o schema Postgres (doc 01).
/// Testes injetam um executor (ex.: NativeDatabase.memory()).
@DriftDatabase(tables: [ListaLocal, ItemLocal, MutacaoPendente])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // SQLite não impõe FK por padrão; o Postgres (doc 01) sim — espelhar.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'lista_compras.sqlite'));
    return NativeDatabase(file);
  });
}
