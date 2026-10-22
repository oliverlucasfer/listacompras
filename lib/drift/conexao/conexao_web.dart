import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Banco local no navegador via Drift/WASM (OPFS quando disponível;
/// IndexedDB como fallback) — doc 05 §2, ADR-012.
QueryExecutor abrirBancoLocal() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'lista_compras',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    final executor = result.resolvedExecutor;
    if (const bool.fromEnvironment('DEMO')) {
      _agendarFlushPeriodico(executor);
    }
    return executor;
  });
}

/// O VFS IndexedDB do sqlite3 grava de forma assíncrona e, sem COOP/COEP não
/// há OPFS; escritas dentro de transações só chegam ao IndexedDB quando outra
/// escrita fora de transação acontece. Um `SELECT 1` encadeado força o flush
/// no build de demo, evitando perder dados ao recarregar a página. O próximo
/// tick só é agendado quando o anterior termina, e falhas repetidas desligam o
/// laço em vez de martelar o banco.
void _agendarFlushPeriodico(QueryExecutor executor) {
  var falhas = 0;
  Timer? timer;

  Future<void> executar() async {
    try {
      await executor.runCustom('SELECT 1');
      falhas = 0;
    } catch (erro) {
      falhas++;
      if (falhas <= 3) {
        debugPrint('flush do demo falhou ($falhas): $erro');
      }
      if (falhas >= 3) {
        timer?.cancel();
        return;
      }
    }
    timer = Timer(const Duration(seconds: 1), executar);
  }

  timer = Timer(const Duration(seconds: 1), executar);
}
