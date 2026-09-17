import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Banco local em arquivo (Android/iOS/desktop) — doc 05 §2, ADR-012.
QueryExecutor abrirBancoLocal() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'lista_compras.sqlite'));
    return NativeDatabase(file);
  });
}
