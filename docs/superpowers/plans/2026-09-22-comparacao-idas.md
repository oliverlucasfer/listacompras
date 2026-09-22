# Fase 37 — Comparação de preços entre idas (RF-29): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guardar localmente (por dispositivo) o último preço pago por item e mostrar "Última compra: R$X" + variação no editor do item.

**Architecture:** Tabela **local** Drift `HistoricoPrecoLocal` (sem Postgres/RLS/sync). O registro acontece em `ListasRepository.editarItem` quando o item fica concluído com preço; a leitura é um `FutureProvider.family` consumido pelo `_DialogoEditarItem`.

**Tech Stack:** Drift (build_runner), Riverpod, Flutter.

**Spec:** `docs/superpowers/specs/2026-09-22-comparacao-idas-design.md`

## Global Constraints

- **Local-only:** nada de migration Postgres, RLS, payload de sync ou `mutacao_pendente`. O histórico **não** sincroniza.
- Dinheiro em **centavos inteiros**; normalização de nome via `normalizarTexto` (`lib/core/texto/normalizar.dart`).
- **Doc dono é autoridade** (05/03/10/12) — atualize no mesmo PR.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Gate por tarefa: `dart format . && flutter analyze && flutter test` verdes (baseline **611**).
- Uma tarefa = um commit, `F37-Tnn: <resumo>` em pt-BR. Push/merge só com autorização.

---

### Task 1: Drift local + registro no repositório

**Files:**
- Create: `lib/drift/tables/historico_preco_local.dart`
- Create: `lib/features/listas/domain/historico_preco.dart`
- Create: `lib/features/listas/data/historico_precos_repository.dart`
- Modify: `lib/drift/database.dart` (regenerar `database.g.dart`)
- Modify: `lib/features/listas/data/listas_repository.dart`
- Test: `test/features/listas/historico_precos_repository_test.dart`, `test/features/listas/listas_repository_test.dart`, `test/drift/database_test.dart`

**Interfaces:** Produz `HistoricoPrecosRepository.registrar({required String nome, required int precoCentavos, required Unidade unidade, DateTime? quando})` e `HistoricoPreco? porNome(String nome)`; `HistoricoPreco { nomeNormalizado, precoCentavos, unidade, registradoEm }`.

- [ ] **Step 1: Tabela Drift** — `lib/drift/tables/historico_preco_local.dart`:
```dart
import 'package:drift/drift.dart';

/// Histórico local de preços por item (doc 05 §6.3, RF-29, F37).
/// **Não sincroniza** — por dispositivo.
class HistoricoPrecoLocal extends Table {
  TextColumn get nomeNormalizado => text()();
  IntColumn get precoCentavos => integer()();
  TextColumn get unidade => text()();
  DateTimeColumn get registradoEm => dateTime()();

  @override
  Set<Column> get primaryKey => {nomeNormalizado};
}
```

- [ ] **Step 2: Database** — `lib/drift/database.dart`: importar a tabela, incluí-la em `@DriftDatabase(tables: [ListaLocal, ItemLocal, MutacaoPendente, HistoricoPrecoLocal])`, `schemaVersion` 6 → **7**, e no `onUpgrade`:
```dart
if (de < 7) {
  // v6 → v7: tabela local de histórico de preços (doc 05 §6.3, RF-29, F37).
  await m.createTable(historicoPrecoLocal);
}
```
Regenerar: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 3: Domínio** — `lib/features/listas/domain/historico_preco.dart`:
```dart
import '../../../drift/database.dart';

/// Último preço pago por item (histórico local, RF-29).
class HistoricoPreco {
  const HistoricoPreco({
    required this.nomeNormalizado,
    required this.precoCentavos,
    required this.unidade,
    required this.registradoEm,
  });

  final String nomeNormalizado;
  final int precoCentavos;
  final String unidade;
  final DateTime registradoEm;

  factory HistoricoPreco.fromLocal(HistoricoPrecoLocalData d) => HistoricoPreco(
    nomeNormalizado: d.nomeNormalizado,
    precoCentavos: d.precoCentavos,
    unidade: d.unidade,
    registradoEm: d.registradoEm,
  );
}
```

