# Fase 24 — Transferência de Dono (RF-14): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-14 — o dono pode transferir a lista para outro membro (vira editor), fechando a colaboração: migration `0016` (RPC `transferir_dono` + `sync_dono` v3 + R-17) e a UI na tela de membros, com aviso ao novo dono via Realtime.

**Architecture:** RPC `security definer` marca a transação com `app.transferindo_dono`; o trigger `sync_dono` v3 libera o downgrade do dono só sob a flag (padrão da `excluir_conta`). O RPC demove o antigo e promove o novo; `listas.dono_id` continua sendo ajustado **só pelo trigger**. No app, a operação é **online-only** (papel não vive no Drift) e o aviso ao novo dono reusa o canal Realtime de `lista_membros` + um `ValueNotifier`, como o "membro entrou".

**Tech Stack:** Postgres/Supabase (RLS, trigger, RPC) · Flutter · Riverpod · go_router · Realtime.

**Spec:** `docs/superpowers/specs/2026-09-21-transferencia-dono-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes; as tarefas de banco rodam também `supabase db reset` + o script SQL novo.
- Uma tarefa = um commit, mensagem `F24-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `docs/03`** (sync) nem no cliente da service_role; nenhum segredo em código/log.
- Migrations **append-only**: `0016_transferir_dono.sql`; nunca editar migrations antigas.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Enum de papéis fechado: `dono, editor, leitor`.
- Aviso ao novo dono é **genérico, sem nome** (o RLS não expõe perfis).
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Banco — migration `0016` (RPC, trigger v3, R-17) + testes SQL + CI

**Files:**
- Create: `supabase/migrations/0016_transferir_dono.sql`
- Create: `supabase/tests/transferir_dono_tests.sql`
- Modify: `.github/workflows/ci.yml` (novo step de `psql`, após o de `aceitar_convite_tests`)
- Modify: `docs/07-qualidade-ci.md` (§3 esqueleto — nova linha de `psql`)

**Interfaces:**
- Consumes: `sync_dono` v2 (`0005_excluir_conta.sql:37`), `listas.dono_id`, `lista_membros`, `convites.criado_por` (`0007_convites.sql:13`).
- Produces: RPC `public.transferir_dono(p_lista uuid, p_novo_dono uuid)`; trigger `sync_dono` v3; FK `convites_criado_por_fkey` com `on delete cascade`.

- [ ] **Step 1: Escrever a migration**

Criar `supabase/migrations/0016_transferir_dono.sql`:

```sql
-- 0016_transferir_dono.sql — transferência de dono (doc 08 §6, RF-14, Fase 6).
-- Reaproveita o padrão da exclusão de conta (0005): o RPC security definer
-- marca a transação e o trigger sync_dono reconhece a marca. listas.dono_id
-- continua sendo ajustado SOMENTE pelo trigger (fonte única).

create or replace function public.transferir_dono(p_lista uuid, p_novo_dono uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  papel_novo text;
begin
  if auth.uid() is null then
    raise exception 'AUTENTICACAO_NECESSARIA';
  end if;

  if not exists (
    select 1 from public.listas
    where id = p_lista and dono_id = auth.uid()
  ) then
    raise exception 'APENAS_O_DONO_PODE_TRANSFERIR';
  end if;

  if p_novo_dono = auth.uid() then
    raise exception 'NAO_PODE_TRANSFERIR_PARA_SI';
  end if;

  select papel into papel_novo
  from public.lista_membros
  where lista_id = p_lista and user_id = p_novo_dono;
  if papel_novo is null then
    raise exception 'NOVO_DONO_PRECISA_SER_MEMBRO';
  end if;

  perform set_config('app.transferindo_dono', 'true', true);

  -- Ordem importa: demove o antigo ANTES de promover o novo.
  update public.lista_membros set papel = 'editor'
  where lista_id = p_lista and user_id = auth.uid();

  update public.lista_membros set papel = 'dono'
  where lista_id = p_lista and user_id = p_novo_dono;
end;
$$;

revoke execute on function public.transferir_dono(uuid, uuid) from public, anon;
grant execute on function public.transferir_dono(uuid, uuid) to authenticated;

-- sync_dono v3 (doc 01 §6): mesma regra + exceção para a transferência.
create or replace function public.sync_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  qtd_donos int;
begin
  select count(*) into qtd_donos
  from public.lista_membros
  where lista_id = coalesce(new.lista_id, old.lista_id)
    and papel = 'dono';

  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if qtd_donos > 1 then
      raise exception 'Lista já possui um dono';
    end if;

    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    if coalesce(current_setting('app.excluindo_conta', true), '') <> 'true'
       and coalesce(current_setting('app.transferindo_dono', true), '') <> 'true' then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

-- R-17: convites.criado_por ganha cascade (a transferência torna o risco real).
alter table public.convites drop constraint convites_criado_por_fkey;
alter table public.convites
  add constraint convites_criado_por_fkey
  foreign key (criado_por) references auth.users(id) on delete cascade;
```

