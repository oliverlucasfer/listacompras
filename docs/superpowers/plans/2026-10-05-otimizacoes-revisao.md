# Otimizações da Revisão — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar full-scans/recomputações na camada Drift e rebuilds desnecessários na UI, e quitar a dívida técnica mapeada na revisão de 05/10/2026.

**Architecture:** App Flutter offline-first; o Drift é a fonte da verdade e a UI é reativa via Riverpod. As mudanças preservam 100% do comportamento observável (mesmos resultados, mesmas rotas), otimizando consultas (índices, agregação no SQL, batch de escritas) e reduzindo o escopo de recomputação na UI (providers derivados, `select`, widgets isolados). A migração Drift v15 apenas cria índices (aditiva, sem tocar dados).

**Tech Stack:** Flutter, Riverpod 3, go_router, Drift/SQLite, `flutter_test`, `drift/native` (in-memory).

**Spec:** Revisão registrada na conversa de 05/10/2026 (achados verificados por leitura e grep). Docs donos tocados: [05](../05-app-flutter.md) (comportamento/UI), [15](../15-design-system.md) (design system), 03 (dados sincronizados — hoje só histórico local), [14](../14-tarefas.md) e [00](../00-visao-geral.md) (ADR-015 local-only). Em qualquer divergência, o doc dono vence.

## Global Constraints

- **Sem rede/conta/sync:** o Drift é a fonte da verdade; nenhuma tarefa pode introduzir dependência de rede, conta ou sync (ADR-015, RF-31).
- **API de escala de teste atual:** `flutter test` deve terminar verde após **cada** tarefa; `dart format .` e `flutter analyze` limpos (CI exige — [07 §3](../07-qualidade-ci.md)).
- **Enum de unidades fechado:** `un, kg, g, l, ml, caixa, pacote, pct, pt, dz` — idêntico em `lib/core/dominio/unidade.dart` e no parser.
- **Enum de categorias fechado:** 11 valores, ordem do enum = ordem dos grupos.
- **Sem chave/segredo** em código, commit ou log.
- **`item_local` e `sqlite3` permanecem no `pubspec`:** `sqlite3` é dependência direta de teste (G-53) — não remover.
- **Índices:** usar `customStatement('CREATE ... IF NOT EXISTS ...')` (mesmo padrão do `_criarIndiceItemAtivo`), não `@TableIndex`, para manter a migração explícita e testável.
- **Nomes de teste:** `deve_<resultado>_quando_<condição>`.
- **Sem comentários desnecessários;** preservar o estilo pt-BR dos existentes.

---

## Fase 1 — Camada de dados (Drift)

### Task 1: Índices de desempenho + migração v15

