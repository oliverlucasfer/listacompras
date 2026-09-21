# Fase 26 — Arquivar e Desarquivar Listas (RF-22): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-22 — arquivar/desarquivar listas (estado global da lista, só o dono), com um toggle "Mostrar arquivadas" no painel, 100% offline-first.

**Architecture:** Coluna `arquivada_em timestamptz` em `listas`, propagada pelo caminho normal (Drift + fila + LWW + aplicador), sem policy nova; um trigger de defesa em profundidade restringe a autoria da mudança ao dono. O painel filtra por um toggle efêmero; o card ganha a ação no menu e um rótulo.

**Tech Stack:** Postgres/Supabase (coluna + trigger) · Flutter · Riverpod · Drift (build_runner) · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-21-arquivar-listas-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes; as tarefas de banco rodam também `supabase db reset` + o script SQL.
- Uma tarefa = um commit, mensagem `F26-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `docs/02`** (sem policy nova) nem em `docs/03` além do payload de lista (dono do sync atualizado na Task 4).
- Migrations **append-only**: `0018_arquivar_listas.sql`.
- `null` = lista ativa; arquivar é reversível.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Arquivo é **global da lista**, controlado **só pelo dono**.
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Banco — migration `0018` (coluna, índice, trigger) + testes SQL + CI

**Files:**
- Create: `supabase/migrations/0018_arquivar_listas.sql`
- Create: `supabase/tests/arquivar_listas_tests.sql`
- Modify: `.github/workflows/ci.yml` (step novo após o de `preco_item_tests`)
- Modify: `docs/07-qualidade-ci.md` (§3 esqueleto — nova linha)

**Interfaces:**
- Consumes: `public.listas` (`docs/01 §4.1`), `auth.uid()`.
- Produces: coluna `arquivada_em timestamptz`; trigger `trg_listas_arquivo_dono`.

- [ ] **Step 1: Escrever a migration**

`supabase/migrations/0018_arquivar_listas.sql`:

```sql
-- 0018_arquivar_listas.sql — arquivar/desarquivar listas (doc 01 §4.1, RF-22, F26).
-- Estado global da lista; só o dono muda `arquivada_em` (a policy de UPDATE
-- permite dono/editor, então um trigger faz a defesa em profundidade).

alter table public.listas add column arquivada_em timestamptz;

create index idx_listas_dono_ativas
  on public.listas (dono_id)
  where deletado_em is null and arquivada_em is null;

create or replace function public.protege_arquivo_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.arquivada_em is distinct from old.arquivada_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_ARQUIVAR';
  end if;
  return new;
end;
$$;

create trigger trg_listas_arquivo_dono
  before update on public.listas
  for each row execute function public.protege_arquivo_dono();