- [ ] **Step 2: Escrever os testes SQL**

Criar `supabase/tests/transferir_dono_tests.sql` (transação com ROLLBACK, como os demais):

```sql
-- ============================================================================
-- transferir_dono_tests.sql — RPC transferir_dono (doc 08 §6, RF-14, F24-T01)
-- Casos:
--   T-01: dono transfere para editor → papéis trocam, dono_id = novo.
--   T-02: dono transfere para leitor → leitor vira dono.
--   T-03: não-dono tenta → APENAS_O_DONO_PODE_TRANSFERIR.
--   T-04: destino sem membership → NOVO_DONO_PRECISA_SER_MEMBRO.
--   T-05: transferir para si → NAO_PODE_TRANSFERIR_PARA_SI.
--   T-06: sem a flag, rebaixar o dono direto segue bloqueado pelo trigger.
--   T-07 (R-17): excluir a conta do ex-dono com convite criado não falha e o
--                convite some (cascade).
-- Execução após `supabase db reset`; ROLLBACK final deixa o banco intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('d0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d1000000-0000-0000-0000-000000000000', 'editor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d2000000-0000-0000-0000-000000000000', 'leitor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d3000000-0000-0000-0000-000000000000', 'outsider@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- list1: dono D, editor E, leitor L. list2: dono D, leitor L.
insert into public.listas (id, titulo, dono_id)
values
  ('d9000000-0000-0000-0000-000000000000', 'Lista 1', 'd0000000-0000-0000-0000-000000000000'),
  ('d9000000-0000-0000-0000-000000000001', 'Lista 2', 'd0000000-0000-0000-0000-000000000000');

insert into public.lista_membros (lista_id, user_id, papel)
values
  ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'dono'),
  ('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'editor'),
  ('d9000000-0000-0000-0000-000000000000', 'd2000000-0000-0000-0000-000000000000', 'leitor'),
  ('d9000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000000', 'dono'),
  ('d9000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000000', 'leitor')
on conflict (lista_id, user_id) do nothing;

-- Convite criado por D (T-07: cascade).
insert into public.convites (lista_id, criado_por, token, tipo, papel_oferecido)
values ('d9000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000000',
        'e9000000-0000-0000-0000-000000000000', 'link', 'editor');

-- ===== T-01: D transfere list1 para E =====
do $$
declare
  v_papel_d text; v_papel_e text; v_dono uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000');
  perform set_config('role', 'postgres', true);

  select papel into v_papel_d from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000000' and user_id = 'd0000000-0000-0000-0000-000000000000';
  select papel into v_papel_e from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000000' and user_id = 'd1000000-0000-0000-0000-000000000000';
  select dono_id into v_dono from public.listas where id = 'd9000000-0000-0000-0000-000000000000';

  if v_papel_d <> 'editor' then raise exception 'FALHOU T-01: D ficou %', v_papel_d; end if;
  if v_papel_e <> 'dono' then raise exception 'FALHOU T-01: E ficou %', v_papel_e; end if;
  if v_dono is distinct from 'd1000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU T-01: dono_id = %', v_dono;
  end if;
  raise notice 'OK T-01: transferencia para editor';
end $$;

-- ===== T-03: leitor L (não-dono de list1) tenta transferir =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d2000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd2000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-03: nao-dono transferiu';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%APENAS_O_DONO_PODE_TRANSFERIR%' then
      raise exception 'FALHOU T-03: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-03: %', v_msg;
  end;
end $$;

-- ===== T-04: E (dono de list1) transfere para outsider O =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd3000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-04: destino sem membership aceito';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%NOVO_DONO_PRECISA_SER_MEMBRO%' then
      raise exception 'FALHOU T-04: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-04: %', v_msg;
  end;
end $$;

-- ===== T-05: E (dono de list1) transfere para si =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-05: transferiu para si';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%NAO_PODE_TRANSFERIR_PARA_SI%' then
      raise exception 'FALHOU T-05: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-05: %', v_msg;
  end;
end $$;

-- ===== T-02: D (dono de list2) transfere para L =====
do $$
declare v_papel_l text; v_papel_d text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.transferir_dono('d9000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000000');
  perform set_config('role', 'postgres', true);

  select papel into v_papel_l from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000001' and user_id = 'd2000000-0000-0000-0000-000000000000';
  select papel into v_papel_d from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000001' and user_id = 'd0000000-0000-0000-0000-000000000000';
  if v_papel_l <> 'dono' then raise exception 'FALHOU T-02: L ficou %', v_papel_l; end if;
  if v_papel_d <> 'editor' then raise exception 'FALHOU T-02: D ficou %', v_papel_d; end if;
  raise notice 'OK T-02: transferencia para leitor';
end $$;

-- ===== T-06: sem a flag, rebaixar o dono direto segue bloqueado =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'postgres', true);
  begin
    update public.lista_membros set papel = 'editor'
    where lista_id = 'd9000000-0000-0000-0000-000000000000'
      and user_id = 'd1000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU T-06: downgrade direto aceito';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg not like '%processo expl%' then
      raise exception 'FALHOU T-06: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-06: trigger bloqueou downgrade direto';
  end;
end $$;

-- ===== T-07 (R-17): excluir D (ex-dono) some com o convite criado =====
do $$
declare v_convites int;
begin
  perform set_config('role', 'postgres', true);
  delete from auth.users where id = 'd0000000-0000-0000-0000-000000000000';
  select count(*) into v_convites from public.convites
   where criado_por = 'd0000000-0000-0000-0000-000000000000';
  if v_convites <> 0 then
    raise exception 'FALHOU T-07 (R-17): % convite(s) restantes', v_convites;
  end if;
  raise notice 'OK T-07: cascade de convites.criado_por';
end $$;

rollback;
```