**Files:**
- Modify: `lib/drift/database.dart`
- Test: `test/drift/database_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` atual (`schemaVersion = 14`, `_criarIndiceItemAtivo`).
- Produces: `schemaVersion = 15`; índices `idx_item_ida_ida_id`, `idx_ida_compra_finalizada_em`, `idx_lista_local_ativa`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/drift/database_test.dart`, adicionar ao final de `main()`:

```dart
  test('deve_criar_indices_de_desempenho_quando_instalacao_nova', () async {
    final indices = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ("
          "'idx_item_ida_ida_id','idx_ida_compra_finalizada_em',"
          "'idx_lista_local_ativa')",
        )
        .get();
    expect(
      indices.map((r) => r.data['name']).toSet(),
      {
        'idx_item_ida_ida_id',
        'idx_ida_compra_finalizada_em',
        'idx_lista_local_ativa',
      },
    );
  });

  test('deve_criar_indices_de_desempenho_quando_migrar_v14_para_v15', () async {
    final arquivo = File(
      '${Directory.systemTemp.path}/v14_para_v15_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (arquivo.existsSync()) arquivo.deleteSync();
    });

    final antigo = sq3.sqlite3.open(arquivo.path);
    antigo.execute('''
      CREATE TABLE lista_local (
        id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL, titulo TEXT NOT NULL, dono_id TEXT NOT NULL,
        deletado_em TEXT NULL, arquivada_em TEXT NULL,
        orcamento_centavos INTEGER NULL
      );
      CREATE TABLE item_local (
        id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL, lista_id TEXT NOT NULL,
        nome TEXT NOT NULL, quantidade REAL NOT NULL DEFAULT 1.0,
        unidade TEXT NOT NULL DEFAULT 'un',
        categoria TEXT NOT NULL DEFAULT 'outros',
        preco_centavos INTEGER NULL,
        concluido INTEGER NOT NULL DEFAULT 0,
        ordem INTEGER NOT NULL DEFAULT 0, deletado_em TEXT NULL
      );
      CREATE TABLE ida_compra (
        id TEXT NOT NULL PRIMARY KEY, lista_id TEXT NULL,
        titulo TEXT NOT NULL, finalizada_em TEXT NOT NULL,
        total_centavos INTEGER NOT NULL DEFAULT 0,
        itens_count INTEGER NOT NULL DEFAULT 0, mercado TEXT NULL
      );
      CREATE TABLE item_ida (
        id TEXT NOT NULL PRIMARY KEY, ida_id TEXT NOT NULL,
        nome TEXT NOT NULL, quantidade REAL NOT NULL DEFAULT 1.0,
        unidade TEXT NOT NULL DEFAULT 'un',
        categoria TEXT NOT NULL DEFAULT 'outros',
        preco_centavos INTEGER NULL
      );
      PRAGMA user_version = 14;
    ''');
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    final indices = await migrado
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ("
          "'idx_item_ida_ida_id','idx_ida_compra_finalizada_em',"
          "'idx_lista_local_ativa')",
        )
        .get();
    expect(
      indices.map((r) => r.data['name']).toSet(),
      {
        'idx_item_ida_ida_id',
        'idx_ida_compra_finalizada_em',
        'idx_lista_local_ativa',
      },
    );
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/drift/database_test.dart`
Expected: FAIL — índices não existem (`schemaVersion` ainda 14 e nenhum `CREATE INDEX`).

- [ ] **Step 3: Implementar**

Em `lib/drift/database.dart`:

1. Trocar `int get schemaVersion => 14;` por `int get schemaVersion => 15;`.
2. Adicionar a lista de statements logo após `_criarIndiceItemAtivo`:

```dart
  /// Índices de desempenho (revisão 05/10/2026): FK de `item_ida`, ordenação
  /// do histórico e listas ativas. Aditivos — não alteram dados.
  static const _criarIndicesDesempenho = [
    'CREATE INDEX IF NOT EXISTS idx_item_ida_ida_id ON item_ida (ida_id)',
    'CREATE INDEX IF NOT EXISTS idx_ida_compra_finalizada_em '
        'ON ida_compra (finalizada_em)',
    'CREATE INDEX IF NOT EXISTS idx_lista_local_ativa '
        'ON lista_local (updated_at) WHERE deletado_em IS NULL',
  ];
```

3. Em `onCreate`, após `await customStatement(_criarIndiceItemAtivo);`:

```dart
      for (final sql in _criarIndicesDesempenho) {
        await customStatement(sql);
      }
```

4. Em `onUpgrade`, adicionar após o bloco `if (de < 14) { ... }`:

```dart
      if (de < 15) {
        // v14 → v15: índices de desempenho (revisão 05/10/2026). Aditivo.
        for (final sql in _criarIndicesDesempenho) {
          await customStatement(sql);
        }
      }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/drift/database_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/drift/database.dart test/drift/database_test.dart
git commit -m "perf(drift): indices de desempenho e migracao v15 (RF-31)"
```

---

### Task 2: Lote transacional em `adicionarItensDedup` e `duplicarLista`

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart:312-324` (dedup em lote) e `:478-514` (duplicar)
- Test: `test/features/listas/listas_repository_test.dart`

**Interfaces:**
- Consumes: `_db`, `_uuid`, `normalizarTexto`, `Unidade`, `CategoriaItem`.
- Produces: `adicionarItensDedup` com **uma** leitura de itens + **um** `transaction`; `duplicarLista` com inserts em `_db.batch` e `ordem` incremental. Contrato público inalterado (mesmos nomes/assinaturas).

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/listas/listas_repository_test.dart`, adicionar:

```dart
  Item itemLote(String nome, {double quantidade = 1, Unidade unidade = Unidade.un}) {
    final agora = DateTime.now().toUtc();
    return Item(
      id: 'lote-$nome', listaId: 'l', nome: nome, quantidade: quantidade,
      unidade: unidade, categoria: CategoriaItem.mercearia,
      concluido: true, ordem: 0, criadoEm: agora, atualizadoEm: agora,
    );
  }

  test('deve_somar_quando_unidade_igual_e_inserir_quando_novo_no_lote', () async {
    final lista = await repo.criarLista(titulo: 'Lote', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 2);

    await repo.adicionarItensDedup(lista.id, [
      itemLote('arroz'), // unidade 'un' igual -> soma 2 + 1 = 3
      itemLote('Feijão', quantidade: 3, unidade: Unidade.kg), // novo -> insere
    ]);

    final itens = await repo.watchItensDaLista(lista.id).first;
    expect(itens.length, 2);
    final arroz = itens.firstWhere((i) => i.nome.toLowerCase() == 'arroz');
    expect(arroz.quantidade, 3);
    final feijao = itens.firstWhere((i) => i.nome == 'Feijão');
    expect(feijao.concluido, isFalse); // RF-23 ignora concluído
    expect(feijao.quantidade, 3);
  });

  test('deve_substituir_quando_unidade_diferente_no_lote', () async {
    final lista = await repo.criarLista(titulo: 'Lote2', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 2);

    await repo.adicionarItensDedup(lista.id, [
      itemLote('arroz', quantidade: 1, unidade: Unidade.kg),
    ]);

    final itens = await repo.watchItensDaLista(lista.id).first;
    final arroz = itens.single;
    expect(arroz.quantidade, 1); // unidade diferente -> substitui
    expect(arroz.unidade, Unidade.kg);
  });
```

```dart
  test('deve_copiar_pendentes_com_ordem_sequencial_quando_duplicar_lista', () async {
    final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'A');
    await repo.adicionarItem(listaId: origem.id, nome: 'B');
    await repo.adicionarItem(listaId: origem.id, nome: 'C', precoCentavos: 500);

    final nova = await repo.duplicarLista(
      origemId: origem.id, titulo: 'Copia', donoId: 'user-a',
    );

    final itens = await repo.watchItensDaLista(nova.id).first;
    expect(itens.map((i) => i.nome), ['A', 'B', 'C']);
    expect(itens.map((i) => i.ordem), [0, 1, 2]);
    expect(itens.last.precoCentavos, 500);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: os dois testes novos PASSAM já hoje (salvo a asserção corrigida). Se passarem, **manter** — são testes de regressão que fixam o contrato antes do refactor (TDD de caracterização). Se algo divergir, corrigir o teste para o contrato real e só então refatorar.

- [ ] **Step 3: Implementar `adicionarItensDedup` em lote**

Substituir o corpo do método (`:312-324`) por:

```dart
  /// Adiciona um lote de itens (RF-23), um a um pela dedup, em **uma** leitura
  /// e **uma** transação. Copia nome/quantidade/unidade/categoria; ignora
  /// preço e concluído.
  Future<void> adicionarItensDedup(String listaId, Iterable<Item> itens) {
    return _db.transaction(() async {
      final ativos =
          await (_db.select(_db.itemLocal)..where(
                (i) => i.listaId.equals(listaId) & i.deletadoEm.isNull(),
              ))
              .get();
      final porNome = <String, ({String id, double qtd, String unidade})>{
        for (final i in ativos)
          normalizarTexto(i.nome): (id: i.id, qtd: i.quantidade, unidade: i.unidade),
      };
      var proxima = ativos.fold<int>(
        0,
        (maior, i) => i.ordem >= maior ? i.ordem + 1 : maior,
      );
      final agora = DateTime.now().toUtc();
      for (final item in itens) {
        final chave = normalizarTexto(item.nome);
        final existente = porNome[chave];
        if (existente != null) {
          final mesmaUnidade = existente.unidade == item.unidade.valor;
          final qtd = mesmaUnidade
              ? existente.qtd + item.quantidade
              : item.quantidade;
          await (_db.update(
            _db.itemLocal,
          )..where((i) => i.id.equals(existente.id))).write(
            ItemLocalCompanion(
              quantidade: Value(qtd),
              unidade: Value(item.unidade.valor),
              updatedAt: Value(agora),
            ),
          );
          porNome[chave] = (
            id: existente.id,
            qtd: qtd,
            unidade: item.unidade.valor,
          );
          continue;
        }
        final id = _uuid.v4();
        await _db
            .into(_db.itemLocal)
            .insert(
              ItemLocalCompanion.insert(
                id: id,
                createdAt: agora,
                updatedAt: agora,
                listaId: listaId,
                nome: item.nome,
                quantidade: Value(item.quantidade),
                unidade: Value(item.unidade.valor),
                categoria: Value(item.categoria.valor),
                ordem: Value(proxima++),
              ),
            );
        porNome[chave] = (
          id: id,
          qtd: item.quantidade,
          unidade: item.unidade.valor,
        );
      }
    });
  }
```

- [ ] **Step 4: Implementar `duplicarLista` com batch**

Substituir o bloco `final nova = ... for (...) { await adicionarItem(...) }` (`:501-511`) por:

```dart
      final agora = DateTime.now().toUtc();
      final novaId = _uuid.v4();
      await _db
          .into(_db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: novaId,
              createdAt: agora,
              updatedAt: agora,
              titulo: titulo,
              donoId: donoId,
            ),
          );
      await _db.batch((b) {
        for (var ordem = 0; ordem < pendentes.length; ordem++) {
          final item = pendentes[ordem];
          b.insert(
            _db.itemLocal,
            ItemLocalCompanion.insert(
              id: _uuid.v4(),
              createdAt: agora,
              updatedAt: agora,
              listaId: novaId,
              nome: item.nome,
              quantidade: Value(item.quantidade),
              unidade: Value(item.unidade),
              categoria: Value(item.categoria),
              precoCentavos: Value(item.precoCentavos),
              ordem: Value(ordem),
            ),
          );
        }
      });
      return Lista(
        id: novaId,
        titulo: titulo,
        donoId: donoId,
        criadoEm: agora,
        atualizadoEm: agora,
      );
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS (incluindo os testes de dedup/duplicar já existentes).

- [ ] **Step 6: Commit**

```bash
git add lib/features/listas/data/listas_repository.dart test/features/listas/listas_repository_test.dart
git commit -m "perf(listas): dedup em lote e duplicar com batch (RF-10, RF-20, RF-23)"
```

---

### Task 3: Escritas em massa (`desmarcarTodos`, `limparConcluidos`, `reordenarItens`)

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart:407-472`
- Test: `test/features/listas/listas_repository_test.dart`

**Interfaces:**
- Produces: `desmarcarTodos` = 1 `UPDATE`; `limparConcluidos` = 1 `SELECT` + 1 `UPDATE` (retorna os mesmos itens para undo); `reordenarItens` = 1 `SELECT` + `batch` de updates só dos que mudaram. Assinaturas inalteradas.

- [ ] **Step 1: Escrever os testes que falham**

```dart
  test('deve_desmarcar_todos_quando_havia_concluidos', () async {
    final lista = await repo.criarLista(titulo: 'Massa', donoId: 'user-a');
    final a = await repo.adicionarItem(listaId: lista.id, nome: 'A');
    final b = await repo.adicionarItem(listaId: lista.id, nome: 'B');
    await repo.editarItem(a.id, concluido: true);
    await repo.editarItem(b.id, concluido: true);

    await repo.desmarcarTodos(lista.id);

    final itens = await repo.watchItensDaLista(lista.id).first;
    expect(itens.every((i) => !i.concluido), isTrue);
  });

  test('deve_retornar_itens_removidos_quando_limpar_concluidos', () async {
    final lista = await repo.criarLista(titulo: 'Limpar', donoId: 'user-a');
    final a = await repo.adicionarItem(listaId: lista.id, nome: 'A');
    await repo.adicionarItem(listaId: lista.id, nome: 'B');
    await repo.editarItem(a.id, concluido: true);

    final removidos = await repo.limparConcluidos(lista.id);

    expect(removidos.map((i) => i.id), [a.id]);
    final itens = await repo.watchItensDaLista(lista.id).first;
    expect(itens.map((i) => i.nome), ['B']);
  });

  test('deve_gravar_nova_ordem_quando_reordenar', () async {
    final lista = await repo.criarLista(titulo: 'Ordem', donoId: 'user-a');
    final a = await repo.adicionarItem(listaId: lista.id, nome: 'A');
    final b = await repo.adicionarItem(listaId: lista.id, nome: 'B');
    final c = await repo.adicionarItem(listaId: lista.id, nome: 'C');

    await repo.reordenarItens(lista.id, [c.id, a.id, b.id]);

    final itens = await repo.watchItensDaLista(lista.id).first;
    expect(itens.map((i) => i.nome), ['C', 'A', 'B']);
    expect(itens.map((i) => i.ordem), [0, 1, 2]);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS na lógica atual (caracterização); o objetivo é provar equivalência antes do refactor.

- [ ] **Step 3: Implementar**

Substituir `desmarcarTodos` por um único update:

```dart
  Future<void> desmarcarTodos(String listaId) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.itemLocal)..where(
            (i) =>
                i.listaId.equals(listaId) &
                i.deletadoEm.isNull() &
                i.concluido.equals(true),
          ))
          .write(
            ItemLocalCompanion(
              concluido: const Value(false),
              updatedAt: Value(agora),
            ),
          );
    });
  }
