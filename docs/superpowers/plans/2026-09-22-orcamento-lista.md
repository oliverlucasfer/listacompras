# Fase 36 — Orçamento por lista (RF-28): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar um orçamento (limite de gasto) por lista — sincronizado, editável por dono/editor — comparado ao total do carrinho (RF-21), com progresso e alerta visual.

**Architecture:** Coluna aditiva `listas.orcamento_centavos` (sem policy nova), Drift schemaVersion 6, payload de `listas` com o campo, e `TotalCarrinho` estendido (lê `listaPorIdProvider`). Dinheiro em centavos inteiros; offline-first (Drift + fila).

**Tech Stack:** Postgres/Supabase (migration + SQL), Drift (build_runner), Riverpod, Flutter.

**Spec:** `docs/superpowers/specs/2026-09-22-orcamento-lista-design.md`

## Global Constraints

- **Doc dono é autoridade** (01/02/03/05/10/12) — atualize no mesmo PR.
- **Enum de unidades fechado** e dinheiro em **centavos inteiros** (sem `float`); teto R$ 999.999,99.
- **RLS sagrado:** nada de service_role no client; `orcamento_centavos` **herda** o UPDATE de `listas` (dono/editor) — **sem policy nova**.
- **Offline-first:** escrita sempre Drift + fila; UI nunca bloqueia em rede.
- Migrations **append-only** (`0020`); nunca SQL direto em produção.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Gate por tarefa: `dart format . && flutter analyze && flutter test` verdes (baseline 589).
- Tarefas com SQL exigem **Docker** (`supabase db reset` + `psql` no container).
- Uma tarefa = um commit, `F36-Tnn: <resumo>` em pt-BR. Push/merge só com autorização.

---

### Task 1: Migration `0020` + SQL tests + CI + docs 01/02

**Files:**
- Create: `supabase/migrations/0020_orcamento_lista.sql`
- Create: `supabase/tests/orcamento_lista_tests.sql`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/01-banco-de-dados.md` (§4.1), `docs/02-seguranca-rls.md` (§4.1)

**Interfaces:** Produz a coluna `listas.orcamento_centavos integer` (CHECK `null ou 0..99999999`).

- [ ] **Step 1: Migration**

`supabase/migrations/0020_orcamento_lista.sql`:
```sql
-- 0020_orcamento_lista.sql — orçamento por lista (doc 01 §4.1, RF-28, F36).
-- Centavos inteiros (sem float); NULL = sem orçamento; 0 é válido; negativo
-- rejeitado. Sem policy nova: herda o UPDATE de `listas` (dono/editor).
alter table public.listas
  add column orcamento_centavos integer
  check (orcamento_centavos is null
         or (orcamento_centavos >= 0 and orcamento_centavos <= 99999999));