- [ ] **Step 4: Repositório de histórico** — `lib/features/listas/data/historico_precos_repository.dart`:
```dart
import 'package:drift/drift.dart';

import '../../../core/texto/normalizar.dart';
import '../../../drift/database.dart';
import '../domain/historico_preco.dart';
import '../domain/unidade.dart'; // ajuste o import real do enum Unidade

/// Histórico local de preços (RF-29). Local-only: não enfileira mutação.
class HistoricoPrecosRepository {
  HistoricoPrecosRepository(this._db);
  final AppDatabase _db;

  Future<void> registrar({
    required String nome,
    required int precoCentavos,
    required Unidade unidade,
    DateTime? quando,
  }) async {
    await _db.into(_db.historicoPrecoLocal).insertOnConflictUpdate(
      HistoricoPrecoLocalCompanion.insert(
        nomeNormalizado: normalizarTexto(nome),
        precoCentavos: precoCentavos,
        unidade: unidade.valor,
        registradoEm: quando ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<HistoricoPreco?> porNome(String nome) async {
    final row = await (_db.select(_db.historicoPrecoLocal)
          ..where((h) => h.nomeNormalizado.equals(normalizarTexto(nome))))
        .getSingleOrNull();
    return row == null ? null : HistoricoPreco.fromLocal(row);
  }
}
```

- [ ] **Step 5: Registrar em `editarItem`** — em `lib/features/listas/data/listas_repository.dart`, logo após `final item = await _lerItem(id);` (≈ linha 398), adicionar (ajuste ao construtor real do repo; pode guardar um `HistoricoPrecosRepository` construído de `_db`):
```dart
if (item.concluido && item.precoCentavos != null) {
  await HistoricoPrecosRepository(_db).registrar(
    nome: item.nome,
    precoCentavos: item.precoCentavos!,
    unidade: item.unidade,
    quando: agora,
  );
}
```
Isto cobre o checkbox da lista, o modo mercado e o editor (todos concluem via `editarItem`). Marcar sem preço não registra; desmarcar não apaga.

- [ ] **Step 6: Testes** — repo de histórico: `registrar` grava normalizado; segunda chamada com o mesmo nome **atualiza** (upsert, sem duplicar); `porNome` normaliza a busca. `editarItem`: marcar concluído **com** preço registra; concluído **sem** preço não registra; desmarcar não apaga o histórico. Migração v6→v7: DB v6 legado (como em `database_test.dart`) sobe e a tabela existe. Nomes `deve_..._quando_...`.

