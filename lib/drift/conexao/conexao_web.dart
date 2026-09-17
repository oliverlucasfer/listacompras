import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Banco local no navegador via Drift/WASM (OPFS quando disponível;
/// IndexedDB como fallback) — doc 05 §2, ADR-012.
QueryExecutor abrirBancoLocal() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'lista_compras',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