```

- [ ] **Step 2: Escrever os testes SQL**

`supabase/tests/arquivar_listas_tests.sql`:

```sql
-- ============================================================================
-- arquivar_listas_tests.sql — coluna/trigger de arquivo (doc 01 §4.1, RF-22, F26)
-- Casos:
--   ARQ-01: dono arquiva e desarquiva → sucesso.
--   ARQ-02: editor tenta arquivar → APENAS_O_DONO_PODE_ARQUIVAR.
--   ARQ-03: editor renomeia sem tocar arquivada_em → sucesso.
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('f0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('f1000000-0000-0000-0000-000000000000', 'editor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('f9000000-0000-0000-0000-000000000000', 'Lista Arquivo', 'f0000000-0000-0000-0000-000000000000');

insert into public.lista_membros (lista_id, user_id, papel)
values
  ('f9000000-0000-0000-0000-000000000000', 'f0000000-0000-0000-0000-000000000000', 'dono'),
  ('f9000000-0000-0000-0000-000000000000', 'f1000000-0000-0000-0000-000000000000', 'editor')
on conflict (lista_id, user_id) do nothing;

-- ===== ARQ-01: dono arquiva e desarquiva =====
do $$
declare v timestamptz;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  update public.listas set arquivada_em = now() where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  select arquivada_em into v from public.listas where id = 'f9000000-0000-0000-0000-000000000000';
  if v is null then raise exception 'FALHOU ARQ-01: dono nao arquivou'; end if;

  perform set_config('role', 'authenticated', true);
  update public.listas set arquivada_em = null where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  select arquivada_em into v from public.listas where id = 'f9000000-0000-0000-0000-000000000000';
  if v is not null then raise exception 'FALHOU ARQ-01: dono nao desarquivou'; end if;
  raise notice 'OK ARQ-01: dono arquiva/desarquiva';
end $$;

-- ===== ARQ-02: editor tenta arquivar =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    update public.listas set arquivada_em = now() where id = 'f9000000-0000-0000-0000-000000000000';
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU ARQ-02: editor arquivou';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%APENAS_O_DONO_PODE_ARQUIVAR%' then
      raise exception 'FALHOU ARQ-02: erro inesperado %', v_msg;
    end if;
    raise notice 'OK ARQ-02: editor rejeitado';
  end;
end $$;

-- ===== ARQ-03: editor renomeia sem tocar arquivada_em =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  update public.listas set titulo = 'Renomeada pelo editor'
  where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  raise notice 'OK ARQ-03: editor renomeia sem interferencia';
end $$;

rollback;
```

- [ ] **Step 3: Rodar `db reset` e o script**

Run:
```powershell
supabase db reset
Get-Content supabase/tests/arquivar_listas_tests.sql -Raw | docker exec -i supabase_db_ListaCompras psql -U postgres -d postgres -v ON_ERROR_STOP=1
```
Expected: `OK ARQ-01`, `OK ARQ-02`, `OK ARQ-03` e `ROLLBACK`; nenhum `FALHOU`.

- [ ] **Step 4: CI e doc 07**

Em `.github/workflows/ci.yml`, após o step "Testes do preço do item (01 §4.3)":

```yaml
      - name: Testes de arquivar listas (01 §4.1)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/arquivar_listas_tests.sql
```

E no esqueleto do `docs/07-qualidade-ci.md` §3, após a linha do `preco_item_tests.sql`:

```
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/arquivar_listas_tests.sql
```

- [ ] **Step 5: Gate Flutter e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add supabase/migrations/0018_arquivar_listas.sql supabase/tests/arquivar_listas_tests.sql .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F26-T01: coluna e trigger de arquivo de lista (RF-22)"
```

---

### Task 2: Drift, domínio, repositório e aplicador — `arquivadaEm`

**Files:**
- Modify: `lib/drift/tables/lista_local.dart`
- Regenerate: `lib/drift/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- Modify: `lib/drift/database.dart` (schemaVersion 5 + migração)
- Modify: `lib/features/listas/domain/lista.dart`
- Modify: `lib/features/listas/data/listas_repository.dart`
- Modify: `lib/features/sync/data/aplicador_remoto.dart`
- Modify: `test/drift/database_test.dart`
- Modify: `test/features/listas/listas_repository_test.dart`
- Modify: `test/features/sync/aplicador_remoto_test.dart`

**Interfaces:**
- Consumes: coluna `arquivada_em` (Task 1).
- Produces: `Lista.arquivadaEm` (`DateTime?`); `ListasRepository.definirArquivada(String id, {required bool arquivada})`; payload de lista com `arquivada_em`; aplicador mapeia.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/drift/database_test.dart`, acrescentar ao final de `void main()` (o arquivo já importa `sq3`, `dart:io`, `NativeDatabase` e `AppDatabase`; espelha o teste v3→v4 existente):

```dart
  test(
    'deve_migrar_v4_para_v5_adicionando_arquivada_em_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v4 (com preco_centavos, sem arquivada_em): DDL
      // espelhando o schema v4 gerado, dados gravados e user_version = 4.
      final arquivo = File(
        '${Directory.systemTemp.path}/v4_para_v5_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 4;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('88888888-8888-8888-8888-888888888888', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final lista =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('88888888-8888-8888-8888-888888888888'),
              ))
              .getSingle();
      expect(lista.titulo, 'Antiga');
      expect(lista.arquivadaEm, isNull);

      // Escrita/leitura da coluna nova após a migração.
      final agora = DateTime.utc(2026, 9, 21, 12);
      await (migrado.update(migrado.listaLocal)
            ..where((l) => l.id.equals('88888888-8888-8888-8888-888888888888')))
          .write(ListaLocalCompanion(arquivadaEm: Value(agora)));
      final atualizada =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('88888888-8888-8888-8888-888888888888'),
              ))
              .getSingle();
      expect(atualizada.arquivadaEm?.toUtc(), agora);
    },
  );
```

Em `test/features/listas/listas_repository_test.dart`, acrescentar:

```dart
  test('deve_gravar_e_enfileirar_arquivo_quando_arquivar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirArquivada(lista.id, arquivada: true);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.arquivadaEm, isNotNull);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['arquivada_em'], isNotNull);
  });

  test('deve_limpar_arquivo_quando_desarquivar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirArquivada(lista.id, arquivada: true);

    await repo.definirArquivada(lista.id, arquivada: false);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.arquivadaEm, isNull);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['arquivada_em'], isNull);
  });

  test('nao_deve_arquivar_lista_nova_quando_duplicar', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    await repo.definirArquivada(origem.id, arquivada: true);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    expect(nova.arquivadaEm, isNull);
  });
```

Em `test/features/sync/aplicador_remoto_test.dart`, acrescentar (usando a classe `AplicadorRemoto(db).aplicar(...)`):

```dart
  test('deve_mapear_arquivo_ausente_para_null_quando_linha_antiga', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-arq-1',
      'titulo': 'X',
      'dono_id': 'u',
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-arq-1'))).getSingle();
    expect(lista.arquivadaEm, isNull);
  });

  test('deve_mapear_arquivo_quando_presente', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-arq-2',
      'titulo': 'X',
      'dono_id': 'u',
      'arquivada_em': '2026-09-21T12:00:00.000Z',
      'created_at': '2026-09-21T11:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-arq-2'))).getSingle();
    expect(lista.arquivadaEm, isNotNull);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart`
Expected: FAIL na compilação — `The method 'definirArquivada' isn't defined` e `The getter 'arquivadaEm' isn't defined`.

- [ ] **Step 3: Implementar**

- `lib/drift/tables/lista_local.dart` — após `deletadoEm`:
  ```dart
  DateTimeColumn get arquivadaEm => dateTime().nullable()();
  ```
- Regerar: `dart run build_runner build --delete-conflicting-outputs`.
- `lib/drift/database.dart`: `schemaVersion` → `5`; no `onUpgrade`, após o `if (de < 4)`:
  ```dart
      if (de < 5) {
        // v4 → v5: coluna arquivada_em (doc 01 §4.1, RF-22, F26).
        await m.addColumn(listaLocal, listaLocal.arquivadaEm);
      }
  ```
- `lib/features/listas/domain/lista.dart`: `final DateTime? arquivadaEm;` + `arquivadaEm: d.arquivadaEm` em `fromLocal`.
- `lib/features/listas/data/listas_repository.dart`:
  - `_payloadLista`: adicionar `'arquivada_em': l.arquivadaEm == null ? null : _iso(l.arquivadaEm!),`.
  - Novo método após `excluirLista`:
    ```dart
    /// Arquiva/desarquiva a lista (RF-22): estado global, só o dono (o
    /// trigger do servidor garante). Offline-first: Drift + fila.
    Future<void> definirArquivada(String id, {required bool arquivada}) async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(
          arquivadaEm: Value(arquivada ? agora : null),
          updatedAt: Value(agora),
        ),
      );
      await _enfileirar(
        tabela: 'listas',
        operacao: 'UPDATE',
        registroId: id,
        listaId: id,
        tsLocal: agora,
        payload: await _payloadLista(id),
      );
    }
    ```
  - `duplicarLista` cria lista nova (não arquivada) — já é o default; nada a mudar.
- `lib/features/sync/data/aplicador_remoto.dart` (`_aplicarLista`): adicionar
  ```dart
  arquivadaEm: Value(_dataOpcional(r['arquivada_em'])),
  ```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart test/drift/database_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/drift/tables/lista_local.dart lib/drift/database.g.dart lib/drift/database.dart lib/features/listas/domain/lista.dart lib/features/listas/data/listas_repository.dart lib/features/sync/data/aplicador_remoto.dart test/drift/database_test.dart test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart
git commit -m "F26-T02: arquivadaEm no Drift, dominio, repositorio e aplicador (RF-22)"
```

---

### Task 3: UI — toggle "Mostrar arquivadas", ação no card e rótulo

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (strings novas)
- Modify: `lib/features/listas/ui/painel_listas.dart`
- Modify: `test/features/listas/minhas_listas_screen_test.dart`
- Modify: `test/features/listas/compartilhadas_screen_test.dart`

**Interfaces:**
- Consumes: `ListasRepository.definirArquivada` (Task 2); `Lista.arquivadaEm`; `listasComContagemProvider`.
- Produces: nada consumido por outras tarefas.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`, após `static const renomear = ...` (ou perto de `renomear`/`excluir`):

```dart
  static const mostrarArquivadas = 'Mostrar arquivadas';
  static const arquivar = 'Arquivar';
  static const desarquivar = 'Desarquivar';
  static const arquivada = 'Arquivada';
  static const listaArquivada = 'Lista arquivada.';
  static const listaDesarquivada = 'Lista desarquivada.';
```

- [ ] **Step 2: Escrever os testes que falham**

Em `test/features/listas/minhas_listas_screen_test.dart`, acrescentar ao final de `void main()` (o arquivo já tem `db`, `abrirTela`, `fechar`):

```dart
  testWidgets('nao_deve_mostrar_arquivada_por_padrao_quando_painel', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Velha', donoId: 'user-a');
    await repo.definirArquivada(lista.id, arquivada: true);
    await abrirTela(tester);

    expect(find.text('Velha'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_arquivada_com_rotulo_quando_toggle_ligado', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Velha', donoId: 'user-a');
    await repo.definirArquivada(lista.id, arquivada: true);
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.mostrarArquivadas));
    await tester.pumpAndSettle();

    expect(find.text('Velha'), findsOneWidget);
    expect(find.text(AppStrings.arquivada), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_arquivar_quando_dono_toca_menu', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Ativa', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.arquivar));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsNothing);
    expect(find.text(AppStrings.listaArquivada), findsOneWidget);
    await fechar(tester);
  });
```

Em `test/features/listas/compartilhadas_screen_test.dart`, acrescentar um teste de que **membro não vê** "Arquivar":

```dart
  testWidgets('nao_deve_mostrar_arquivar_para_membro', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-b');
    await abrirTela(tester, usuario: 'user-a');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.arquivar), findsNothing);
    await fechar(tester);
  });
```

> Use o harness real do arquivo (`abrirTela(tester, usuario: ...)` já existe em `compartilhadas_screen_test.dart`).

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: FAIL — o toggle/ação/rótulo ainda não existem.

- [ ] **Step 4: Implementar no painel**

Em `lib/features/listas/ui/painel_listas.dart`:

1. Em `_PainelListasState`, novo estado:
   ```dart
   bool _mostrarArquivadas = false;
   ```
2. No `build`, no filtro de `listasAsync`, adicionar o filtro de arquivadas (antes do filtro de busca):
   ```dart
   .where((c) => _mostrarArquivadas || c.lista.arquivadaEm == null)
   ```
3. Na AppBar, no ramo `else ...[` (quando não está buscando), adicionar o toggle antes da lupa:
   ```dart
   IconButton(
     tooltip: AppStrings.mostrarArquivadas,
     icon: Icon(
       _mostrarArquivadas ? Icons.inventory_2 : Icons.inventory_2_outlined,
     ),
     onPressed: () => setState(() => _mostrarArquivadas = !_mostrarArquivadas),
   ),
   ```
4. Em `_CardListaState._itensDono`, adicionar o item (dono) no topo:
   ```dart
   if (widget.contagem.lista.arquivadaEm == null)
     const PopupMenuItem(value: 'arquivar', child: Text(AppStrings.arquivar))
   else
     const PopupMenuItem(value: 'desarquivar', child: Text(AppStrings.desarquivar)),
   ```
5. Em `_acaoMenu`, novos cases:
   ```dart
   case 'arquivar':
     _definirArquivada(true);
   case 'desarquivar':
     _definirArquivada(false);
   ```
6. Método:
   ```dart
   Future<void> _definirArquivada(bool arquivada) async {
     try {
       await ref
           .read(listasRepositoryProvider)
           .definirArquivada(widget.contagem.lista.id, arquivada: arquivada);
       if (mounted) {
         mostrarSnackBar(
           context,
           arquivada ? AppStrings.listaArquivada : AppStrings.listaDesarquivada,
         );
       }
     } catch (_) {
       if (mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
     }
   }
   ```
7. No `subtitle` do card (a `Column` que já mostra contagem/atualização), quando `widget.contagem.lista.arquivadaEm != null`, adicionar:
   ```dart
   const AppChip(rotulo: AppStrings.arquivada),
   ```
   (importe `../../../core/widgets/app_chip.dart` se necessário).

> O menu de **membro** (`_itensMembro`) **não** ganha a ação.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/painel_listas.dart test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart
git commit -m "F26-T03: toggle de arquivadas e acao no card (RF-22)"
```

---

### Task 4: Docs donos e fechamento da Fase 26

**Files:**
- Modify: `docs/01-banco-de-dados.md` (§4.1 — coluna/índice/trigger)
- Modify: `docs/03-sincronizacao-offline.md` (payload de lista inclui `arquivada_em`)
- Modify: `docs/05-app-flutter.md` (§6.2 — toggle e ação)
- Modify: `docs/10-wireframes-telas.md` (toggle + rótulo do card)
- Modify: `docs/12-prd.md` (RF-22)
- Modify: `docs/14-tarefas.md` (Fase 26 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A2 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–3.
- Produces: nada consumido por código.

- [ ] **Step 1: Doc 01**
  - §4.1: adicionar `arquivada_em timestamptz` à tabela SQL de `listas` e à lista de campos (`null` = ativa); citar o índice `idx_listas_dono_ativas` e o trigger `protege_arquivo_dono`/`trg_listas_arquivo_dono` (só o dono muda `arquivada_em`; migration `0018`).

- [ ] **Step 2: Doc 03**
  - No ponto do payload de listas, incluir `arquivada_em` e a tolerância do aplicador (ausente → `null`).

- [ ] **Step 3: Docs 05 e 10**
  - `05 §6.2`: bullet "Arquivar listas (RF-22, F26)" — botão "Mostrar arquivadas" na AppBar (ocultas por padrão); menu `⋮` do dono com Arquivar/Desarquivar; rótulo "Arquivada"; a busca respeita o toggle.
  - `10 §2`: acrescentar o toggle na AppBar do painel e o rótulo "Arquivada" no card (wireframe/nota).

- [ ] **Step 4: Doc 12 e 16**
  - `12 §2`: `RF-22 | Arquivar/desarquivar listas (estado global, só o dono) | 05 §6.2 + 10 §2 | F26 | ...`; §6: rastreabilidade `RF-22 | US-01 | F26 | F26-T02, F26-T03 | Unit arquivo + widgets`.
  - `16`: Onda A linha A2 → `concluído (F26-T01…T04)`.

- [ ] **Step 5: Doc 14 (Fase 26 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 26 com F26-T01…T04 `[x]` e CPs.
  - Na tabela, após `| F25 Preço e total | 5 | 5 |`, adicionar `| F26 Arquivar listas | 4 | 4 |` e atualizar o total para `| **Total** | **152** | **150** |`.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/01-banco-de-dados.md docs/03-sincronizacao-offline.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F26-T04: docs donos e fechamento da Fase 26 (RF-22)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 banco → Task 1; §4 Drift/domínio/repo/aplicador → Task 2 (inclui o bump do `schemaVersion`, que faltou na F25); §5 UI → Task 3; §6 itens frequentes inalterados (nenhuma mudança); §7 testes → Tasks 1–3; docs → Task 4.
- **Placeholders:** nenhum "TBD"; o teste de migração v4→v5 está completo (DDL espelhando o schema v4), e todo o código de produção/teste está escrito.
- **Consistência de tipos:** `arquivadaEm` (`DateTime?`), `definirArquivada(String, {required bool arquivada})`, payload `arquivada_em`, strings, progresso 152/150 — idênticos entre tarefas.
- **Lição da F25 aplicada:** o bump do `schemaVersion` do Drift está **explicitamente** na Task 2.