```

Substituir `limparConcluidos` por um `UPDATE ... IN (ids)`:

```dart
  Future<List<Item>> limparConcluidos(String listaId) {
    return _db.transaction(() async {
      final concluidos =
          await (_db.select(_db.itemLocal)..where(
                (i) =>
                    i.listaId.equals(listaId) &
                    i.deletadoEm.isNull() &
                    i.concluido.equals(true),
              ))
              .get();
      if (concluidos.isEmpty) return const <Item>[];
      final agora = DateTime.now().toUtc();
      final ids = [for (final i in concluidos) i.id];
      await (_db.update(
        _db.itemLocal,
      )..where((i) => i.id.isIn(ids))).write(
        ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
      return concluidos.map(Item.fromLocal).toList();
    });
  }
```

Substituir `reordenarItens` por mapa + batch:

```dart
  Future<void> reordenarItens(String listaId, List<String> idsOrdenados) {
    return _db.transaction(() async {
      final itens =
          await (_db.select(_db.itemLocal)..where(
                (i) => i.listaId.equals(listaId) & i.deletadoEm.isNull(),
              ))
              .get();
      final ordemAtual = {for (final i in itens) i.id: i.ordem};
      final agora = DateTime.now().toUtc();
      final mudancas = <(String, int)>[];
      for (var posicao = 0; posicao < idsOrdenados.length; posicao++) {
        final id = idsOrdenados[posicao];
        if (ordemAtual[id] == null || ordemAtual[id] == posicao) continue;
        mudancas.add((id, posicao));
      }
      if (mudancas.isEmpty) return;
      await _db.batch((b) {
        for (final (id, ordem) in mudancas) {
          b.update(
            _db.itemLocal,
            ItemLocalCompanion(ordem: Value(ordem), updatedAt: Value(agora)),
            where: (i) => i.id.equals(id),
          );
        }
      });
    });
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/data/listas_repository.dart test/features/listas/listas_repository_test.dart
git commit -m "perf(listas): desmarcar/limpar/reordenar com updates em massa (RF-04, RF-05)"
```

---

### Task 4: `finalizar` com `insertAll` de `item_ida`

**Files:**
- Modify: `lib/features/historico/data/historico_compras_repository.dart:61-75`
- Test: `test/features/historico/finalizar_compra_test.dart`

**Interfaces:**
- Produces: `finalizar` insere os snapshots num único `batch` (comportamento/ordem idênticos).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar (se ainda não existir) um teste que finalize com 3 concluídos e verifique os 3 itens:

```dart
  test('deve_gravar_todos_os_itens_quando_finalizar', () async {
    // setUp deste arquivo já cria db/repo; ajustar aos helpers locais.
    final lista = await repo.criarLista(titulo: 'Ida', donoId: 'user-a');
    for (final nome in ['A', 'B', 'C']) {
      final item = await repo.adicionarItem(listaId: lista.id, nome: nome);
      await repo.editarItem(item.id, concluido: true);
    }
    final ida = await historico.finalizar(lista.id);
    final itens = await historico.itensDaIda(ida.id);
    expect(itens.map((i) => i.nome).toSet(), {'A', 'B', 'C'});
    expect(ida.itensCount, 3);
  });
```

> Se o arquivo já tiver um teste equivalente, pular a criação e usar o existente como regressão.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/historico/finalizar_compra_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Substituir o loop de insert (`:61-75`) por:

```dart
      await _db.batch((b) {
        for (final i in concluidos) {
          b.insert(
            _db.itemIda,
            ItemIdaCompanion.insert(
              id: _uuid.v4(),
              idaId: idaId,
              nome: i.nome,
              quantidade: Value(i.quantidade),
              unidade: Value(i.unidade),
              categoria: Value(i.categoria),
              precoCentavos: Value(i.precoCentavos),
            ),
          );
        }
      });
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/historico/finalizar_compra_test.dart test/features/historico/finalizar_mercado_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/data/historico_compras_repository.dart test/features/historico/
git commit -m "perf(historico): finalizar com insertAll dos itens da ida (RF-34)"
```

---

## Fase 2 — Consultas e estatísticas

### Task 5: Agregações no SQL (`resumo`, `gastoPorMes`, `gastoPorCategoria`, `gastoPorMercado`)

**Files:**
- Modify: `lib/features/historico/data/historico_compras_repository.dart`
- Test: `test/features/historico/historico_compras_repository_test.dart` e `estatisticas_repository_test.dart`

**Interfaces:**
- Produces: mesmos tipos de retorno (`ResumoHistorico`, `List<GastoPorMes>`, `List<GastoPorCategoria>`, `List<GastoPorMercado>`), agora agregados com `SUM/COUNT/GROUP BY`. Ordenações e regras (só itens com preço; média arredondada) inalteradas.

- [ ] **Step 1: Escrever os testes que falham**

Garantir cobertura de equivalência (valores exatos):

```dart
  test('deve_somar_e_agrupar_quando_calcular_estatisticas', () async {
    // criar 2 idas em meses diferentes com itens/categorias/mercados
    // ... (usar os helpers do arquivo de teste)
    final resumo = await historico.resumo();
    expect(resumo.nIdas, 2);
    expect(resumo.totalGeralCentavos, 1500);
    expect(resumo.ticketMedioCentavos, 750);
    expect((await historico.gastoPorMes()).map((m) => m.totalCentavos).toList(),
        [500, 1000]);
    final cat = await historico.gastoPorCategoria();
    expect(cat.firstWhere((c) => c.categoria == CategoriaItem.mercearia).totalCentavos, 1500);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/historico/historico_compras_repository_test.dart test/features/historico/estatisticas_repository_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Substituir `resumo`, `gastoPorMes`, `gastoPorCategoria` e `gastoPorMercado` por consultas agregadas. Padrão:

```dart
  Future<ResumoHistorico> resumo() async {
    final linhas = await _db
        .customSelect(
          'SELECT COUNT(*) AS n, COALESCE(SUM(total_centavos), 0) AS total '
          'FROM ida_compra',
        )
        .getSingle();
    final n = linhas.read<int>('n');
    final total = linhas.read<int>('total');
    return ResumoHistorico(
      totalGeralCentavos: total,
      ticketMedioCentavos: n == 0 ? 0 : (total / n).round(),
      nIdas: n,
    );
  }

  Future<List<GastoPorMes>> gastoPorMes() async {
    // `substr(1,7)` em vez de `strftime`: as datas são texto ISO-8601 do Drift
    // (`storeDateTimeAsText`) e o parsing fica em Dart, sem depender do
    // reconhecimento de 'Z' pelo SQLite.
    final linhas = await _db
        .customSelect(
          'SELECT substr(finalizada_em, 1, 7) AS ano_mes, '
          'SUM(total_centavos) AS total FROM ida_compra '
          'GROUP BY ano_mes ORDER BY ano_mes',
        )
        .get();
    return [
      for (final r in linhas)
        GastoPorMes(
          mes: DateTime.utc(
            int.parse(r.read<String>('ano_mes').substring(0, 4)),
            int.parse(r.read<String>('ano_mes').substring(5, 7)),
          ),
          totalCentavos: r.read<int>('total'),
        ),
    ];
  }

  Future<List<GastoPorCategoria>> gastoPorCategoria() async {
    final linhas = await _db
        .customSelect(
          'SELECT categoria, '
          'SUM(CAST(ROUND(quantidade * preco_centavos) AS INTEGER)) AS total '
          'FROM item_ida WHERE preco_centavos IS NOT NULL '
          'GROUP BY categoria',
        )
        .get();
    final lista = [
      for (final r in linhas)
        GastoPorCategoria(
          categoria: CategoriaItem.fromValor(r.read<String>('categoria')),
          totalCentavos: r.read<int>('total'),
        ),
    ]..sort((a, b) => b.totalCentavos.compareTo(a.totalCentavos));
    return lista;
  }
```

`gastoPorMercado` (agrupando por `mercado`, preservando "Sem mercado" e exibição original):

```dart
  Future<List<GastoPorMercado>> gastoPorMercado() async {
    final linhas = await _db
        .customSelect(
          'SELECT mercado, SUM(total_centavos) AS total FROM ida_compra '
          'GROUP BY mercado',
        )
        .get();
    final totais = <String?, int>{};
    final exibicao = <String, String>{};
    for (final r in linhas) {
      final m = r.read<String?>('mercado');
      final chave = (m == null || m.trim().isEmpty) ? null : normalizarTexto(m);
      if (chave != null) exibicao.putIfAbsent(chave, () => m!);
      totais[chave] = (totais[chave] ?? 0) + r.read<int>('total');
    }
    final lista = [
      for (final e in totais.entries)
        GastoPorMercado(
          mercado: e.key == null ? null : exibicao[e.key]!,
          totalCentavos: e.value,
        ),
    ]..sort((a, b) => b.totalCentavos.compareTo(a.totalCentavos));
    return lista;
  }
```

> Atenção: `CAST(quantidade * preco_centavos AS INTEGER)` trunca; a regra atual usa `(quantidade * preco).round()`. Para bater exatamente, arredondar em vez de truncar. Usar `CAST(ROUND(quantidade * preco_centavos) AS INTEGER)`. Ajustar o teste para confirmar (ex.: `1.5 * 333 = 499.5` → 500).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/historico/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/data/historico_compras_repository.dart test/features/historico/
git commit -m "perf(historico): agregacoes de estatisticas no SQL (RF-34)"
```

---

### Task 6: Filtro por unidade no SQL + providers `autoDispose`

**Files:**
- Modify: `lib/features/historico/data/historico_compras_repository.dart` (`evolucaoPreco`, `unidadeRecenteComprada`, `precosPorMercado`, `itensMaisComprados`, `nomesComprados`)
- Modify: `lib/features/historico/providers/historico_providers.dart`
- Test: `test/features/historico/estatisticas_mercado_test.dart` e `historico_compras_repository_test.dart`

**Interfaces:**
- Produces: mesmas listas; `evolucaoPreco`/`unidadeRecente`/`precosPorMercado` filtram `unidade` na consulta antes do `get()`; providers de estatística viram `FutureProvider.autoDispose`.

- [ ] **Step 1: Escrever os testes que falham**

Garantir equivalência para um item com 2 unidades (o filtro por unidade não pode misturar):

```dart
  test('deve_separar_unidades_quando_evolucao_preco', () async {
    // finalizar idas registrando o mesmo nome em 'kg' e em 'un'
    final kg = await historico.evolucaoPreco('arroz', Unidade.kg);
    expect(kg.every((p) => p.unidade == Unidade.kg), isTrue);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/historico/estatisticas_mercado_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar os filtros**

Em `evolucaoPreco`, `unidadeRecenteComprada` e `precosPorMercado`, adicionar `..where`/join com filtro de unidade. Exemplo para `evolucaoPreco`:

```dart
  Future<List<PontoPreco>> evolucaoPreco(
    String nomeNormalizado,
    Unidade unidade,
  ) async {
    final consulta = _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ])..where(_db.itemIda.unidade.equals(unidade.valor));
    final linhas = await consulta.get();
    // ... resto igual (normaliza nome e monta os pontos)
  }
```

Aplicar o mesmo `..where(_db.itemIda.unidade.equals(...))` em `unidadeRecenteComprada` e `precosPorMercado` (esta usa o parâmetro `unidade`).

> `nomesComprados`/`itensMaisComprados` dependem da normalização por nome (acentos), que o SQLite não faz; manter o processamento em Dart, mas selecionar apenas as colunas necessárias (`customSelect('SELECT nome, ... FROM item_ida')`) para reduzir cópia.

- [ ] **Step 4: Providers `autoDispose`**

Em `historico_providers.dart`, trocar `FutureProvider<...>` por `FutureProvider.autoDispose<...>` em: `gastoPorMesProvider`, `gastoPorCategoriaProvider`, `itensMaisCompradosProvider`, `nomesCompradosProvider`, `unidadeRecenteProvider`, `evolucaoPrecoProvider`, `mercadosUsadosProvider`, `precosPorMercadoProvider`, `gastoPorMercadoProvider`. Manter `idasProvider`/`idaProvider`/`itensDaIdaProvider`/`resumoHistoricoProvider` como estão (alimentam telas persistentes).

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/historico/ test/features/listas/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/historico/ test/features/historico/
git commit -m "perf(historico): filtra unidade no SQL e providers autoDispose (RF-34, RF-35)"
```

---

## Fase 3 — UI (performance de rebuild/recomputação)

### Task 7: Tela da lista — busca isolada, agrupamento derivado e concluídos virtualizados

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `_ListaItens` recebe `consulta` (já existe) e calcula `Map<CategoriaItem, List<Item>>` e `alvoTourId` numa passada; `_CampoBusca` (novo, `StatefulWidget`) detém o `TextEditingController`/`setState` local; concluídos renderizados por `SliverList`; nenhuma mudança de UX (mesmos estados vazios/grupos).

- [ ] **Step 1: Escrever os testes que falham**

Manter os testes atuais de busca/grupos/clicáveis verdes. Adicionar regressão de que digitar no campo não aciona rebuild do corpo (ex.: usar um contador ou verificar que os itens continuam presentes). Se não for viável medir rebuild, cobrir comportamento (filtro funciona e resultado correto) — o refactor não deve alterar asserções.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Extrair estado da busca**

No `_TelaListaScreenState`, manter `_buscando` (visibilidade) e um `ValueNotifier<String> _consulta` (em vez de `_busca` TextEditingController para o corpo). A AppBar usa um `_CampoBusca` que recebe `onChanged: (v) => _consulta.value = v`; o `_ListaItens` recebe `consultaNotifier` e usa `ValueListenableBuilder` para filtrar, **sem** `setState` do `State` raiz. O `_CampoAdicionar` continua com seu `TextEditingController` próprio.

- [ ] **Step 4: Agrupar em uma passada**

Substituir o trecho `:848-936` por uma passada única:

```dart
        final pendentes = <Item>[];
        final concluidos = <Item>[];
        final grupos = <CategoriaItem, List<Item>>{};
        for (final item in itens) {
          if (!_casa(item)) continue;
          if (item.concluido) {
            concluidos.add(item);
          } else {
            pendentes.add(item);
            grupos.putIfAbsent(item.categoria, () => <Item>[]).add(item);
          }
        }
        String? alvoTourId;
        for (final categoria in ordemCategorias) {
          final grupo = grupos[categoria];
          if (grupo != null && grupo.isNotEmpty) {
            alvoTourId = grupo.first.id;
            break;
          }
        }
```

E iterar `ordemCategorias` usando `grupos[categoria] ?? const []` (sem `.where` por categoria).

- [ ] **Step 5: (decisão) manter o `ExpansionTile` dos concluídos**

Não virtualizar os concluídos nesta tarefa: o `ExpansionTile` preserva a UX/animacão/semântica e a lista de concluídos costuma ser curta. O ganho de reconstrução já vem dos Steps 3–4. **Ruling:** registrar como dívida opcional, não implementar aqui.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listas/ui/tela_lista_screen.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "perf(tela-lista): busca isolada e agrupamento em passada unica (RF-03, RF-17)"
```

---

### Task 8: `PainelListas` — filtro derivado e busca isolada

**Files:**
- Modify: `lib/features/listas/ui/painel_listas.dart`
- Test: `test/features/listas/minhas_listas_screen_test.dart`

**Interfaces:**
- Produces: filtro/ordenação da busca em passada única a partir do estado do provider; `setState` restrito ao widget de busca (novo `_CampoBuscaPainel`), sem reconstruir a `ListView` por tecla desnecessariamente.

- [ ] **Step 1: Escrever os testes que falham**

Cobrir: busca filtra por título; alternar "mostrar arquivadas"; vazio de busca. (Provavelmente já existe; manter verde.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Extrair o campo de busca para um `ValueNotifier<String>` + `ValueListenableBuilder` que só reconstrói a lista filtrada, mantendo a AppBar estável. Substituir a cadeia `.where(...).where(...).where(...)` por um método `_filtrar(List<ListaComContagem>, String consulta, bool mostrarArquivadas)` fora do `build`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ui/painel_listas.dart test/features/listas/minhas_listas_screen_test.dart
git commit -m "perf(painel): filtro de busca isolado do rebuild da lista (RF-17)"
```

---

### Task 9: `TotalCarrinho` e alerta de orçamento via provider derivado

**Files:**
- Modify: `lib/features/listas/providers/listas_providers.dart` (novos providers derivados) e `lib/features/listas/ui/total_carrinho.dart`, `lib/features/listas/ui/tela_lista_screen.dart` (`_AlertaOrcamentoCategorias`).
- Test: `test/features/listas/total_carrinho_test.dart`, `total_carrinho_progressivo_test.dart`, `tela_lista_orcamento_test.dart`.

**Interfaces:**
- Produces: `totalCarrinhoProvider` (`Provider.family<int, String>`) e `subtotaisPorCategoriaProvider` (`Provider.family<Map<CategoriaItem,int>, String>`), derivados de `itensDaListaProvider` com `.select` da lista de itens — evitando recomputar em widgets que já observam a lista.

- [ ] **Step 1: Escrever os testes que falham**

Manter os existentes; adicionar unit test dos novos providers (ou cobrir via widget). Ex.: `totalCarrinhoProvider` devolve a soma dos marcados com preço.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/total_carrinho_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Em `listas_providers.dart`:

```dart
final totalCarrinhoProvider = Provider.family<int, String>((ref, listaId) {
  final itens = ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
  return totalCarrinho(itens);
});

final subtotaisPorCategoriaProvider =
    Provider.family<Map<CategoriaItem, int>, String>((ref, listaId) {
      final itens =
          ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
      final mapa = <CategoriaItem, int>{};
      for (final item in itens) {
        if (!item.concluido) continue;
        mapa[item.categoria] =
            (mapa[item.categoria] ?? 0) + subtotalMarcado(item);
      }
      return mapa;
    });
```

Atualizar `TotalCarrinho` para consumir `totalCarrinhoProvider` e a lista apenas para `marcados`/`semPreco` (ou criar `resumoCarrinhoProvider`). Atualizar `_AlertaOrcamentoCategorias` para consumir `subtotaisPorCategoriaProvider`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/total_carrinho_test.dart test/features/listas/total_carrinho_progressivo_test.dart test/features/listas/tela_lista_orcamento_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ test/features/listas/
git commit -m "perf(listas): total e subtotais derivados em providers (RF-21, RF-28, RF-36)"
```

---

### Task 10: `_CampoAdicionar` só assina sugestões quando necessário

**Files:**
- Modify: `lib/features/listas/providers/listas_providers.dart`, `lib/features/listas/ui/tela_lista_screen.dart`
- Test: `test/features/listas/itens_frequentes_test.dart`, `tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `itensFrequentesProvider` `autoDispose` (families por lista descartam ao sair da tela); o widget dos chips (`_ChipsSugestoes`) só é montado quando `_controller.text.trim().isEmpty` — evitando recomputar o ranking durante digitação.

- [ ] **Step 1: Escrever os testes que falham**

Cobrir: chips aparecem com campo vazio; somem ao digitar; item sugerido é adicionado.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/itens_frequentes_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Marcar `itensFrequentesProvider` como `StreamProvider.autoDispose.family` (sem `keepAlive`) e extrair os chips para `_ChipsSugestoes` (ConsumerWidget), montado por `_CampoAdicionar` apenas quando `_controller.text.trim().isEmpty`. O `_CampoAdicionar` continua usando `setState` local (é o widget do campo).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ test/features/listas/
git commit -m "perf(tela-lista): chips de sugestao so quando campo vazio (RF-19)"
```

---

### Task 11: `MercadoScreen` — sem mutação no build e faixa virtualizada

**Files:**
- Modify: `lib/features/listas/ui/mercado_screen.dart`
- Test: `test/features/listas/mercado_screen_test.dart`, `tela_lista_mercado_test.dart`

**Interfaces:**
- Produces: a poda de `_marcadosNaSessao` sai do `build` (feita em `_marcar`/`_desmarcar` e num listener de stream ou `didUpdateWidget`); `_FaixaMarcados` não usa `shrinkWrap` e só constrói itens quando aberta.

- [ ] **Step 1: Escrever os testes que falham**

Cobrir: contador não fica preso quando um item some/desmarca; abrir a faixa lista os marcados e desmarcar devolve ao pendentes.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/mercado_screen_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Remover a mutação de `_marcadosValidos` no `build`; calcular apenas `_marcadosNaSessao.length` (ou podar em `didUpdateWidget`/listener). Em `_FaixaMarcados`, trocar `AnimatedAlign`+`shrinkWrap` por `AnimatedSize`/`SizeTransition` com `ListView.builder` sem `shrinkWrap` dentro do `ConstrainedBox(maxHeight)`, construindo itens apenas quando `_aberta` (usar `Offstage`/child condicional preservando o estado).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/mercado_screen_test.dart test/features/listas/tela_lista_mercado_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ui/mercado_screen.dart test/features/listas/
git commit -m "perf(mercado): sem mutacao no build e faixa de marcados virtualizada (RF-18)"
```

---

### Task 12: Configurações — cachear `PackageInfo`

**Files:**
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Test: `test/features/configuracoes/configuracoes_screen_test.dart`

**Interfaces:**
- Produces: `packageInfoProvider` (`FutureProvider<PackageInfo>`) consumido uma única vez; sem chamada de canal no `build`.

- [ ] **Step 1: Escrever o teste que falha**

Cobrir que a versão aparece (mock do provider, se o teste já o fizer) e que o widget segue verde.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: PASS (caracterização).

- [ ] **Step 3: Implementar**

Criar em `configuracoes_screen.dart` (ou `lib/core/providers`) `final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());` e trocar o `FutureBuilder(future: PackageInfo.fromPlatform(), ...)` por `ref.watch(packageInfoProvider)`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/configuracoes/ui/configuracoes_screen.dart
git commit -m "perf(config): cacheia PackageInfo em provider (RF-11)"
```

---

### Task 13: Modais virtualizados e com estado isolado

**Files:**
- Modify: `lib/features/listas/ui/modal_adicionar_de_outra_lista.dart`, `lib/features/importacao/ui/modal_previsao_importacao.dart`, `lib/features/compartilhamento/ui/modal_previsao_receber.dart`
- Test: os testes de `modal_*` correspondentes.

**Interfaces:**
- Produces: `ListView.builder`/`SliverList` no lugar de `Column`/`ListView(children: for ...)` com `shrinkWrap`; `setState` de título isolado onde aplicável.

- [ ] **Step 1: Rodar os testes atuais (caracterização)**

Run: `flutter test test/features/listas/ test/features/importacao/ test/features/compartilhamento/`
Expected: PASS.

- [ ] **Step 2: Implementar**

Trocar as listas não virtualizadas por `.builder` mantendo escopos de altura. Isolar o estado do campo título em `modal_previsao_receber` num widget próprio com `ValueNotifier`, evitando reconstruir os itens a cada tecla.

- [ ] **Step 3: Rodar e ver passar**

Run: `flutter test test/features/listas/ test/features/importacao/ test/features/compartilhamento/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/listas/ui/modal_adicionar_de_outra_lista.dart lib/features/importacao/ui/modal_previsao_importacao.dart lib/features/compartilhamento/ui/modal_previsao_receber.dart
git commit -m "perf(modais): listas virtualizadas e estado de titulo isolado"
```

---

## Fase 4 — Dívida técnica

### Task 14: Limpeza de código morto e comentários obsoletos

**Files:**
- Modify: `lib/core/navigation/voltar_para_inicio.dart` (remover `ehDono`/`/compartilhadas`); call sites `tela_lista_screen.dart:305`, `mercado_screen.dart:150`.
- Modify comentários: `tela_lista_screen.dart:54`, `mercado_screen.dart:87-89`, `database.dart:74`, `router.dart:19`, `bootstrap.dart:7`, `usuario_local.dart:1`, `url_strategy_web.dart:3`.
- Test: `test/core/navigation/`, `test/widget_test.dart`.

**Interfaces:**
- Produces: `String inicioDaLista()` sem parâmetro (sempre `/listas`); comentários condizentes com o app local.

- [ ] **Step 1: Rodar os testes atuais**

Run: `flutter test test/core/navigation/ test/widget_test.dart`
Expected: PASS.

- [ ] **Step 2: Implementar**

Trocar `String inicioDaLista({required bool ehDono}) => ehDono ? '/listas' : '/compartilhadas';` por `String inicioDaLista() => '/listas';` e atualizar os dois call sites (`inicioDaLista(ehDono: true)` → `inicioDaLista()`). Reescrever/remover os comentários históricos listados. **Não** remover o passo `de < 2` da migração sem evidência de que não há instalações v1 em campo (deixar como dívida anotada, não executar).

- [ ] **Step 3: Rodar e ver passar**

Run: `flutter test test/core/navigation/ test/widget_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/navigation/voltar_para_inicio.dart lib/features/listas/ui/tela_lista_screen.dart lib/features/listas/ui/mercado_screen.dart lib/drift/database.dart lib/router.dart lib/bootstrap.dart lib/core/config/usuario_local.dart lib/core/web/url_strategy_web.dart
git commit -m "chore: remove ramo morto de rota e comentarios obsoletos de sync/conta"
```

---

### Task 15: Helpers compartilhados (data, moeda, quantidade+unidade, total)

**Files:**
- Create: `lib/core/utils/formatacao.dart`
- Modify: `lib/features/listas/domain/preco.dart` (`formatarReaisSemSimbolo`), `lib/features/listas/domain/orcamento.dart` (reusar subtotal em total), `lib/features/listas/ui/tela_lista_screen.dart:1277`, `lib/features/listas/ui/mercado_screen.dart:330`, `lib/features/historico/ui/ida_detalhe_screen.dart:81`, `historico_screen.dart:168`, `estatisticas_tab.dart:415`.
- Test: `test/features/listas/preco_test.dart`, novos unit tests.

**Interfaces:**
- Produces: `formatarData(DateTime)` (dd/MM/aaaa), `formatarQuantidadeComUnidade(double, Unidade)`, `formatarReaisSemSimbolo(int)`. `totalCarrinho` passa a somar `subtotalMarcado` (uma regra só).

- [ ] **Step 1: Escrever os testes que falham**

```dart
test('deve_formatar_data_quando_dd_MM_aaaa', () {
  expect(formatarData(DateTime.utc(2026, 1, 9)), '09/01/2026');
});
test('deve_formatar_quantidade_com_unidade', () {
  expect(formatarQuantidadeComUnidade(1.5, Unidade.kg), '1,5 kg');
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/preco_test.dart`
Expected: FAIL (funções inexistentes).

- [ ] **Step 3: Implementar**

Criar `lib/core/utils/formatacao.dart` com `formatarData` e `formatarQuantidadeComUnidade`; adicionar `formatarReaisSemSimbolo` em `preco.dart` (`reais,resto` sem prefixo) e reescrever `totalCarrinho` em função de `subtotalMarcado`. Atualizar os call sites para os helpers.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/ test/features/historico/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/formatacao.dart lib/features/listas/domain/preco.dart lib/features/listas/domain/orcamento.dart lib/features/listas/ui/ lib/features/historico/ui/ test/
git commit -m "refactor: centraliza formatacao de data/moeda/quantidade"
```

---

### Task 16: Rótulos de categoria via l10n

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `app_en.arb`, `app_es.arb` (11 chaves `categoriaHortifruti`…), `lib/core/dominio/categoria.dart` (remover `rotulo`), todos os call sites (`categoria.rotulo` → `context.l10n.<chave>`).
- Docs: [05 §6.3](../05-app-flutter.md), [15](../15-design-system.md).
- Test: `test/core/dominio/categoria_test.dart`, `test/core/l10n/arb_paridade_test.dart`, `test/core/theme/tokens_test.dart`.

**Interfaces:**
- Produces: `CategoriaItem` sem texto de UI; textos nos ARB; helper `String rotuloCategoria(AppLocalizations, CategoriaItem)`.

- [ ] **Step 1: Rodar os testes atuais**

Run: `flutter test test/core/dominio/categoria_test.dart test/core/l10n/arb_paridade_test.dart`
Expected: PASS (baseline).

- [ ] **Step 2: Implementar**

Adicionar as 11 chaves nos três ARB (pt/en/es), rodar `flutter gen-l10n`, remover `rotulo` do enum e substituir os 15 usos por `context.l10n.<chave>`. Ajustar `categoria_test.dart` e qualquer teste que assevere o rótulo em pt-BR.

- [ ] **Step 3: Rodar e ver passar**

Run: `flutter test test/core/ test/features/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/ lib/core/dominio/categoria.dart lib/features/ test/
git commit -m "i18n(categorias): rotulos no ARB (RF-39)"
```

---

### Task 17: Dividir `tela_lista_screen.dart` (refactor estrutural)

**Files:**
- Create: `lib/features/listas/ui/campo_adicionar_item.dart`, `lista_itens.dart`, `linha_item.dart`, `sheet_editar_item.dart`, `dialogo_orcamento.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (shell apenas).

**Interfaces:**
- Produces: widgets extraídos como classes públicas (`CampoAdicionarItem`, `ListaItens`, `LinhaItem`, …) ou privados movidos, mantendo o mesmo comportamento. Somente mover código, sem alterar lógica.

- [ ] **Step 1: Rodar os testes atuais**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (baseline).

- [ ] **Step 2: Mover widgets**

Mover cada classe privada para seu arquivo (mantendo `_` ou tornando público conforme o acesso), ajustando imports. Sem mudanças de comportamento.

- [ ] **Step 3: Rodar e ver passar**

Run: `flutter test test/features/listas/`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/listas/ui/
git commit -m "refactor(listas): divide tela_lista_screen em widgets"
```

---

### Task 18: Docs donas, format/analyze/test e fechamento

**Files:**
- Modify: `docs/05-app-flutter.md` (índices/migração v15, providers derivados), `docs/14-tarefas.md` (registrar a fase de otimizações e o progresso), `docs/00-visao-geral.md` (se necessário, ADR-015).
- Version: `pubspec.yaml` + `web/version.json` (paridade) — bump `1.7.0+17`, e atualizar a linha de distribuição F5-T05b se for distribuir.

**Interfaces:**
- Produces: docs donas consistentes com o código; CI verde.

- [ ] **Step 1: Atualizar docs donas**

Em `05-app-flutter.md`, registrar na seção de dados/árvore: `schemaVersion = 15`, índices novos, os providers derivados (`totalCarrinhoProvider`/`subtotaisPorCategoriaProvider`/`resumoCarrinhoProvider`), o ciclo de vida **`autoDispose`** de `itensFrequentesProvider` e dos providers de estatística, e que `_ChipsSugestoes` só assina sugestões com o campo vazio. Em `14-tarefas.md`, adicionar a nota da fase de otimizações no histórico e ajustar a tabela de progresso.

- [ ] **Step 2: Bump de versão**

Alterar `version: 1.7.0+17` e `web/version.json` (`version: "1.7.0"`, `build_number: 17` — conferir o formato atual do arquivo).

- [ ] **Step 3: Verificação final**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: format sem alterações pendentes, analyze `No issues found!`, todos os testes verdes.

- [ ] **Step 4: Commit**

```bash
git add docs/ pubspec.yaml web/version.json
git commit -m "docs(otimizacoes): registra indices v15, providers derivados e bump 1.7.0+17"
```

---

## Self-Review (do autor do plano)

- **Cobertura dos achados:** índices (T1), N+1 (T2), escritas em massa (T3), `finalizar` batch (T4), estatísticas full-scan (T5/T6), busca/rebuild (T7/T8), `select`/providers (T9), `watchItensFrequentes` (T10), mercado (T11), `PackageInfo` (T12), modais (T13), código morto (T14), duplicações (T15), rótulos l10n (T16), arquivo grande (T17), docs/CI (T18). Falta apenas `sugerirCategoria` full-scan (achado médio 6): **registrado como dívida** — a otimização behavior-preserving exige cache invalidado por escrita ou coluna normalizada; fica fora deste plano para não arriscar regressão.
- **Consistência de tipos:** `Item`/`Unidade`/`CategoriaItem`/`Ida`/`GastoPorMes` são os já existentes; os novos providers reutilizam os mesmos nomes de domínio.
- **Risco/ordem:** dados antes de UI; cada tarefa termina com teste verde e commit isolado.
- **Dependência de docs:** T16 e T18 exigem atualização de doc dona (declarada nos files).