- [ ] **Step 7: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add lib/drift lib/features/listas/domain/historico_preco.dart lib/features/listas/data/historico_precos_repository.dart lib/features/listas/data/listas_repository.dart test
git commit -m "F37-T01: historico local de precos e registro ao concluir (RF-29)"
```

---

### Task 2: Provider + linha no editor do item (05 §6.3)

**Files:**
- Modify: `lib/features/listas/providers/listas_providers.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_DialogoEditarItem`)
- Test: `test/features/listas/editar_item_historico_test.dart` (novo)

**Interfaces:** Consome `HistoricoPrecosRepository.porNome` (Task 1) via `historicoPrecoProvider(nome)`.

- [ ] **Step 1: Provider** — em `listas_providers.dart`:
```dart
final historicoPrecoProvider =
    FutureProvider.family<HistoricoPreco?, String>((ref, nome) async {
  return HistoricoPrecosRepository(ref.watch(appDatabaseProvider)).porNome(nome);
});
```

- [ ] **Step 2: Strings** — `app_strings.dart`: `ultimaCompra(String valor, String data)` → `'Última compra: $valor ($data)'`; `mesmoPreco = 'Mesmo preço'`; `precoSubiu(String diff)` → `'↑ $diff'`; `precoBaixou(String diff)` → `'↓ $diff'`; `unidadeDiferente` (opcional) se quiser sinalizar.

- [ ] **Step 3: Linha no editor** — em `_DialogoEditarItem.build`, ler `final hist = ref.watch(historicoPrecoProvider(widget.item.nome)).value;` e, quando `hist != null`, inserir um `Text` (pequeno) logo abaixo do campo de preço:
  - "Última compra: `formatarReais(hist.precoCentavos)` (`dd/mm` de `hist.registradoEm`)".
  - Se o preço atual (`parsePrecoParaCentavos(_preco.text)`, tolerando `ArgumentError`/nulo) existir **e** a unidade atual (`_unidade.valor`) for igual a `hist.unidade`: mostrar a variação — `precoSubiu`/`precoBaixou` com `formatarReais((atual - hist.precoCentavos).abs())`, ou `mesmoPreco` se iguais.
  - Unidade diferente ou preço atual ausente → só a linha do último preço.
  - Rebuild ao digitar: o `onChanged` do campo de preço já chama `setState` — garanta que a variação reflita o texto atual.
  - Data `dd/mm` sem `intl`: `'${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'` (use a data local: `hist.registradoEm.toLocal()`).

- [ ] **Step 4: Testes** — widget: sem histórico → nenhuma linha; com histórico (mesma unidade) → "Última compra" + variação ↑/↓/mesmo; unidade diferente → só o último preço; o texto reage ao digitar o preço.

- [ ] **Step 5: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add lib/features/listas/providers/listas_providers.dart lib/core/l10n/app_strings.dart lib/features/listas/ui/tela_lista_screen.dart test
git commit -m "F37-T02: ultima compra e variacao no editor do item (RF-29)"
```

---

### Task 3: RF-29 (12) + docs donos + fechamento (14/16)

**Files:**
- Modify: `docs/05-app-flutter.md`, `docs/03-sincronizacao-offline.md`, `docs/10-wireframes-telas.md`, `docs/12-prd.md`, `docs/14-tarefas.md`, `docs/16-roadmap-pos-mvp.md`

- [ ] **Step 1: doc 05 §6.3** — descrever a linha "Última compra" no editor do item + a variação (só com unidade igual) e a natureza **local/não sincronizada** do histórico (RF-29, F37).
- [ ] **Step 2: doc 03** — nota curta de que o histórico de preços (`HistoricoPrecoLocal`) é **local-only** e **não** entra no sync/fila.
- [ ] **Step 3: doc 10 §3.1** — anotar a linha "Última compra" no wireframe do editor.
- [ ] **Step 4: doc 12** — **RF-29** na tabela de requisitos e na rastreabilidade (F37; unit repo + widgets); **remover "comparação entre idas"** da lista de fora de escopo (era o último item de preços pendente).
- [ ] **Step 5: doc 14** — `## Fase 37 — Comparação entre idas (RF-29)` com `Spec: docs/superpowers/specs/2026-09-22-comparacao-idas-design.md · Requisito: RF-29 · Docs donos: 05, 03, 10, 12`; F37-T01…T03 `[x]` no estilo da F36; tabela `| F37 Comparação entre idas | 3 | 3 |` e total `| **Total** | **187** | **185** |`.
- [ ] **Step 6: doc 16** — Onda D, linha D1 → **concluído** (preço/total F25, orçamento F36, comparação entre idas F37), no estilo das linhas concluídas.
- [ ] **Step 7: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add docs/05-app-flutter.md docs/03-sincronizacao-offline.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F37-T03: RF-29 no PRD, docs donos e fechamento (RF-29)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 tabela → T01; §4 registro → T01; §5 exibição → T02; §6 docs → T03.
- **Placeholders:** nenhum "TBD"; código dos Steps 1/3/4/5 completo (nomes internos do repo indicados para ajuste).
- **Consistência:** `registrar`/`porNome`/`HistoricoPreco`/`historicoPrecoProvider`; schemaVersion 7; progresso 187/185.
- **Sem arquivos compartilhados entre tarefas:** T01 (drift/domain/repo), T02 (providers/strings/tela), T03 (docs).
- **Local-only:** nenhum arquivo de `supabase/`, `mutacao_pendente` ou payload é tocado.