- [ ] **Step 3: Rodar `db reset` e o script (verde)**

Run:
```powershell
supabase db reset
Get-Content supabase/tests/transferir_dono_tests.sql -Raw | docker exec -i supabase_db_ListaCompras psql -U postgres -d postgres -v ON_ERROR_STOP=1
```
Expected: 7 `OK T-*` e nenhum `FALHOU`. (Se o container tiver outro nome, use o comando do cabeçalho do `rls_tests.sql`.)

- [ ] **Step 4: Adicionar o script ao CI**

Em `.github/workflows/ci.yml`, após o step "Testes do aceite de convite (08 §3.1)":

```yaml
      - name: Testes da transferência de dono (08 §6)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/transferir_dono_tests.sql
```

E no esqueleto do `docs/07-qualidade-ci.md` §3, após a linha do `aceitar_convite_tests.sql`:

```
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/transferir_dono_tests.sql
```

- [ ] **Step 5: Rodar a suíte Flutter e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde (nenhuma mudança no app nesta tarefa).

```bash
git add supabase/migrations/0016_transferir_dono.sql supabase/tests/transferir_dono_tests.sql .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F24-T01: migration transferir_dono, trigger v3 e R-17 (RF-14)"
```

---

### Task 2: App — `ConvitesRepository.transferirDono` + erros + strings

**Files:**
- Modify: `lib/features/convites/domain/convite.dart` (`ErroConvite.fromCodigoTransferencia`)
- Modify: `lib/features/convites/data/convites_repository.dart` (método novo)
- Modify: `lib/core/l10n/app_strings.dart` (8 strings novas)
- Modify: `test/features/convites/convites_repository_test.dart`

