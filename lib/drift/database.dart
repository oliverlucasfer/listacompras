import 'package:drift/drift.dart';

import 'conexao/conexao.dart';
import 'tables/historico_preco_local.dart';
import 'tables/ida_compra.dart';
import 'tables/item_ida.dart';
import 'tables/item_local.dart';
import 'tables/lista_local.dart';
import 'tables/orcamento_categoria.dart';

part 'database.g.dart';

/// Fonte de verdade local (doc 03 §1). Espelha o schema Postgres (doc 01).
/// Testes injetam um executor (ex.: NativeDatabase.memory()).
@DriftDatabase(
  tables: [
    ListaLocal,
    ItemLocal,
    HistoricoPrecoLocal,
    IdaCompra,
    ItemIda,
    OrcamentoCategoria,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 15;

  /// Paridade com o índice único parcial `uq_item_ativo` do Postgres
  /// (`0001_init.sql:57-59`): parcial não é expressável no `@TableIndex`.
  static const _criarIndiceItemAtivo =
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_item_ativo '
      'ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL';

  /// Índices de desempenho (revisão 05/10/2026): FK de `item_ida`, ordenação
  /// do histórico e listas ativas. Aditivos — não alteram dados.
  static const _criarIndicesDesempenho = [
    'CREATE INDEX IF NOT EXISTS idx_item_ida_ida_id ON item_ida (ida_id)',
    'CREATE INDEX IF NOT EXISTS idx_ida_compra_finalizada_em '
        'ON ida_compra (finalizada_em)',
    'CREATE INDEX IF NOT EXISTS idx_lista_local_ativa '
        'ON lista_local (updated_at) WHERE deletado_em IS NULL',
  ];

  /// Dedup defensivo antes de criar `uq_item_ativo` (F39): mantém 1 item ativo
  /// por `(lista_id, lower(nome))`; prefere a linha de `updated_at` mais
  /// recente, depois o maior `rowid`. Remove as perdedoras.
  Future<void> _dedupItensAtivos() async {
    await customStatement('''
      CREATE TEMP TABLE _dups_grupos AS
      SELECT i.lista_id AS lista_id, lower(i.nome) AS nome_lower
      FROM item_local i
      WHERE i.deletado_em IS NULL
      GROUP BY i.lista_id, lower(i.nome)
      HAVING COUNT(*) > 1
    ''');
    await customStatement('''
      CREATE TEMP TABLE _dups_remover AS
      SELECT i.id AS id
      FROM item_local i
      JOIN _dups_grupos g
        ON g.lista_id = i.lista_id AND g.nome_lower = lower(i.nome)
      WHERE i.deletado_em IS NULL
        AND i.id <> (
          SELECT j.id FROM item_local j
          WHERE j.lista_id = i.lista_id
            AND lower(j.nome) = g.nome_lower
            AND j.deletado_em IS NULL
          ORDER BY j.updated_at DESC, j.rowid DESC
          LIMIT 1
        )
    ''');
    await customStatement(
      'DELETE FROM item_local WHERE id IN (SELECT id FROM _dups_remover)',
    );
    await customStatement('DROP TABLE _dups_remover');
    await customStatement('DROP TABLE _dups_grupos');
  }

  /// Datas como texto ISO-8601 com microssegundos: o armazenamento padrão
  /// (unix segundos) truncava `updated_at` e criava empates artificiais de
  /// timestamp.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(_criarIndiceItemAtivo);
      for (final sql in _criarIndicesDesempenho) {
        await customStatement(sql);
      }
    },
    onUpgrade: (m, de, para) async {
      // G-29 (F43-T08): os passos abaixo recriam `item_local` a partir da
      // definição ATUAL (com `CHECK (quantidade <= 1000000)`); `quantidade` é
      // entrada do usuário sem teto no app. Sanitiza qualquer valor legado
      // antes de QUALQUER `alterTable` do upgrade — senão a cópia das linhas
      // viola o CHECK e o app não abre.
      await customStatement(
        'UPDATE item_local SET quantidade = 1000000 WHERE quantidade > 1000000',
      );
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
      if (de < 8) {
        // v7 → v8: barreiras locais espelhadas do Postgres (F39) —
        // dedup antes de recriar as tabelas com CHECK e de criar o índice.
        await _dedupItensAtivos();
        await m.alterTable(TableMigration(itemLocal));
        await m.alterTable(TableMigration(listaLocal));
        await customStatement(_criarIndiceItemAtivo);
      }
      if (de < 9) {
        // v8 → v9: teto de `quantidade` espelhado do Postgres (F43-T08) —
        // `alterTable` recria a tabela; o índice manual é refeito em seguida.
        await m.alterTable(TableMigration(itemLocal));
        await customStatement(_criarIndiceItemAtivo);
      }
      if (de < 10) {
        // v9 → v10: unidade `pt` no CHECK local, espelhando o enum do Postgres
        // (doc 01 §3.1, F45-T01) — `alterTable` recria a tabela.
        await m.alterTable(TableMigration(itemLocal));
        await customStatement(_criarIndiceItemAtivo);
      }
      if (de < 11) {
        // v10 → v11: sem sync não há fila de mutações (F48/RF-31).
        await m.deleteTable('mutacao_pendente');
      }
      if (de < 12) {
        // v11 → v12: idas de compra (RF-34, F50). Local-only; sem sync.
        await m.createTable(idaCompra);
        await m.createTable(itemIda);
      }
      if (de == 12) {
        // v12 → v13: mercado (loja) da ida (RF-35, F52). Bancos abaixo de v12
        // já criam `ida_compra` com a definição atual (passo `de < 12`), que
        // já inclui `mercado` — então a coluna só é adicionada a partir do v12.
        await m.addColumn(idaCompra, idaCompra.mercado);
      }
      if (de < 14) {
        // v13 → v14: limite de orçamento por categoria (RF-36, F53). Tabela
        // NOVA: acumulativo (`de < 14`), como `historico_preco_local` (`de < 7`)
        // e as idas (`de < 12`) — bancos abaixo do v14 precisam criá-la aqui,
        // já que nenhum passo anterior a cria.
        await m.createTable(orcamentoCategoria);
      }
      if (de < 15) {
        // v14 → v15: índices de desempenho (revisão 05/10/2026). Aditivo.
        for (final sql in _criarIndicesDesempenho) {
          await customStatement(sql);
        }
      }
    },
    beforeOpen: (details) async {
      // SQLite não impõe FK por padrão; o Postgres (doc 01) sim — espelhar.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openConnection() => abrirBancoLocal();
