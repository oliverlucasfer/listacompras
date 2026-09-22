import 'package:drift/drift.dart';

import 'conexao/conexao.dart';
import 'tables/historico_preco_local.dart';
import 'tables/item_local.dart';
import 'tables/lista_local.dart';
import 'tables/mutacao_pendente.dart';

part 'database.g.dart';

/// Fonte de verdade local (doc 03 §1). Espelha o schema Postgres (doc 01).
/// Testes injetam um executor (ex.: NativeDatabase.memory()).
@DriftDatabase(
  tables: [ListaLocal, ItemLocal, MutacaoPendente, HistoricoPrecoLocal],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  /// Datas como texto ISO-8601 com microssegundos: o armazenamento padrão
  /// (unix segundos) truncava `updated_at` e criava empates artificiais no
  /// LWW do sync (doc 03 §5).
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, de, para) async {
      if (de < 2) {
        // v1 → v2: converte unix segundos (inteiro) para texto ISO-8601.
        for (final tabela in const ['lista_local', 'item_local']) {
          await customStatement(
            "UPDATE $tabela SET "
            "created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at, 'unixepoch'), "
            "updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at, 'unixepoch'), "
            "deletado_em = strftime('%Y-%m-%dT%H:%M:%fZ', deletado_em, 'unixepoch')",
          );
        }
        await customStatement(
          "UPDATE mutacao_pendente SET "
          "ts_local = strftime('%Y-%m-%dT%H:%M:%fZ', ts_local, 'unixepoch')",
        );
      }
      if (de < 3) {
        // v2 → v3: coluna categoria (doc 01 §3.2, ADR-011, F6-T02) —
        // aditiva; itens existentes passam a 'outros' (default).
        await m.addColumn(itemLocal, itemLocal.categoria);
      }
      if (de < 4) {
        // v3 → v4: coluna preco_centavos (doc 01 §4.3, RF-21, F25) —
        // aditiva e nullable; itens existentes ficam sem preço (null).
        await m.addColumn(itemLocal, itemLocal.precoCentavos);
      }
      if (de < 5) {
        // v4 → v5: coluna arquivada_em (doc 01 §4.1, RF-22, F26).
        await m.addColumn(listaLocal, listaLocal.arquivadaEm);
      }
      if (de < 6) {
        // v5 → v6: coluna orcamento_centavos (doc 01 §4.1, RF-28, F36).
        await m.addColumn(listaLocal, listaLocal.orcamentoCentavos);
      }
      if (de < 7) {
        // v6 → v7: tabela local de histórico de preços (doc 05 §6.3,
        // RF-29, F37). Local-only: não sincroniza.
        await m.createTable(historicoPrecoLocal);
      }
    },
    beforeOpen: (details) async {
      // SQLite não impõe FK por padrão; o Postgres (doc 01) sim — espelhar.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openConnection() => abrirBancoLocal();