**Interfaces:**
- Consumes: RPC `transferir_dono` (Task 1); `ehSemConexao` (`lib/core/rede/erro_rede.dart`); `ServidorFake`.
- Produces: `Future<void> ConvitesRepository.transferirDono({required String listaId, required String novoDonoId})`; `ErroConvite.fromCodigoTransferencia(String)`; strings `transferirDono`, `transferirDonoTitulo`, `transferirDonoMensagem`, `transferirDonoMensagemFinal`, `donoTransferido`, `transferirApenasDono`, `transferirDestinoInvalido`, `transferirSemConexao`, `voceAgoraDono`.

- [ ] **Step 1: Escrever as strings e os testes que falham**

Em `lib/core/l10n/app_strings.dart`, após `static const membroEntrou = 'Um novo membro entrou na lista';` (linha 246):

```dart
  static const transferirDono = 'Transferir dono';
  static const transferirDonoTitulo = 'Transferir dono?';
  static const transferirDonoMensagem =
      'Você deixará de ser dono e passará a editor desta lista.';
  static const transferirDonoMensagemFinal =
      'Confirmar a transferência? Depois disso você poderá sair da lista.';
  static const donoTransferido = 'Dono transferido.';
  static const transferirApenasDono = 'Só o dono pode transferir a lista.';
  static const transferirDestinoInvalido =
      'Escolha um participante da lista para receber.';
  static const transferirSemConexao =
      'Conecte-se para transferir a lista.';
  static const voceAgoraDono = 'Você agora é dono de uma lista';
```

Acrescentar ao final de `void main()` em `test/features/convites/convites_repository_test.dart`:

```dart
  group('transferir_dono', () {
    ConvitesRepository repoCom(ServidorFake servidor) => ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    test('deve_chamar_rpc_de_transferencia_quando_transfere', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' &&
            req.url.path.contains('transferir_dono')) {
          return (200, const <Object?>[]);
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await repoCom(servidor).transferirDono(
        listaId: _listaId,
        novoDonoId: 'U2',
      );

      final corpo =
          jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
      expect(corpo, {'p_lista': _listaId, 'p_novo_dono': 'U2'});
    });

    test('deve_mapear_apenas_dono_quando_servidor_nega', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' &&
            req.url.path.contains('transferir_dono')) {
          return (
            400,
            {
              'code': 'P0001',
              'message': 'APENAS_O_DONO_PODE_TRANSFERIR',
              'details': null,
              'hint': null,
            },
          );
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await expectLater(
        repoCom(servidor).transferirDono(listaId: _listaId, novoDonoId: 'U2'),
        throwsA(
          isA<ErroConvite>()
              .having((e) => e.code, 'code', 'apenas_dono')
              .having((e) => e.message, 'message', AppStrings.transferirApenasDono),
        ),
      );
    });

    test('deve_mapear_destino_invalido_quando_servidor_nega', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' &&
            req.url.path.contains('transferir_dono')) {
          return (
            400,
            {
              'code': 'P0001',
              'message': 'NOVO_DONO_PRECISA_SER_MEMBRO',
              'details': null,
              'hint': null,
            },
          );
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await expectLater(
        repoCom(servidor).transferirDono(listaId: _listaId, novoDonoId: 'U2'),
        throwsA(
          isA<ErroConvite>().having(
            (e) => e.message,
            'message',
            AppStrings.transferirDestinoInvalido,
          ),
        ),
      );
    });

    test('deve_mapear_sem_conexao_quando_socket_ao_transferir', () async {
      final servidor = ServidorFake((req) {
        throw const SocketException('sem rota');
      });
      addTearDown(servidor.close);

      await expectLater(
        repoCom(servidor).transferirDono(listaId: _listaId, novoDonoId: 'U2'),
        throwsA(
          isA<ErroConvite>()
              .having((e) => e.code, 'code', 'sem_conexao')
              .having((e) => e.message, 'message', AppStrings.transferirSemConexao),
        ),
      );
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/convites_repository_test.dart`
Expected: FAIL na compilação — `The method 'transferirDono' isn't defined for the type 'ConvitesRepository'` e `Member not found: 'transferirApenasDono'`.

- [ ] **Step 3: Implementar o mapeamento e o método**

Em `lib/features/convites/domain/convite.dart`, adicionar em `ErroConvite` (após `fromCodigoDoContrato`):