```

- [ ] **Step 2: SQL tests** (`ORC-01..03`)

`supabase/tests/orcamento_lista_tests.sql` (padrão do `preco_item_tests.sql`: transação com `rollback`, `do $$` com `raise exception`/`raise notice`):
```sql
-- ============================================================================
-- orcamento_lista_tests.sql — coluna orcamento_centavos (doc 01 §4.1, RF-28, F36-T01)
--   ORC-01: orçamento ausente (NULL) aceito.
--   ORC-02: 0 e valor normal aceitos.
--   ORC-03: negativo rejeitado; acima do teto rejeitado.
-- Transação com ROLLBACK final.
-- ============================================================================
begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values ('f0000000-0000-0000-0000-000000000000', 'orcamento@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- ===== ORC-01: NULL aceito =====
do $$
declare v int;
begin
  insert into public.listas (id, titulo, dono_id)
  values ('f9000000-0000-0000-0000-000000000000', 'Lista Orcamento', 'f0000000-0000-0000-0000-000000000000')
  returning orcamento_centavos into v;
  if v is not null then raise exception 'FALHOU ORC-01: orcamento %', v; end if;
  raise notice 'OK ORC-01: NULL aceito';
end $$;

-- ===== ORC-02: zero e valor normal =====
do $$
declare v int;
begin
  update public.listas set orcamento_centavos = 0
    where id = 'f9000000-0000-0000-0000-000000000000'
    returning orcamento_centavos into v;
  if v <> 0 then raise exception 'FALHOU ORC-02: zero virou %', v; end if;

  update public.listas set orcamento_centavos = 25000
    where id = 'f9000000-0000-0000-0000-000000000000'
    returning orcamento_centavos into v;
  if v <> 25000 then raise exception 'FALHOU ORC-02: normal virou %', v; end if;
  raise notice 'OK ORC-02: zero e normal aceitos';
end $$;

-- ===== ORC-03: negativo e acima do teto rejeitados =====
do $$
begin
  begin
    update public.listas set orcamento_centavos = -1
      where id = 'f9000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU ORC-03: negativo aceito';
  exception when check_violation then
    raise notice 'OK ORC-03: negativo rejeitado';
  end;

  begin
    update public.listas set orcamento_centavos = 100000000
      where id = 'f9000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU ORC-03: acima do teto aceito';
  exception when check_violation then
    raise notice 'OK ORC-03: acima do teto rejeitado';
  end;
end $$;

rollback;
```

- [ ] **Step 3: CI** — em `.github/workflows/ci.yml`, após o step "Testes do preço do item", adicionar:
```yaml
      - name: Testes do orçamento da lista (01 §4.1)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/orcamento_lista_tests.sql
```

- [ ] **Step 4: Validar local (Docker)** — `supabase db reset` e então:
`Get-Content supabase/tests/orcamento_lista_tests.sql -Raw | docker exec -i supabase_db_ListaCompras psql -U postgres -d postgres -v ON_ERROR_STOP=1`
Expected: `OK ORC-01/02/03`.

- [ ] **Step 5: Docs 01/02**
  - `docs/01-banco-de-dados.md` §4.1: adicionar a linha da coluna na tabela de `listas` (mesmo formato de `arquivada_em`) e no bloco `create table`, e uma nota: "`orcamento_centavos` (RF-28, F36): `null` = sem orçamento; `0` válido; CHECK `null ou 0..99999999`; **sem policy nova** — herda o UPDATE de `listas` (dono/editor)".
  - `docs/02-seguranca-rls.md` §4.1: nota curta de que `orcamento_centavos` não cria policy (herda `listas` UPDATE).

- [ ] **Step 6: Gate e commit**
Run: `dart format . && flutter analyze && flutter test` (verde, 589).
```bash
git add supabase/migrations/0020_orcamento_lista.sql supabase/tests/orcamento_lista_tests.sql .github/workflows/ci.yml docs/01-banco-de-dados.md docs/02-seguranca-rls.md
git commit -m "F36-T01: migration 0020 orcamento da lista + SQL + CI (RF-28)"
```

---

### Task 2: Drift + domínio + repositório + sync (03)

**Files:**
- Modify: `lib/drift/tables/lista_local.dart`, `lib/drift/database.dart` (regenerar `database.g.dart`)
- Modify: `lib/features/listas/domain/lista.dart`
- Modify: `lib/features/listas/data/listas_repository.dart`
- Modify: `lib/features/sync/data/aplicador_remoto.dart`
- Modify: `docs/03-sincronizacao-offline.md`
- Test: `test/features/listas/listas_repository_test.dart`, `test/features/sync/aplicador_remoto_test.dart` (ou arquivos existentes equivalentes)

**Interfaces:** Produz `Lista.orcamentoCentavos` (`int?`), `ListasRepository.definirOrcamento(String id, {required int? centavos})`, payload de lista com `orcamento_centavos`; consome a coluna da Task 1.

- [ ] **Step 1: Drift**
  - `lib/drift/tables/lista_local.dart`: adicionar `IntColumn get orcamentoCentavos => integer().nullable()();`
  - `lib/drift/database.dart`: `schemaVersion` 5 → **6** e no `onUpgrade`:
    ```dart
    if (de < 6) {
      // v5 → v6: coluna orcamento_centavos (doc 01 §4.1, RF-28, F36).
      await m.addColumn(listaLocal, listaLocal.orcamentoCentavos);
    }
    ```
  - Regenerar: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Domínio** — `lib/features/listas/domain/lista.dart`: campo `final int? orcamentoCentavos;` (constructor + `fromLocal: orcamentoCentavos: d.orcamentoCentavos`).

- [ ] **Step 3: Repositório**
  - `_payloadLista` passa a incluir **sempre** `'orcamento_centavos': l.orcamentoCentavos` (como `titulo`; a mescla do sync é por chave, então não há conflito com `arquivada_em`).
  - Novo método (padrão `definirArquivada`):
    ```dart
    /// Define/limpa o orçamento da lista (RF-28). Offline-first: Drift + fila.
    Future<void> definirOrcamento(String id, {required int? centavos}) async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(
          orcamentoCentavos: Value(centavos),
          updatedAt: Value(agora),
        ),
      );
      await _enfileirar(tabela: 'listas', registroId: id, operacao: 'UPDATE',
        payload: await _payloadLista(id));
    }
    ```
    (ajuste os nomes reais de `_enfileirar`/parâmetros ao arquivo.)

- [ ] **Step 4: Aplicador** — `lib/features/sync/data/aplicador_remoto.dart`: em `_aplicarLista`, `orcamentoCentavos: Value(_intOpcional(r['orcamento_centavos']))`, com helper tolerante:
  ```dart
  int? _intOpcional(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
  ```

- [ ] **Step 5: Testes** — repo: `definirOrcamento` grava a coluna e enfileira UPDATE com `orcamento_centavos` no payload; `definirOrcamento(null)` limpa. Aplicador: `orcamento_centavos` ausente/não numérico → `null`; numérico → valor. Nome `deve_..._quando_...`.

- [ ] **Step 6: Doc 03** — registrar que o payload de `listas` inclui `orcamento_centavos` (tolerância a ausente → `null`).

- [ ] **Step 7: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add lib/drift lib/features/listas/domain/lista.dart lib/features/listas/data/listas_repository.dart lib/features/sync/data/aplicador_remoto.dart docs/03-sincronizacao-offline.md test
git commit -m "F36-T02: orcamento no drift, dominio, repo e sync (RF-28)"
```

---

### Task 3: UI — definir/limpar orçamento (05 §6.3)

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Test: `test/features/listas/tela_lista_orcamento_test.dart` (novo)

**Interfaces:** Consome `ListasRepository.definirOrcamento` (Task 2); usa `parsePrecoParaCentavos`/`formatarReais` (`domain/preco.dart`).

- [ ] **Step 1: Strings** — em `app_strings.dart`: `orcamento = 'Orçamento'`, `campoOrcamento = 'Orçamento (R$)'`, `removerOrcamento = 'Remover orçamento'`, `orcamentoDefinido = 'Orçamento salvo.'`, `orcamentoRemovido = 'Orçamento removido.'`, `erroOrcamentoInvalido = 'Valor de orçamento inválido.'`.

- [ ] **Step 2: Menu** — em `tela_lista_screen.dart`, no `PopupMenuButton` (≈ linha 351, junto de `renomear`), adicionar quando `podeEscrever`:
  ```dart
  const PopupMenuItem(value: 'orcamento', child: Text(AppStrings.orcamento)),
  ```
  e no `_acaoMenu` (≈ linha 133) o `case 'orcamento':` → `_abrirDialogoOrcamento(context, ref, lista)`.

- [ ] **Step 3: Diálogo** — `_abrirDialogoOrcamento`: `AlertDialog` com `AppCampoTexto` "Orçamento (R$)" (prefixado com o valor atual via `formatarReais(lista.orcamentoCentavos)` quando houver), erro inline (`erroOrcamentoInvalido`) para `parsePrecoParaCentavos` inválido; ações **Salvar** (`definirOrcamento(id, centavos: parse)` → SnackBar `orcamentoDefinido`) e **Remover orçamento** (só quando há orçamento → `definirOrcamento(id, centavos: null)` → SnackBar `orcamentoRemovido`). Leitor não vê o item de menu.

- [ ] **Step 4: Testes** — widget: dono define orçamento (menu → diálogo → salvar → repo chamado/valor persistido); dono remove; leitor **não** vê "Orçamento"; valor inválido mostra erro inline.

- [ ] **Step 5: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/tela_lista_screen.dart test
git commit -m "F36-T03: menu e dialogo de orcamento na tela da lista (RF-28)"
```

---

### Task 4: UI — `TotalCarrinho` com orçamento (05 §6.3/§6.5, 10 §3.1/§3.5)

**Files:**
- Modify: `lib/features/listas/ui/total_carrinho.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `docs/05-app-flutter.md` (§6.3/§6.5), `docs/10-wireframes-telas.md` (§3.1/§3.5)
- Test: `test/features/listas/total_carrinho_test.dart` (existente/novo)

**Interfaces:** Consome `listaPorIdProvider(listaId)` (Task 2 expõe `orcamentoCentavos`); mantém a assinatura `TotalCarrinho({required String listaId})`.

- [ ] **Step 1: Strings** — `totalComOrcamento(String valor, String orcamento, int semPreco)` → `'No carrinho: $valor de $orcamento'` (+ `' · $semPreco sem preço'` quando `semPreco > 0`); `acimaDoOrcamento = 'Acima do orçamento'`.

- [ ] **Step 2: Widget** — em `total_carrinho.dart`, ler `ref.watch(listaPorIdProvider(listaId)).value?.orcamentoCentavos`. Sem orçamento → comportamento atual (`totalNoCarrinho`). Com orçamento: texto `totalComOrcamento(...)` + `LinearProgressIndicator(value: (total / orcamento).clamp(0, 1))` (se `orcamento > 0`); quando `total > orcamento`: cor de erro no texto/progresso + ícone (`Icons.warning_amber_rounded`) + `acimaDoOrcamento`. Mantém `Semantics(liveRegion: true)`. `orcamento == 0` → qualquer total > 0 é "acima".

- [ ] **Step 3: Docs** — `docs/05-app-flutter.md` §6.3/§6.5: descrever a faixa com orçamento (progresso + alerta). `docs/10-wireframes-telas.md` §3.1/§3.5: anotar o estado com orçamento.

- [ ] **Step 4: Testes** — widget: sem orçamento → texto atual; com orçamento abaixo → "de R$ Y" + progresso; acima → alerta/"Acima do orçamento"; presente na tela da lista e no modo mercado.

- [ ] **Step 5: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add lib/features/listas/ui/total_carrinho.dart lib/core/l10n/app_strings.dart docs/05-app-flutter.md docs/10-wireframes-telas.md test
git commit -m "F36-T04: TotalCarrinho com orcamento (RF-28)"
```

---

### Task 5: RF-28 (12) + fechamento (14/16)

**Files:**
- Modify: `docs/12-prd.md`, `docs/14-tarefas.md`, `docs/16-roadmap-pos-mvp.md`

- [ ] **Step 1: doc 12** — adicionar **RF-28** na tabela de requisitos e na matriz de rastreabilidade (F36; unit repo/aplicador + widgets); **remover "orçamento/limite"** da lista de fora de escopo (mantendo "comparação entre idas").

- [ ] **Step 2: doc 14** — bloco `## Fase 36 — Orçamento por lista (RF-28)` com `Spec: docs/superpowers/specs/2026-09-22-orcamento-lista-design.md · Requisito: RF-28 · Docs donos: 01, 02, 03, 05, 10, 12`, F36-T01…T05 `[x]` com `Dep:`/`Docs:`/`CP:` no estilo da F35; tabela `| F36 Orçamento | 5 | 5 |` e total `| **Total** | **184** | **182** |`.

- [ ] **Step 3: doc 16** — Onda D, linha D1 → atualizar as notas: preço/total (F25) **e** orçamento (F36) concluídos; **comparação entre idas pendente**.

- [ ] **Step 4: Gate e commit**
Run: `dart format . && flutter analyze && flutter test`.
```bash
git add docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F36-T05: RF-28 no PRD e fechamento da Fase 36 (RF-28)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 schema → T01; §4 sync → T02; §5 app (Drift/domínio/repo → T02; menu/diálogo → T03; exibição → T04); §6 docs donos → T01/T02/T03/T04/T05.
- **Placeholders:** nenhum "TBD"; SQL e trechos Dart completos (ajustes de nomes internos indicados quando necessário).
- **Consistência de interfaces:** `definirOrcamento(id, {required int? centavos})`, `Lista.orcamentoCentavos:int?`, payload `orcamento_centavos`, `_intOpcional`; progresso 184/182.
- **Sem arquivos compartilhados entre tarefas:** T01 (SQL/CI/01/02), T02 (drift/domain/repo/sync/03), T03 (strings/tela), T04 (total_carrinho/strings/05/10), T05 (12/14/16). `app_strings.dart` é tocado por T03 e T04 — **ruling: T04 faz o commit depois de T03** (mesma sessão, ordem sequencial; sem paralelismo).