```dart
  /// Mapeia os códigos do RPC `transferir_dono` (doc 08 §6, RF-14, F24).
  static ErroConvite fromCodigoTransferencia(String mensagemServidor) {
    final maiuscula = mensagemServidor.toUpperCase();
    if (maiuscula.contains('APENAS_O_DONO_PODE_TRANSFERIR')) {
      return const ErroConvite('apenas_dono', AppStrings.transferirApenasDono);
    }
    if (maiuscula.contains('NOVO_DONO_PRECISA_SER_MEMBRO') ||
        maiuscula.contains('NAO_PODE_TRANSFERIR_PARA_SI')) {
      return const ErroConvite(
        'destino_invalido',
        AppStrings.transferirDestinoInvalido,
      );
    }
    return const ErroConvite('inesperado', AppStrings.conviteInesperado);
  }
```

Em `lib/features/convites/data/convites_repository.dart`, adicionar após `aceitar`:

```dart
  /// Transfere a lista para outro membro (doc 08 §6, RF-14, F24):
  /// online-only (papel não vive no Drift). Erros do contrato viram
  /// mensagens amigáveis, como nos demais RPCs.
  Future<void> transferirDono({
    required String listaId,
    required String novoDonoId,
  }) async {
    try {
      await _client.rpc(
        'transferir_dono',
        params: {'p_lista': listaId, 'p_novo_dono': novoDonoId},
      );
    } on PostgrestException catch (e) {
      throw ErroConvite.fromCodigoTransferencia(e.message);
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.transferirSemConexao);
      }
      rethrow;
    }
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/convites_repository_test.dart`
Expected: PASS (todos, incluindo os 4 novos).

- [ ] **Step 5: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/convites/domain/convite.dart lib/features/convites/data/convites_repository.dart lib/core/l10n/app_strings.dart test/features/convites/convites_repository_test.dart
git commit -m "F24-T02: repositorio transferirDono com erros amigaveis (RF-14)"
```

---

### Task 3: App — "Transferir dono" na tela de membros

**Files:**
- Modify: `lib/features/convites/ui/tela_membros_screen.dart`
- Modify: `test/features/convites/tela_membros_screen_test.dart`

**Interfaces:**
- Consumes: `ConvitesRepository.transferirDono` (Task 2); `papelRepositoryProvider.atualizar`; `AppDialog.confirmarDestrutivo`; `membrosDaListaProvider`.
- Produces: nada consumido por outras tarefas.

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar ao final de `void main()` em `test/features/convites/tela_membros_screen_test.dart` (seguindo o harness já existente no arquivo: `ServidorFake`, `ProviderScope` com `donoAtualIdProvider`, `papelRepositoryProvider`):

```dart
  testWidgets('deve_mostrar_transferir_dono_so_para_dono', (tester) async {
    // dono D vê a opção no menu de outro membro, mas não em si mesmo.
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      if (req.method == 'GET' && req.url.path.contains('/listas')) {
        return (200, _listaLinha());
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrirTela(tester, servidor);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.transferirDono), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_transferir_quando_cancela_confirmacao', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      if (req.method == 'GET' && req.url.path.contains('/listas')) {
        return (200, _listaLinha());
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrirTela(tester, servidor);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.transferirDono));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.transferirDonoTitulo), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, AppStrings.cancelar));
    await tester.pumpAndSettle();

    expect(
      servidor.pedidos.where((p) => p.url.path.contains('transferir_dono')),
      isEmpty,
    );
    await fechar(tester);
  });

  testWidgets('deve_transferir_quando_confirma_duas_vezes', (tester) async {
    var papelAtualizado = false;
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('transferir_dono')) {
        return (200, const <Object?>[]);
      }
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      if (req.method == 'GET' && req.url.path.contains('/listas')) {
        return (200, _listaLinha());
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrirTela(tester, servidor, aoAtualizarPapel: () => papelAtualizado = true);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.transferirDono));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.continuar));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.transferirDono),
    );
    await tester.pumpAndSettle();

    expect(papelAtualizado, isTrue);
    expect(find.text(AppStrings.donoTransferido), findsOneWidget);
    await fechar(tester);
  });
```

> O harness `abrirTela`/`fechar`, os helpers `_linhasMembros`/`_listaLinha` e o parâmetro `aoAtualizarPapel` podem precisar ser adicionados/ajustados no arquivo seguindo o que já existe — use o harness real do arquivo (ele já cria `ServidorFake`, `donoAtualIdProvider = 'D'` e o `PapelRepository`); reaproveite os helpers existentes em vez de duplicar. Se `aoAtualizarPapel` for difícil de costurar, valide o efeito pelo `papelRepository` lido do container, como em `minhas_listas_screen_test.dart:221-226`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: FAIL — `find.text(AppStrings.transferirDono)` sem resultado (item ainda não existe).

- [ ] **Step 3: Implementar o item de menu e o fluxo**

Em `lib/features/convites/ui/tela_membros_screen.dart`, no `PopupMenuButton<String>` do `build`, adicionar o item (para dono e alvo ≠ eu):

```dart
                            if (_eDono(membrosAsync, usuarioId) && !souEu)
                              PopupMenuItem(
                                value: 'transferir',
                                child: Text(AppStrings.transferirDono),
                              ),
```

No `_acaoMenu`, adicionar o case:

```dart
      case 'transferir':
        _confirmarTransferencia(context, ref, membro);
```

E o método (perto de `_confirmarRemover`):

```dart
  Future<void> _confirmarTransferencia(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
  ) async {
    // Confirmação dupla (doc 08 §6): explica a perda de poderes e confirma.
    final passo1 = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.transferirDonoTitulo,
      mensagem: AppStrings.transferirDonoMensagem,
      confirmar: AppStrings.continuar,
    );
    if (!passo1 || !context.mounted) return;
    final passo2 = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.transferirDonoTitulo,
      mensagem: AppStrings.transferirDonoMensagemFinal,
      confirmar: AppStrings.transferirDono,
    );
    if (!passo2 || !context.mounted) return;

    try {
      await ref
          .read(convitesRepositoryProvider)
          .transferirDono(listaId: listaId, novoDonoId: membro.userId);
      ref.read(papelRepositoryProvider).atualizar(listaId, Papel.editor);
      ref.invalidate(membrosDaListaProvider(listaId));
      if (context.mounted) mostrarSnackBar(context, AppStrings.donoTransferido);
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os 3 novos).

- [ ] **Step 5: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/convites/ui/tela_membros_screen.dart test/features/convites/tela_membros_screen_test.dart
git commit -m "F24-T03: transferir dono na tela de membros com confirmacao dupla (RF-14)"
```

---

### Task 4: App — aviso ao novo dono via Realtime

**Files:**
- Modify: `lib/features/convites/data/papel_repository.dart`
- Modify: `lib/features/convites/data/papel_realtime.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Modify: `test/features/convites/papel_repository_test.dart`
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `AppStrings.voceAgoraDono` (Task 2); canal Realtime de `lista_membros` (`supabase_bootstrap.dart:202-207`); padrão `membroEntrou` (`papel_repository.dart:21,72,75`).
- Produces: `ValueNotifier<String?> PapelRepository.donoTransferido`, `notificarDono`, `consumirDono`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/convites/papel_repository_test.dart`, acrescentar ao final de `void main()`:

```dart
  test('deve_sinalizar_dono_transferido_quando_update_para_dono', () {
    final repo = PapelRepository(Supabase.instance.client);
    aplicarEventoMembro(
      usuarioAtual: 'U1',
      payload: _payloadUpdate(paraPapel: 'dono', dePapel: 'editor'),
      onPerdaAcesso: () {},
      papelRepository: repo,
    );
    expect(repo.donoTransferido.value, 'l1');
    repo.consumirDono();
    expect(repo.donoTransferido.value, isNull);
  });

  test('nao_deve_sinalizar_dono_quando_ja_era_dono', () {
    final repo = PapelRepository(Supabase.instance.client);
    aplicarEventoMembro(
      usuarioAtual: 'U1',
      payload: _payloadUpdate(paraPapel: 'dono', dePapel: 'dono'),
      onPerdaAcesso: () {},
      papelRepository: repo,
    );
    expect(repo.donoTransferido.value, isNull);
  });
```

> `_payloadUpdate` segue o payload de `lista_membros` já montado no arquivo (`papel_repository_test.dart:34-46`); ajuste o helper existente para parametrizar `papel`/`old papel` em vez de criar outro.

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar (espelhando os testes de `membroEntrou`, linhas ~1195-1220):

```dart
  testWidgets('deve_mostrar_voce_agora_dono_quando_papel_vira_dono', (
    tester,
  ) async {
    // ... montar a tela como no teste de `membroEntrou` ...
    // papelRepo.notificarDono(listaId);
    // await tester.pumpAndSettle();
    expect(find.text(AppStrings.voceAgoraDono), findsOneWidget);
  });
```

> Reuse o setup do teste `deve_mostrar_membro_entrou...` do mesmo arquivo (servidor fake, `papelRepo`); troque `notificarEntrada` por `notificarDono` e a string esperada.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/papel_repository_test.dart`
Expected: FAIL na compilação — `The getter 'donoTransferido' isn't defined` / `Member not found: 'consumirDono'`.

- [ ] **Step 3: Implementar o notifier e o sinal**

Em `lib/features/convites/data/papel_repository.dart`:

Após `final ValueNotifier<String?> membroEntrou = ValueNotifier(null);` (linha 21):

```dart
  /// Última lista onde o usuário virou dono por transferência (RF-14): sinal
  /// one-shot, espelho de [membroEntrou].
  final ValueNotifier<String?> donoTransferido = ValueNotifier(null);
```

Após `void consumirEntrada() => membroEntrou.value = null;` (linha 75):

```dart
  /// UPDATE de `lista_membros` que promove o usuário a dono (RF-14).
  void notificarDono(String listaId) => donoTransferido.value = listaId;

  void consumirDono() => donoTransferido.value = null;
```

E em `limpar()` (linha 82), adicionar `donoTransferido.value = null;` junto de `membroEntrou.value = null;`.

Em `lib/features/convites/data/papel_realtime.dart`, no `switch`, no case insert/update do próprio usuário, após atualizar o papel:

```dart
      try {
        papelRepository?.atualizar(listaId, Papel.fromValor(valor));
      } on ArgumentError {
        // Papel fora do enum fechado (servidor divergiu): linha ignorada.
      }
      // Transferência de dono para mim (RF-14): avisa a UI aberta.
      if (evento == PostgresChangeEvent.update &&
          payload.newRecord['papel'] == 'dono' &&
          payload.oldRecord['papel'] != 'dono') {
        papelRepository?.notificarDono(listaId);
      }
```

Em `lib/features/listas/ui/tela_lista_screen.dart`, espelhar o `_membroEntrou`:

- Campo `ValueNotifier<String?>? _donoTransferido;`
- No `initState` (ao lado de `_membroEntrou = _papelRepo?.membroEntrou;`): `_donoTransferido = _papelRepo?.donoTransferido; _donoTransferido?.addListener(_aoVirarDono);`
- No `dispose`: `_donoTransferido?.removeListener(_aoVirarDono);`
- Método:

```dart
  void _aoVirarDono() {
    if (!mounted || _donoTransferido?.value == null) return;
    _papelRepo?.consumirDono();
    mostrarSnackBar(context, AppStrings.voceAgoraDono);
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/papel_repository_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/convites/data/papel_repository.dart lib/features/convites/data/papel_realtime.dart lib/features/listas/ui/tela_lista_screen.dart test/features/convites/papel_repository_test.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F24-T04: aviso ao novo dono pelo realtime (RF-14)"
```

---

### Task 5: Docs donos e fechamento da Fase 24

**Files:**
- Modify: `docs/01-banco-de-dados.md` (§6 trigger v3; §4.4 cascata R-17)
- Modify: `docs/02-seguranca-rls.md` (RPC `transferir_dono`; matriz/§5)
- Modify: `docs/08-compartilhamento-colaborativo.md` (§6 fluxo final)
- Modify: `docs/05-app-flutter.md` (§6.3/§6 membros — "Transferir dono")
- Modify: `docs/10-wireframes-telas.md` (menu/confirmação na tela de membros)
- Modify: `docs/06-mvp-entregas.md` (§3.3.1 — R-17 resolvido)
- Modify: `docs/12-prd.md` (RF-14 aceite/rastreabilidade)
- Modify: `docs/14-tarefas.md` (Fase 24 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (B1 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–4.
- Produces: nada consumido por código.

- [ ] **Step 1: Doc 01 e 02 (schema/RLS)**

- `docs/01-banco-de-dados.md` §6: na descrição do `sync_dono`, acrescentar que a exceção do downgrade também reconhece `app.transferindo_dono` (RPC `transferir_dono`, migration `0016`), e citar o RPC como processo explícito de transferência. §4.4 (`convites`): trocar a nota de R-17 por "resolvido na migration `0016` (`on delete cascade`)".
- `docs/02-seguranca-rls.md`: adicionar §4.6 com o SQL do RPC `transferir_dono` (copiar da migration) e a nota de que é `security definer` com `set_config` (clientes não forjam a flag); atualizar a matriz §3 se necessário (nenhuma policy nova) e citar o script `transferir_dono_tests.sql` em §5.

- [ ] **Step 2: Doc 08 §6 (fluxo final)**

Reescrever §6 para o fluxo entregue: RPC `transferir_dono` (só dono; destino membro; demove→promove; `dono_id` pelo trigger), UX (menu na tela de membros + confirmação dupla), aviso Realtime ao novo dono, e o ex-dono vira editor e pode sair. Remover a nota "Alteração necessária no trigger" (feita) e a marca de "adiada".

- [ ] **Step 3: Docs 05 e 10 (UI/layout)**

- `docs/05-app-flutter.md` §6 (membros): bullet "Transferir dono (RF-14, F24)" — item no menu só para dono e alvo ≠ eu; confirmação dupla; sucesso atualiza o papel local (vira editor) e mostra SnackBar; aviso genérico ao novo dono pelo Realtime.
- `docs/10-wireframes-telas.md` §4 (membros): acrescentar o item "Transferir dono" ao menu do membro e um box da confirmação dupla.

- [ ] **Step 4: Doc 06 §3.3.1 (cascatas/R-17)**

Na lista de cascatas de `excluir_conta`, incluir `convites` por `criado_por` (cascade, migration `0016`) e remover a observação de risco (R-17 resolvido).

- [ ] **Step 5: Doc 12 (RF-14) e 16 (roadmap)**

- `docs/12-prd.md`: atualizar a linha de aceite do RF-14 para refletir "transferência entregue" e ajustar a rastreabilidade (F24; F24-T01…T04).
- `docs/16-roadmap-pos-mvp.md`: linha B1 → `concluído (F24-T01…T05)`.

- [ ] **Step 6: Doc 14 (Fase 24 + progresso)**

Logo antes de `## Progresso por fase`, adicionar a Fase 24 com F24-T01…T05 todas `[x]` e seus CPs (resumidos das tarefas acima). Na tabela de progresso, após a linha `| F23 Duplicar lista | 3 | 3 |`, adicionar `| F24 Transferência de dono | 5 | 5 |` e atualizar o total para `| **Total** | **143** | **141** |`.

- [ ] **Step 7: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde (docs não afetam a suíte).

```bash
git add docs/01-banco-de-dados.md docs/02-seguranca-rls.md docs/08-compartilhamento-colaborativo.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/06-mvp-entregas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F24-T05: docs donos e fechamento da Fase 24 (RF-14)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 banco (RPC, trigger v3, R-17) → Task 1; §4.1 repositório → Task 2; §4.2 tela de membros → Task 3; §4.3 Realtime → Task 4; §4.4 strings → Task 2; §5 testes → Tasks 1–4; §6 decisões → refletidas; docs → Task 5.
- **Placeholders:** os Steps de UI (Task 3 e Task 4) apontam para o harness existente do arquivo de teste em vez de repetir código que só o arquivo conhece — o implementador lê o arquivo; todo o código novo de produção está completo. Nenhum "TBD".
- **Consistência de tipos:** `transferir_dono(p_lista, p_novo_dono)`; `transferirDono({listaId, novoDonoId})`; `ErroConvite.fromCodigoTransferencia`; `donoTransferido`/`notificarDono`/`consumirDono`; `voceAgoraDono`; progresso 143/141 — idênticos entre tarefas.
