# Notificações push de convite e entrada (RF-30) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notificar por push (Android) quando o usuário recebe um convite por e-mail ou quando alguém entra numa lista sua, com permissão contextual, toggle em Configurações e deep link no toque.

**Architecture:** O banco dispara o envio (triggers `pg_net` → Edge Function `enviar-push` → FCM HTTP v1); o app só registra o token do dispositivo (`push_tokens`, RLS por `auth.uid()`) e reage à notificação. Sem fila/Drift: token e notificação são device-only e online.

**Tech Stack:** Postgres 17 + RLS + pg_net + Vault (Supabase local/produção) · Deno 2 (Edge Function, `jose` para OAuth2) · Flutter 3.44.5 / Dart 3.12 · `firebase_core` + `firebase_messaging` · FCM HTTP v1 (projeto Firebase `lista-compras-34f93`).

**Spec:** [`docs/superpowers/specs/2026-09-23-notificacoes-push-design.md`](../specs/2026-09-23-notificacoes-push-design.md)

## Global Constraints

- **Requisito:** RF-30 (novo no [12](../../12-prd.md)). **Fase:** 38 ([14](../../14-tarefas.md)). **ADR-014** ([00 §5](../../00-visao-geral.md)).
- **Plataformas:** **Android agora**; iOS entra depois reusando a abstração; **Web/Desktop = sem push** (Web é local, ADR-013).
- **Escopo de eventos:** apenas `convite_email_criado` e `membro_entrou`.
- **Nenhum segredo** em código, commit ou log (service account do FCM e segredo do webhook ficam em secrets/Vault).
- **RLS é sagrado:** `push_tokens` só acessível com `user_id = auth.uid()`; a Edge Function usa `service_role` só para resolver tokens.
- **Offline-first:** nada de push entra no Drift/fila; falha de rede no registro de token é silenciosa (best-effort).
- **Migrations:** `0021_push_tokens.sql` e `0022_notificar_push.sql`; nunca SQL direto no dashboard.
- **Convenções:** pt-BR; sem comentários salvo indispensável; testes `deve_<resultado>_quando_<condicao>`; CI verde ([07 §3](../../07-qualidade-ci.md)).
- **Versão do app:** bump para `1.5.0+9` no fechamento (Task 9).
- **Payload `data` do FCM (contrato):** `{tipo: 'convite'|'membro', lista_id, token?, titulo, corpo}`.

---

### Task 1: Planejamento — RF-30, ADR-014, Fase 38 e docs de roadmap

**Files:**
- Modify: `docs/12-prd.md` (tabela §2, rastreabilidade §6, fora de escopo §7)
- Modify: `docs/00-visao-geral.md` (§5 ADRs)
- Modify: `docs/14-tarefas.md` (Fase 38 + tabela de progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (Onda B, B3)
- Modify: `docs/08-compartilhamento-colaborativo.md` (§7: remover "Sem push notifications")

**Interfaces:**
- Consumes: nada (docs).
- Produces: RF-30, ADR-014 e Fase 38 referenciados pelas demais tarefas.

- [ ] **Step 1: RF-30 no doc 12 §2**

Na tabela de requisitos funcionais (após a linha do RF-29), adicionar:

```markdown
| RF-30 | Notificação push (Android) de convite por e-mail recebido e de novo membro numa lista sua | 08 §7 + 01 §4.5 + 09 §2 | F38 | [08 §7](08-compartilhamento-colaborativo.md) |
```

- [ ] **Step 2: Rastreabilidade no doc 12 §6**

Após a linha do RF-29:

```markdown
| RF-30 | US-01, US-03 | F38 | F38-T05, F38-T08 | Unit fake/roteamento + Deno/SQL + widgets |
```

- [ ] **Step 3: Fora de escopo no doc 12 §7**

Remover "push notifications" da lista de fora de escopo (linha que hoje diz "histórico de compras, cupons, push notifications, scan de código de barras...") — o push passa a ser RF-30. Manter o restante.

- [ ] **Step 4: ADR-014 no doc 00 §5**

Após a linha do ADR-013:

```markdown
| ADR-014 | 23/09/2026 | **Notificações push via FCM (Android-first).** Disparo server-side por trigger + `pg_net` → Edge Function `enviar-push` → FCM HTTP v1, reusando o projeto Firebase `lista-compras-34f93`; token por dispositivo em `push_tokens` (RLS). | Web Push; OneSignal/terceiros; envio pelo cliente; webhooks do dashboard (não versionados) | Firebase já é usado no App Distribution; FCM é o caminho nativo do Android; iOS entra depois reusando a abstração | 
```

- [ ] **Step 5: Fase 38 no doc 14**

Ao final das fases (antes de "## Progresso por fase"), adicionar o bloco da Fase 38 com as 9 tarefas (T01…T09) espelhando este plano (IDs, Dep, Docs, CP). Adicionar a linha na tabela de progresso:

```markdown
| F38 Notificações push | 9 | 0 |
```

- [ ] **Step 6: B3 no doc 16**

Na Onda B, trocar a linha do B3 por:

```markdown
| B3 | Notificações push (convite/entrada) | RF-30 | 08, 09 | Médio | G | em execução (F38) — convite por e-mail + novo membro; Android agora, iOS depois |
```

- [ ] **Step 7: Nota no doc 08 §7**

Substituir a linha "Sem push notifications no MVP da feature (Fase 6); painel de convites pendentes cobre a descoberta." por:

```markdown
* **Push notifications (RF-30, F38):** os eventos `convite_email_criado` e `membro_entrou` disparam notificação push (Android) via Edge Function `enviar-push` (detalhes em §11). O painel de convites pendentes continua sendo o caminho in-app.
```

(§11 será criado na Task 9.)

- [ ] **Step 8: Commit**

```bash
git add docs/12-prd.md docs/00-visao-geral.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md docs/08-compartilhamento-colaborativo.md
git commit -m "F38-T01: RF-30, ADR-014 e Fase 38 no planejamento (RF-30)"
```

---

### Task 2: Banco — tabela `push_tokens` + RLS + testes SQL

**Files:**
- Create: `supabase/migrations/0021_push_tokens.sql`
- Create: `supabase/tests/push_tokens_tests.sql`
- Modify: `.github/workflows/ci.yml` (step do teste)
- Modify: `docs/01-banco-de-dados.md` (§4.5 novo)
- Modify: `docs/02-seguranca-rls.md` (§3 matriz, §4.5 policies, §5 N-18…N-20)

**Interfaces:**
- Consumes: nada.
- Produces: tabela `public.push_tokens (id, user_id, token, plataforma, atualizado_em, created_at)` com RLS por `auth.uid()`; testes N-18…N-20.

- [ ] **Step 1: Escrever a migration**

`supabase/migrations/0021_push_tokens.sql`:

```sql
-- 0021_push_tokens.sql — tokens de push por dispositivo (doc 01 §4.5, RF-30,
-- F38). Device-only: sem fila/Drift; o app faz upsert pelo `token` (unique) e
-- a Edge Function `enviar-push` lê com service_role.

create table public.push_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  token         text not null unique,
  plataforma    text not null default 'android'
                  check (plataforma in ('android', 'ios')),
  atualizado_em timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index idx_push_tokens_user on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
alter table public.push_tokens force row level security;

create policy push_tokens_select on public.push_tokens
  for select using (user_id = auth.uid());

create policy push_tokens_insert on public.push_tokens
  for insert with check (user_id = auth.uid());

create policy push_tokens_update on public.push_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy push_tokens_delete on public.push_tokens
  for delete using (user_id = auth.uid());
```

- [ ] **Step 2: Rodar `db reset` e conferir**

Run: `supabase db reset`
Expected: aplica `0021` sem erro; `\d public.push_tokens` mostra a tabela e os 4 policies.

- [ ] **Step 3: Escrever o teste SQL (N-18…N-20 + positivos)**

`supabase/tests/push_tokens_tests.sql`:

```sql
-- ============================================================================
-- push_tokens_tests.sql — RLS de tokens de push (doc 02 §5, RF-30, F38)
-- Casos:
--   N-18: A não lê token de B.
--   N-19: A não insere token para B (with check).
--   N-20: A não apaga token de B.
--   P-06: A lê/insere/apaga o próprio; upsert reatribui o token a outro dono.
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('c0000000-0000-0000-0000-000000000000', 'a@push.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('c1000000-0000-0000-0000-000000000000', 'b@push.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.push_tokens (user_id, token, plataforma)
values ('c1000000-0000-0000-0000-000000000000', 'token-do-b', 'android');

-- ===== N-18: A não lê o token de B =====
do $$
declare v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*) into v_qtd from public.push_tokens where token = 'token-do-b';
  perform set_config('role', 'postgres', true);
  if v_qtd <> 0 then raise exception 'FALHOU N-18: A viu % tokens de B', v_qtd; end if;
  raise notice 'OK N-18: A nao le o token de B';
end $$;

-- ===== N-19: A não insere token para B =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    insert into public.push_tokens (user_id, token) values ('c1000000-0000-0000-0000-000000000000', 'token-falso');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU N-19: A inseriu token para B';
  exception when insufficient_privilege then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    raise notice 'OK N-19: with check barrou token para B (%)', v_msg;
  end;
end $$;

-- ===== N-20: A não apaga o token de B =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  delete from public.push_tokens where token = 'token-do-b';
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.push_tokens where token = 'token-do-b') <> 1 then
    raise exception 'FALHOU N-20: A apagou o token de B';
  end if;
  raise notice 'OK N-20: A nao apaga o token de B';
end $$;

-- ===== P-06: A gerencia o próprio; upsert reatribui o token =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  insert into public.push_tokens (user_id, token) values ('c0000000-0000-0000-0000-000000000000', 'token-do-a');
  if (select count(*) from public.push_tokens) <> 1 then
    raise exception 'FALHOU P-06: A nao ve apenas o proprio token';
  end if;
  delete from public.push_tokens where token = 'token-do-a';
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.push_tokens where token = 'token-do-a') then
    raise exception 'FALHOU P-06: A nao apagou o proprio token';
  end if;
  raise notice 'OK P-06: A gerencia o proprio token';
end $$;

rollback;
```

- [ ] **Step 4: Rodar o teste**

Run: `psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/push_tokens_tests.sql`
Expected: 4 `NOTICE ... OK` e nenhum erro.

- [ ] **Step 5: CI — adicionar o step**

Em `.github/workflows/ci.yml`, no job `supabase`, após o step "Testes de convite por e-mail (08 §4)":

```yaml
      - name: Testes de tokens de push (02 §5)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/push_tokens_tests.sql
```

- [ ] **Step 6: Doc 01 §4.5**

Após `### 4.4. convites (Fase 6)`:

```markdown
### 4.5. `push_tokens` (RF-30, F38)

| Coluna | Tipo | Regra |
| :--- | :--- | :--- |
| `id` | `uuid` | PK, `gen_random_uuid()` |
| `user_id` | `uuid` | FK `auth.users(id)` `on delete cascade` (RF-11) |
| `token` | `text` | **unique** — upsert por token; o mesmo aparelho reatribui o token ao novo usuário |
| `plataforma` | `text` | `check (plataforma in ('android','ios'))`, default `android` |
| `atualizado_em` | `timestamptz` | atualizado pelo app no upsert |
| `created_at` | `timestamptz` | `now()` |

Índice `idx_push_tokens_user (user_id)`. Device-only: **não** entra no Realtime nem no sync.
```

- [ ] **Step 7: Doc 02 §3/§4.5/§5**

- §3 (matriz): linha `push_tokens` com SELECT/INSERT/UPDATE/DELETE = "dono da linha (`user_id = auth.uid()`)".
- §4.5 (SQL das policies): colar as 4 policies da migration.
- §5: adicionar N-18, N-19, N-20 (negações) e P-06 (positivo), com a descrição de uma linha cada.

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/0021_push_tokens.sql supabase/tests/push_tokens_tests.sql .github/workflows/ci.yml docs/01-banco-de-dados.md docs/02-seguranca-rls.md
git commit -m "F38-T02: push_tokens, RLS e testes SQL (RF-30)"
```

---

### Task 3: Banco — triggers `pg_net` de notificação

**Files:**
- Create: `supabase/migrations/0022_notificar_push.sql`
- Create: `supabase/tests/notificar_push_tests.sql`
- Modify: `.github/workflows/ci.yml` (step do teste)
- Modify: `docs/01-banco-de-dados.md` (§7 Realtime/notificações)

**Interfaces:**
- Consumes: tabelas `convites`, `lista_membros`, `listas` (existentes).
- Produces: função `public.notificar_push()` e triggers `trg_convites_push`/`trg_membros_push`; corpo do webhook `{evento, destinatario_id, lista_id, token?, titulo_lista}`.

- [ ] **Step 1: Escrever a migration**

`supabase/migrations/0022_notificar_push.sql`:

```sql
-- 0022_notificar_push.sql — dispara a Edge Function `enviar-push` (doc 08 §7,
-- RF-30, F38). URL e segredo vêm do Vault (nunca hardcoded); sem eles, a
-- função é no-op (dev/teste). Destinatário resolvido aqui, para a função não
-- precisar de auth.users.

create extension if not exists pg_net;

create or replace function public.notificar_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_segredo text;
  v_dest uuid;
  v_titulo text;
  v_corpo jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_function_url';
  select decrypted_secret into v_segredo
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_url is null or v_segredo is null then
    return new;
  end if;

  if tg_argv[0] = 'convite_email_criado' then
    select id into v_dest from auth.users
    where lower(email) = lower(new.email) limit 1;
    if v_dest is null or v_dest = new.criado_por then
      return new;
    end if;
    select titulo into v_titulo from public.listas where id = new.lista_id;
    v_corpo := jsonb_build_object(
      'evento', 'convite_email_criado',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'token', new.token,
      'titulo_lista', v_titulo
    );
  else
    select dono_id, titulo into v_dest, v_titulo
    from public.listas where id = new.lista_id;
    if v_dest is null or v_dest = new.user_id then
      return new;
    end if;
    v_corpo := jsonb_build_object(
      'evento', 'membro_entrou',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'titulo_lista', v_titulo
    );
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_segredo
    ),
    body := v_corpo
  );
  return new;
end;
$$;

create trigger trg_convites_push
  after insert on public.convites
  for each row
  when (new.tipo = 'email' and new.estado = 'pendente')
  execute function public.notificar_push('convite_email_criado');

create trigger trg_membros_push
  after insert on public.lista_membros
  for each row
  when (new.papel <> 'dono')
  execute function public.notificar_push('membro_entrou');
```

- [ ] **Step 2: `db reset` e conferir**

Run: `supabase db reset`
Expected: aplica `0022` sem erro; `\df public.notificar_push` e `\d public.convites` mostram a função/trigger.

- [ ] **Step 3: Escrever o teste SQL**

`supabase/tests/notificar_push_tests.sql`:

```sql
-- ============================================================================
-- notificar_push_tests.sql — triggers de push (doc 01 §7, RF-30, F38)
-- Casos:
--   NP-01: INSERT de convite 'email' pendente enfileira 1 request no pg_net.
--   NP-02: INSERT de convite 'link' NÃO enfileira.
--   NP-03: INSERT de membro com papel <> dono enfileira 1 request.
--   NP-04: INSERT da linha do dono (papel = dono) NÃO enfileira.
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

select vault.create_secret('http://127.0.0.1:54321/functions/v1/enviar-push', 'push_function_url', 'teste');
select vault.create_secret('segredo-teste', 'push_webhook_secret', 'teste');

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('d0000000-0000-0000-0000-000000000000', 'dono@np.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d1000000-0000-0000-0000-000000000000', 'novo@np.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('d9000000-0000-0000-0000-000000000000', 'Lista NP', 'd0000000-0000-0000-0000-000000000000');

-- ===== NP-01: convite email pendente enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.convites (lista_id, criado_por, tipo, email, papel_oferecido)
  values ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'email', 'novo@np.test', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois - v_antes <> 1 then
    raise exception 'FALHOU NP-01: enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-01: convite email enfileira 1 request';
end $$;

-- ===== NP-02: convite link não enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.convites (lista_id, criado_por, tipo, papel_oferecido)
  values ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'link', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois <> v_antes then
    raise exception 'FALHOU NP-02: link enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-02: convite link nao enfileira';
end $$;

-- ===== NP-03: membro (papel <> dono) enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois - v_antes <> 1 then
    raise exception 'FALHOU NP-03: enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-03: membro enfileira 1 request';
end $$;

-- ===== NP-04: linha do dono não enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'dono');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois <> v_antes then
    raise exception 'FALHOU NP-04: dono enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-04: linha do dono nao enfileira';
end $$;

rollback;
```

- [ ] **Step 4: Rodar o teste**

Run: `psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/notificar_push_tests.sql`
Expected: 4 `NOTICE ... OK`; nenhum erro. (Se `vault.create_secret` não existir no stack local, verificar a versão do CLI — `supabase start` recente inclui o Vault.)

- [ ] **Step 5: CI — adicionar o step**

Após o step da Task 2:

```yaml
      - name: Testes de notificação push (01 §7)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/notificar_push_tests.sql
```

- [ ] **Step 6: Doc 01 §7**

Na seção §7 (Realtime), adicionar um sub-bloco "Notificações push (RF-30)":

```markdown
### Notificações push (RF-30, F38)

`convites` (INSERT `tipo='email'`, `estado='pendente'`) e `lista_membros` (INSERT `papel <> 'dono'`) disparam `public.notificar_push()`, que faz `net.http_post` para a Edge Function `enviar-push` com `{evento, destinatario_id, lista_id, token?, titulo_lista}`. URL e segredo vêm do Vault (`push_function_url`, `push_webhook_secret`); ausentes → no-op. O destinatário é resolvido no trigger (convite: `auth.users` pelo e-mail; entrada: `listas.dono_id`).
```

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0022_notificar_push.sql supabase/tests/notificar_push_tests.sql .github/workflows/ci.yml docs/01-banco-de-dados.md
git commit -m "F38-T03: triggers pg_net de notificacao push (RF-30)"
```

---

### Task 4: Edge Function `enviar-push` + testes Deno + CI

**Files:**
- Create: `supabase/functions/enviar-push/mensagem.ts`
- Create: `supabase/functions/enviar-push/fcm.ts`
- Create: `supabase/functions/enviar-push/index.ts`
- Create: `supabase/functions/enviar-push/mensagem_test.ts`
- Create: `supabase/functions/enviar-push/fcm_test.ts`
- Modify: `.github/workflows/ci.yml` (job `supabase`: setup-deno + `deno test`)
- Modify: `docs/07-qualidade-ci.md` (§3 esqueleto + §2 o que é testado)

**Interfaces:**
- Consumes: corpo do webhook `{evento, destinatario_id, lista_id, token?, titulo_lista}` (Task 3); tabela `push_tokens` (Task 2).
- Produces: função `montarMensagem(evento, tituloLista) -> {titulo, corpo} | null`; `tipoDoEvento(evento) -> 'convite'|'membro'|null`; `enviarFcm(accessToken, projetoId, tokens, mensagem, data, fetchFn) -> Promise<string[]>` (tokens inválidos); `obterAccessToken(serviceAccount, fetchFn) -> Promise<string>`.

- [ ] **Step 1: Escrever `mensagem.ts`**

```ts
export type Tipo = "convite" | "membro";

export function tipoDoEvento(evento: string): Tipo | null {
  if (evento === "convite_email_criado") return "convite";
  if (evento === "membro_entrou") return "membro";
  return null;
}

export function montarMensagem(
  evento: string,
  tituloLista: string,
): { titulo: string; corpo: string } | null {
  const tipo = tipoDoEvento(evento);
  if (tipo === "convite") {
    return {
      titulo: "Convite para lista",
      corpo: `Você recebeu um convite para "${tituloLista}".`,
    };
  }
  if (tipo === "membro") {
    return {
      titulo: "Novo membro",
      corpo: `Um novo membro entrou em "${tituloLista}".`,
    };
  }
  return null;
}
```

- [ ] **Step 2: Escrever `mensagem_test.ts`**

```ts
import { assertEquals } from "jsr:@std/assert@1";
import { montarMensagem, tipoDoEvento } from "./mensagem.ts";

Deno.test("deve_mapear_convite_quando_evento_email", () => {
  assertEquals(tipoDoEvento("convite_email_criado"), "convite");
});

Deno.test("deve_mapear_membro_quando_evento_entrou", () => {
  assertEquals(tipoDoEvento("membro_entrou"), "membro");
});

Deno.test("deve_devolver_null_quando_evento_desconhecido", () => {
  assertEquals(tipoDoEvento("outro"), null);
  assertEquals(montarMensagem("outro", "X"), null);
});

Deno.test("deve_montar_corpo_com_titulo_da_lista", () => {
  assertEquals(montarMensagem("convite_email_criado", "Compras"), {
    titulo: "Convite para lista",
    corpo: 'Você recebeu um convite para "Compras".',
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run (em `supabase/functions/enviar-push`): `deno test mensagem_test.ts`
Expected: FAIL (arquivo `mensagem.ts` ainda não existe — crie antes; se já criou no Step 1, o teste passa). Para TDD, crie o teste antes do módulo.

- [ ] **Step 4: Escrever `fcm.ts`**

```ts
export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

export async function obterAccessToken(
  conta: ServiceAccount,
  fetchFn: typeof fetch = fetch,
): Promise<string> {
  const { importPKCS8, SignJWT } = await import("https://deno.land/x/jose@v5.9.6/mod.ts");
  const chave = await importPKCS8(conta.private_key, "RS256");
  const agora = Math.floor(Date.now() / 1000);
  const tokenUri = conta.token_uri ?? "https://oauth2.googleapis.com/token";
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(conta.client_email)
    .setAudience(tokenUri)
    .setIssuedAt(agora)
    .setExpirationTime(agora + 3600)
    .sign(chave);
  const resp = await fetchFn(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await resp.json();
  return json.access_token as string;
}

export async function enviarFcm(
  accessToken: string,
  projetoId: string,
  tokens: string[],
  mensagem: { titulo: string; corpo: string },
  data: Record<string, string>,
  fetchFn: typeof fetch = fetch,
): Promise<string[]> {
  const invalidos: string[] = [];
  for (const token of tokens) {
    const resp = await fetchFn(
      `https://fcm.googleapis.com/v1/projects/${projetoId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: mensagem.titulo, body: mensagem.corpo },
            data,
          },
        }),
      },
    );
    if (!resp.ok) {
      const corpo = await resp.text();
      if (
        resp.status === 404 || corpo.includes("UNREGISTERED") ||
        corpo.includes("INVALID_ARGUMENT")
      ) {
        invalidos.push(token);
      }
    }
  }
  return invalidos;
}
```

- [ ] **Step 5: Escrever `fcm_test.ts`**

```ts
import { assertEquals } from "jsr:@std/assert@1";
import { enviarFcm } from "./fcm.ts";

function respOk() {
  return new Response(JSON.stringify({ name: "ok" }), { status: 200 });
}
function respErro(status: number, corpo: string) {
  return new Response(corpo, { status });
}

Deno.test("deve_enviar_para_todos_quando_tokens_validos", async () => {
  let chamadas = 0;
  const fake: typeof fetch = () => {
    chamadas++;
    return Promise.resolve(respOk());
  };
  const invalidos = await enviarFcm("tk", "proj", ["a", "b"], {
    titulo: "T",
    corpo: "C",
  }, { tipo: "membro" }, fake);
  assertEquals(chamadas, 2);
  assertEquals(invalidos, []);
});

Deno.test("deve_devolver_invalidos_quando_unregistered", async () => {
  const fake: typeof fetch = (_url, init) => {
    const body = JSON.parse((init?.body as string) ?? "{}");
    const token = body.message.token;
    return Promise.resolve(
      token === "morto"
        ? respErro(404, '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}')
        : respOk(),
    );
  };
  const invalidos = await enviarFcm("tk", "proj", ["vivo", "morto"], {
    titulo: "T",
    corpo: "C",
  }, { tipo: "membro" }, fake);
  assertEquals(invalidos, ["morto"]);
});
```

- [ ] **Step 6: Escrever `index.ts`**

```ts
import { createClient } from "jsr:@supabase/supabase-js@2";
import { montarMensagem, tipoDoEvento } from "./mensagem.ts";
import { enviarFcm, obterAccessToken, type ServiceAccount } from "./fcm.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function json(status: number, corpo: unknown): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: JSON_HEADERS,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { code: "method_not_allowed" });

  const segredo = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (segredo && req.headers.get("x-webhook-secret") !== segredo) {
    return json(401, { code: "unauthorized" });
  }

  const corpo = await req.json().catch(() => null) as
    | {
      evento?: string;
      destinatario_id?: string;
      lista_id?: string;
      token?: string;
      titulo_lista?: string;
    }
    | null;
  if (!corpo?.evento || !corpo?.destinatario_id || !corpo?.lista_id) {
    return json(400, { code: "bad_request" });
  }

  const tipo = tipoDoEvento(corpo.evento);
  const mensagem = montarMensagem(corpo.evento, corpo.titulo_lista ?? "uma lista");
  if (!tipo || !mensagem) return json(200, { ok: true, ignorado: "evento_desconhecido" });

  const contaBruta = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!contaBruta) return json(200, { ok: true, ignorado: "sem_fcm" });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: linhas } = await admin
    .from("push_tokens")
    .select("token")
    .eq("user_id", corpo.destinatario_id);
  const tokens = (linhas ?? []).map((l) => l.token as string);
  if (tokens.length === 0) return json(200, { ok: true, ignorado: "sem_token" });

  const conta = JSON.parse(contaBruta) as ServiceAccount;
  const accessToken = await obterAccessToken(conta);
  const data: Record<string, string> = {
    tipo,
    lista_id: String(corpo.lista_id),
  };
  if (corpo.token) data.token = String(corpo.token);

  const invalidos = await enviarFcm(
    accessToken,
    conta.project_id,
    tokens,
    mensagem,
    data,
  );
  if (invalidos.length > 0) {
    await admin.from("push_tokens").delete().in("token", invalidos);
  }
  return json(200, { ok: true, enviados: tokens.length - invalidos.length });
});
```

- [ ] **Step 7: Rodar os testes Deno**

Run (em `supabase/functions/enviar-push`): `deno test --allow-env`
Expected: PASS (6 testes: 4 de mensagem + 2 de fcm).

- [ ] **Step 8: CI — setup-deno + deno test**

Em `.github/workflows/ci.yml`, no job `supabase`, após o step "Testes de notificação push (01 §7)":

```yaml
      - uses: denoland/setup-deno@v2
        with:
          deno-version: v2.x
      - name: Testes da Edge Function enviar-push (07 §1)
        working-directory: supabase/functions/enviar-push
        run: deno test --allow-env
```

- [ ] **Step 9: Doc 07 §1/§2/§3**

- §1 (pirâmide): linha "Edge Function `enviar-push` (Deno) — `mensagem.ts`/`fcm.ts` com `fetch` fake; sem FCM real".
- §2: registrar que o envio real ao FCM é smoke manual (device), não CI.
- §3 (esqueleto): refletir os 2 steps novos (teste SQL + deno test).

- [ ] **Step 10: Commit**

```bash
git add supabase/functions/enviar-push .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F38-T04: Edge Function enviar-push e testes Deno no CI (RF-30)"
```

---

### Task 5: App — dependências, init do Firebase e abstração `NotificacoesPush`

**Files:**
- Modify: `pubspec.yaml` (`firebase_core`, `firebase_messaging`)
- Modify: `android/settings.gradle.kts` (plugin google-services)
- Modify: `android/app/build.gradle.kts` (aplicar plugin)
- Modify: `lib/main.dart` (init do Firebase)
- Create: `lib/features/notificacoes/domain/notificacoes_push.dart`
- Create: `lib/features/notificacoes/data/notificacoes_push_firebase.dart`
- Create: `lib/features/notificacoes/providers/notificacoes_providers.dart`
- Create: `test/features/notificacoes/fake_notificacoes_push.dart`
- Create: `test/features/notificacoes/notificacoes_push_provider_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `enum PermissaoPush { concedida, negada, indisponivel }`; `abstract interface class NotificacoesPush { bool suportado; Future<PermissaoPush> pedirPermissao(); Future<String?> obterToken(); Future<void> apagarToken(); Stream<String> onTokenRefresh; Stream<Map<String,Object?>> onToque; Future<Map<String,Object?>?> toqueInicial(); Stream<Map<String,Object?>> onRecebida; }`; `bool plataformaComPush()`; `notificacoesPushProvider`; `NotificacoesPushFake`.

- [ ] **Step 1: Adicionar dependências**

Em `pubspec.yaml` (bloco `dependencies:`), após `speech_to_text`:

```yaml
  firebase_core: ^4.1.0
  firebase_messaging: ^16.0.0
```

Run: `flutter pub get`
Expected: resolve sem conflito (se as versões não existirem, rodar `flutter pub add firebase_core firebase_messaging` e usar as resolvidas).

- [ ] **Step 2: Plugin Gradle do google-services**

`android/settings.gradle.kts`, no bloco `plugins`:

```kotlin
    id("com.google.gms.google-services") version "4.4.3" apply false
```

`android/app/build.gradle.kts`, no bloco `plugins`:

```kotlin
    id("com.google.gms.google-services")
```

- [ ] **Step 3: Init do Firebase no `main.dart`**

Adicionar o import e a inicialização (Android apenas; Web/Desktop não inicializam):

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
```

Dentro de `main()`, após `await Supabase.initialize(...)`:

```dart
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
```

(`defaultTargetPlatform` vem de `package:flutter/foundation.dart` — ajustar o import para incluir `defaultTargetPlatform`.)

- [ ] **Step 4: Escrever o domínio**

`lib/features/notificacoes/domain/notificacoes_push.dart`:

```dart
enum PermissaoPush { concedida, negada, indisponivel }

abstract interface class NotificacoesPush {
  bool get suportado;
  Future<PermissaoPush> pedirPermissao();
  Future<String?> obterToken();
  Future<void> apagarToken();
  Stream<String> get onTokenRefresh;
  Stream<Map<String, Object?>> get onToque;
  Future<Map<String, Object?>?> toqueInicial();
  Stream<Map<String, Object?>> get onRecebida;
}
```

- [ ] **Step 5: Escrever o fake e o teste do provider**

`test/features/notificacoes/fake_notificacoes_push.dart`:

```dart
import 'package:lista_compras/features/notificacoes/domain/notificacoes_push.dart';

class NotificacoesPushFake implements NotificacoesPush {
  NotificacoesPushFake({this.suportado = true, this.permissao = PermissaoPush.concedida});

  @override
  bool suportado;
  PermissaoPush permissao;
  String? token = 'token-fake';
  bool apagouToken = false;
  int pedidos = 0;

  final _refresh = <String>[];
  final _toque = <Map<String, Object?>>[];
  final _recebida = <Map<String, Object?>>[];
  Map<String, Object?>? inicial;

  @override
  Future<PermissaoPush> pedirPermissao() async {
    pedidos++;
    return permissao;
  }

  @override
  Future<String?> obterToken() async => token;

  @override
  Future<void> apagarToken() async {
    apagouToken = true;
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => Stream.fromIterable(_refresh);

  @override
  Stream<Map<String, Object?>> get onToque => Stream.fromIterable(_toque);

  @override
  Future<Map<String, Object?>?> toqueInicial() async => inicial;

  @override
  Stream<Map<String, Object?>> get onRecebida => Stream.fromIterable(_recebida);
}
```

`test/features/notificacoes/notificacoes_push_provider_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacoes_providers.dart';

void main() {
  test('deve_indicar_push_quando_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(plataformaComPush(), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  test('deve_negar_push_quando_web_ou_desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(plataformaComPush(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
```

- [ ] **Step 6: Escrever o plugin Firebase e o provider**

`lib/features/notificacoes/data/notificacoes_push_firebase.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/notificacoes_push.dart';

class NotificacoesPushFirebase implements NotificacoesPush {
  final _mensageria = FirebaseMessaging.instance;

  @override
  bool get suportado => true;

  @override
  Future<PermissaoPush> pedirPermissao() async {
    final ajustes = await _mensageria.requestPermission();
    return switch (ajustes.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PermissaoPush.concedida,
      AuthorizationStatus.notDetermined => PermissaoPush.indisponivel,
      _ => PermissaoPush.negada,
    };
  }

  @override
  Future<String?> obterToken() => _mensageria.getToken();

  @override
  Future<void> apagarToken() => _mensageria.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _mensageria.onTokenRefresh;

  @override
  Stream<Map<String, Object?>> get onToque =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, Object?>?> toqueInicial() async =>
      (await _mensageria.getInitialMessage())?.data;

  @override
  Stream<Map<String, Object?>> get onRecebida =>
      FirebaseMessaging.onMessage.map((m) => m.data);
}
```

`lib/features/notificacoes/providers/notificacoes_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notificacoes_push_firebase.dart';
import '../domain/notificacoes_push.dart';

/// Push só onde há suporte: Android hoje (iOS entra depois; Web/Desktop não).
bool plataformaComPush() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

final notificacoesPushProvider = Provider<NotificacoesPush>(
  (ref) => NotificacoesPushFirebase(),
);
```

- [ ] **Step 7: Rodar**

Run: `dart format . ; flutter analyze ; flutter test test/features/notificacoes`
Expected: sem issues; 2 testes verdes.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock android/settings.gradle.kts android/app/build.gradle.kts lib/main.dart lib/features/notificacoes test/features/notificacoes
git commit -m "F38-T05: FCM, abstracao NotificacoesPush e provider (RF-30)"
```

---

### Task 6: App — repositório de tokens, serviço e strings

**Files:**
- Create: `lib/features/notificacoes/data/push_tokens_repository.dart`
- Create: `lib/features/notificacoes/data/notificacoes_service.dart`
- Modify: `lib/features/notificacoes/providers/notificacoes_providers.dart` (repositório, serviço, `notificacoesAtivasProvider`)
- Modify: `lib/core/l10n/app_strings.dart` (strings de notificações)
- Create: `test/features/notificacoes/push_tokens_repository_test.dart`
- Create: `test/features/notificacoes/notificacoes_service_test.dart`

**Interfaces:**
- Consumes: `NotificacoesPush`/`PermissaoPush` (Task 5).
- Produces: `PushTokensRepository.registrar({token, plataforma})`/`remover(token)`; `NotificacoesService.ativas()`/`talvezPedirPermissao()`/`definirAtivas(bool)`/`registrarSeAtivo()`/`aoSair()`; `pushTokensRepositoryProvider`, `notificacoesServiceProvider`, `notificacoesAtivasProvider`.

- [ ] **Step 1: Escrever o repositório**

`lib/features/notificacoes/data/push_tokens_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokensRepository {
  PushTokensRepository(this._client);

  final SupabaseClient _client;

  Future<void> registrar({
    required String token,
    required String plataforma,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('push_tokens').upsert({
      'token': token,
      'user_id': userId,
      'plataforma': plataforma,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> remover(String token) async {
    await _client.from('push_tokens').delete().eq('token', token);
  }
}
```

- [ ] **Step 2: Escrever o serviço**

`lib/features/notificacoes/data/notificacoes_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notificacoes_push.dart';
import 'push_tokens_repository.dart';

class NotificacoesService {
  NotificacoesService({
    required NotificacoesPush push,
    required PushTokensRepository repositorio,
    required String plataforma,
  }) : _push = push,
       _repositorio = repositorio,
       _plataforma = plataforma;

  static const _chaveAtivas = 'push_ativas';
  static const _chavePedido = 'push_pedido';

  final NotificacoesPush _push;
  final PushTokensRepository _repositorio;
  final String _plataforma;

  Future<bool> ativas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chaveAtivas) ?? false;
  }

  /// Pede a permissão uma única vez, no primeiro momento relevante.
  Future<bool> talvezPedirPermissao() async {
    if (!_push.suportado) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_chavePedido) ?? false) return false;
    await prefs.setBool(_chavePedido, true);
    final permissao = await _push.pedirPermissao();
    if (permissao != PermissaoPush.concedida) return false;
    await prefs.setBool(_chaveAtivas, true);
    await _registrarToken();
    return true;
  }

  Future<void> definirAtivas(bool ativas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveAtivas, ativas);
    if (ativas) {
      final permissao = await _push.pedirPermissao();
      if (permissao == PermissaoPush.concedida) await _registrarToken();
    } else {
      final token = await _push.obterToken();
      if (token != null) await _removerToken(token);
      await _push.apagarToken();
    }
  }

  /// No start do app logado: reafirma o token do dispositivo (idempotente).
  Future<void> registrarSeAtivo() async {
    if (!_push.suportado) return;
    if (!await ativas()) return;
    await _registrarToken();
  }

  Future<void> aoSair() async {
    final token = await _push.obterToken();
    if (token != null) await _removerToken(token);
    await _push.apagarToken();
  }

  Future<void> _registrarToken() async {
    final token = await _push.obterToken();
    if (token == null) return;
    try {
      await _repositorio.registrar(token: token, plataforma: _plataforma);
    } on Exception {
      // Best-effort (offline): o próximo start/refresh reafirma.
    }
  }

  Future<void> _removerToken(String token) async {
    try {
      await _repositorio.remover(token);
    } on Exception {
      // Best-effort (offline).
    }
  }
}
```

- [ ] **Step 3: Escrever o teste do serviço**

`test/features/notificacoes/notificacoes_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/data/notificacoes_service.dart';
import 'package:lista_compras/features/notificacoes/domain/notificacoes_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_notificacoes_push.dart';
import 'repositorio_tokens_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deve_pedir_permissao_uma_vez_quando_chamado_duas_vezes', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    expect(await servico.talvezPedirPermissao(), isTrue);
    expect(await servico.talvezPedirPermissao(), isFalse);
    expect(push.pedidos, 1);
    expect(repo.registrados, ['token-fake']);
  });

  test('deve_registrar_token_quando_permissao_concedida', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    await servico.definirAtivas(true);
    expect(repo.registrados, ['token-fake']);
  });

  test('deve_remover_token_quando_desativado', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    await servico.definirAtivas(false);
    expect(repo.removidos, ['token-fake']);
    expect(push.apagouToken, isTrue);
  });

  test('deve_nao_pedir_quando_plataforma_sem_suporte', () async {
    final push = NotificacoesPushFake(suportado: false);
    final servico = NotificacoesService(
      push: push,
      repositorio: RepositorioTokensFake(),
      plataforma: 'android',
    );
    expect(await servico.talvezPedirPermissao(), isFalse);
    expect(push.pedidos, 0);
  });
}
```

`test/features/notificacoes/repositorio_tokens_fake.dart`:

```dart
import 'package:lista_compras/features/notificacoes/data/push_tokens_repository.dart';

class RepositorioTokensFake implements PushTokensRepository {
  final registrados = <String>[];
  final removidos = <String>[];

  @override
  Future<void> registrar({
    required String token,
    required String plataforma,
  }) async {
    registrados.add(token);
  }

  @override
  Future<void> remover(String token) async {
    removidos.add(token);
  }
}
```

(Se `implements PushTokensRepository` reclamar do construtor privado, usar `class RepositorioTokensFake implements PushTokensRepository` — a interface só expõe os dois métodos públicos; o `_client` não faz parte da interface.)

- [ ] **Step 4: Providers e strings**

Em `notificacoes_providers.dart`, adicionar:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notificacoes_service.dart';
import '../data/push_tokens_repository.dart';

final pushTokensRepositoryProvider = Provider<PushTokensRepository>(
  (ref) => PushTokensRepository(Supabase.instance.client),
);

final notificacoesServiceProvider = Provider<NotificacoesService>(
  (ref) => NotificacoesService(
    push: ref.watch(notificacoesPushProvider),
    repositorio: ref.watch(pushTokensRepositoryProvider),
    plataforma: 'android',
  ),
);

class NotificacoesAtivas extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(notificacoesServiceProvider).ativas();

  Future<void> definir(bool ativas) async {
    state = AsyncData(ativas);
    await ref.read(notificacoesServiceProvider).definirAtivas(ativas);
  }
}

final notificacoesAtivasProvider =
    AsyncNotifierProvider<NotificacoesAtivas, bool>(NotificacoesAtivas.new);
```

Em `app_strings.dart`, na seção Configurações:

```dart
  static const notificacoes = 'Notificações';
  static const notificacoesAjuda =
      'Avisar quando você receber um convite ou alguém entrar numa lista sua.';
```

- [ ] **Step 5: Rodar**

Run: `dart format . ; flutter analyze ; flutter test test/features/notificacoes`
Expected: 6 testes verdes (2 do provider + 4 do serviço).

- [ ] **Step 6: Commit**

```bash
git add lib/features/notificacoes lib/core/l10n/app_strings.dart test/features/notificacoes
git commit -m "F38-T06: repositorio de tokens, servico de notificacoes e strings (RF-30)"
```

---

### Task 7: App — toggle em Configurações e permissão contextual

**Files:**
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Modify: `lib/features/listas/ui/painel_listas.dart` (`abrirSheetNovaLista`)
- Modify: `lib/features/convites/ui/entrar_screen.dart` (`_processar`)
- Modify: `lib/features/convites/ui/convites_pendentes_secao.dart` (`_aceitar`)
- Modify: `lib/features/auth/data/supabase_auth_repository.dart` (hook de logout) — ver Step 4
- Modify: `lib/features/sync/providers/sync_providers.dart` (registro no start) — ver Step 5
- Create: `test/features/notificacoes/configuracoes_notificacoes_test.dart`

**Interfaces:**
- Consumes: `notificacoesAtivasProvider`, `notificacoesServiceProvider`, `plataformaComPush()` (Tasks 5–6).
- Produces: `SwitchListTile` "Notificações"; chamadas de `talvezPedirPermissao()` após criar lista/aceitar convite; `registrarSeAtivo()` no start; `aoSair()` no logout.

- [ ] **Step 1: Toggle em Configurações**

Em `configuracoes_screen.dart`, adicionar o import:

```dart
import '../../notificacoes/providers/notificacoes_providers.dart';
```

No `build`, antes de `const AppCabecalhoSecao(AppStrings.conta)`, inserir:

```dart
          if (plataformaComPush()) ...[
            const AppCabecalhoSecao(AppStrings.notificacoes),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text(AppStrings.notificacoes),
              subtitle: const Text(AppStrings.notificacoesAjuda),
              value: ref.watch(notificacoesAtivasProvider).value ?? false,
              onChanged: (valor) => ref
                  .read(notificacoesAtivasProvider.notifier)
                  .definir(valor),
            ),
          ],
```

- [ ] **Step 2: Permissão contextual — criar lista**

Em `painel_listas.dart`, `abrirSheetNovaLista` (após `ref.read(papelRepositoryProvider).atualizar(...)`), adicionar:

```dart
      await ref.read(notificacoesServiceProvider).talvezPedirPermissao();
```

(Importar `../../notificacoes/providers/notificacoes_providers.dart`.)

- [ ] **Step 3: Permissão contextual — aceitar convite (2 pontos)**

Em `entrar_screen.dart`, `_processar`, após `final listaId = await ...aceitar(token);`:

```dart
      await ref.read(notificacoesServiceProvider).talvezPedirPermissao();
```

Em `convites_pendentes_secao.dart`, `_aceitar`, após o `aceitar(convite.token)` bem-sucedido (mesmo ponto em que já há SnackBar de sucesso), adicionar a mesma chamada.

- [ ] **Step 4: Limpeza no logout**

Em `configuracoes_screen.dart`, `_confirmarSair`, antes de `authRepository.sair()`:

```dart
    await ref.read(notificacoesServiceProvider).aoSair();
```

- [ ] **Step 5: Registro no start**

Em `lib/features/sync/providers/sync_providers.dart`, no provider de bootstrap (onde o app liga o sync), encadear o registro best-effort após iniciar. Adicionar:

```dart
ref.listen(autenticadoProvider, (_, autenticado) {
  if (autenticado) {
    ref.read(notificacoesServiceProvider).registrarSeAtivo();
  }
});
```

(Ajustar o nome do provider de sessão se o arquivo usar outro; o alvo é rodar `registrarSeAtivo()` quando houver sessão, uma vez por transição para autenticado.)

- [ ] **Step 6: Widget test do toggle**

`test/features/notificacoes/configuracoes_notificacoes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacoes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_notificacoes_push.dart';
import 'repositorio_tokens_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('deve_mostrar_toggle_e_ativar_quando_tocado', (tester) async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
          notificacoesPushProvider.overrideWithValue(push),
          pushTokensRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repo.registrados, isNotEmpty);
  });
}
```

Run: `flutter test test/features/notificacoes/configuracoes_notificacoes_test.dart`
Expected: PASS (o toggle aparece e registra o token). O teste segue o padrão de `test/features/configuracoes/configuracoes_screen_test.dart` (override de `emailUsuarioProvider` para não tocar o Supabase real).

- [ ] **Step 7: Rodar tudo**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: verde.

- [ ] **Step 8: Commit**

```bash
git add lib/features test/features/notificacoes
git commit -m "F38-T07: toggle de notificacoes e permissao contextual (RF-30)"
```

---

### Task 8: App — deep link no toque e SnackBar em primeiro plano

**Files:**
- Create: `lib/features/notificacoes/domain/rota_notificacao.dart`
- Create: `lib/features/notificacoes/providers/push_navegacao.dart`
- Modify: `lib/main.dart` (ponte + `scaffoldMessengerKey`)
- Modify: `lib/features/notificacoes/providers/notificacoes_providers.dart` (streams)
- Create: `test/features/notificacoes/rota_notificacao_test.dart`

**Interfaces:**
- Consumes: `notificacoesPushProvider` (Task 5); `routerProvider` (`lib/router.dart`).
- Produces: `String? rotaDaNotificacao(Map<String, Object?> data)`; `pushNavegacaoProvider` (StreamSubscription); `notificacoesForegroundProvider` (StreamProvider do payload em primeiro plano).

- [ ] **Step 1: Teste da função pura**

`test/features/notificacoes/rota_notificacao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/domain/rota_notificacao.dart';

void main() {
  test('deve_abrir_entrar_quando_convite_com_token', () {
    expect(
      rotaDaNotificacao({'tipo': 'convite', 'token': 'abc'}),
      '/entrar?token=abc',
    );
  });

  test('deve_abrir_lista_quando_membro', () {
    expect(
      rotaDaNotificacao({'tipo': 'membro', 'lista_id': 'L1'}),
      '/lista/L1',
    );
  });

  test('deve_devolver_null_quando_dados_incompletos', () {
    expect(rotaDaNotificacao({'tipo': 'convite'}), isNull);
    expect(rotaDaNotificacao({'tipo': 'membro'}), isNull);
    expect(rotaDaNotificacao({'tipo': 'outro'}), isNull);
    expect(rotaDaNotificacao({}), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/notificacoes/rota_notificacao_test.dart`
Expected: FAIL (`rota_notificacao.dart` não existe).

- [ ] **Step 3: Implementar a função pura**

`lib/features/notificacoes/domain/rota_notificacao.dart`:

```dart
String? rotaDaNotificacao(Map<String, Object?> data) {
  final tipo = data['tipo'];
  if (tipo == 'convite') {
    final token = data['token'];
    if (token is String && token.isNotEmpty) {
      return '/entrar?token=${Uri.encodeComponent(token)}';
    }
    return null;
  }
  if (tipo == 'membro') {
    final listaId = data['lista_id'];
    if (listaId is String && listaId.isNotEmpty) return '/lista/$listaId';
  }
  return null;
}
```

Run: `flutter test test/features/notificacoes/rota_notificacao_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 4: Provider de navegação + stream de foreground**

`lib/features/notificacoes/providers/push_navegacao.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router.dart';
import '../domain/rota_notificacao.dart';
import 'notificacoes_providers.dart';

/// Ponte push → go_router (app aberto e cold start).
final pushNavegacaoProvider = Provider<StreamSubscription<Map<String, Object?>>?>(
  (ref) {
    final push = ref.watch(notificacoesPushProvider);
    final router = ref.watch<GoRouter>(routerProvider);
    void ir(Map<String, Object?> data) {
      final rota = rotaDaNotificacao(data);
      if (rota != null) router.go(rota);
    }

    push.toqueInicial().then((data) {
      if (data != null) ir(data);
    });
    final sub = push.onToque.listen(ir, onError: (_) {});
    ref.onDispose(sub.cancel);
    return sub;
  },
);

/// Notificação recebida em primeiro plano (payload) — o app mostra um SnackBar.
final notificacoesForegroundProvider = StreamProvider<Map<String, Object?>>(
  (ref) => ref.watch(notificacoesPushProvider).onRecebida,
);
```

- [ ] **Step 5: SnackBar em foreground no `main.dart`**

Adicionar um `GlobalKey<ScaffoldMessengerState>` e ligar os providers:

```dart
final _messengerKey = GlobalKey<ScaffoldMessengerState>();
```

Em `ListaComprasApp.build`:

```dart
    ref.listen(notificacoesForegroundProvider, (_, proximo) {
      final data = proximo.value;
      final corpo = data?['corpo'];
      if (corpo is String && corpo.isNotEmpty) {
        _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(corpo)));
      }
    });
```

E no `MaterialApp.router(...)`:

```dart
      scaffoldMessengerKey: _messengerKey,
```

No `app()` do `main()`, ligar a ponte:

```dart
    container.read(pushNavegacaoProvider);
```

(Importar `features/notificacoes/providers/push_navegacao.dart`.)

- [ ] **Step 6: Rodar**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: verde.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/features/notificacoes test/features/notificacoes
git commit -m "F38-T08: deep link no toque e SnackBar em primeiro plano (RF-30)"
```

---

### Task 9: Docs donos finais, runbook, fechamento e distribuição

**Files:**
- Modify: `docs/08-compartilhamento-colaborativo.md` (§11 novo + §10 checklist)
- Modify: `docs/09-runbook-operacoes.md` (§2: secrets, deploy, smoke, rotação)
- Modify: `docs/14-tarefas.md` (marcar Fase 38; tabela de progresso 187→…)
- Modify: `docs/16-roadmap-pos-mvp.md` (B3 concluído)
- Modify: `pubspec.yaml` (versão `1.5.0+9`)

**Interfaces:**
- Consumes: tudo das Tasks 1–8.
- Produces: documentação fechada e build distribuído.

- [ ] **Step 1: Doc 08 §11 (arquitetura do push)**

Adicionar ao final do doc 08:

```markdown
## 11. Notificações push (RF-30, F38)

Dois eventos disparam push (Android): **convite por e-mail recebido** e **novo membro numa lista sua**.
O disparo é server-side: triggers em `convites` (INSERT `tipo='email'`, `estado='pendente'`) e
`lista_membros` (INSERT `papel <> 'dono'`) chamam `public.notificar_push()`, que faz `net.http_post`
para a Edge Function `enviar-push` (URL/segredo no Vault). A função resolve os tokens em `push_tokens`
(service_role), envia pelo FCM HTTP v1 e remove tokens inválidos. No app: permissão contextual
(primeira lista criada ou primeiro convite aceito) + toggle "Notificações" em Configurações; token
registrado por dispositivo (`push_tokens`, RLS `user_id = auth.uid()`), apagado no logout. O toque
abre `/entrar?token=…` (convite) ou `/lista/:id` (entrada); em primeiro plano, SnackBar. Limites:
sem retry no `pg_net`; iOS/Web fora (iOS na Onda E; Web é local, ADR-013).
```

- [ ] **Step 2: Doc 08 §10 checklist**

Adicionar:

```markdown
- [ ] Push de convite e de entrada chegam ao aparelho (2 dispositivos); toque abre a tela certa.
- [ ] Token some ao desativar o toggle e ao sair da conta.
```

- [ ] **Step 3: Doc 09 §2 (runbook)**

Adicionar subseção:

```markdown
### 2.x. Notificações push (RF-30, F38)

- **Secrets:** `supabase secrets set PUSH_WEBHOOK_SECRET=... FCM_SERVICE_ACCOUNT='{...json...}'`.
- **Vault (usado pelos triggers):** `select vault.create_secret('<url da function>', 'push_function_url');`
  e `select vault.create_secret('<segredo>', 'push_webhook_secret');`.
- **Deploy:** `supabase functions deploy enviar-push`.
- **Operação externa:** habilitar a API FCM/Cloud Messaging e gerar a service account no console do
  Firebase (projeto `lista-compras-34f93`).
- **Smoke:** 2 aparelhos; convidar por e-mail → notificação no convidado; aceitar → notificação no dono;
  tocar → abre a tela. Sem `FCM_SERVICE_ACCOUNT`, a função é no-op (dev/teste).
- **Rotação de token:** tokens inválidos são removidos no envio; tokens do usuário no logout.
```

- [ ] **Step 4: Fechamento no doc 14/16**

Marcar todas as F38-T01…T09 como `[x]`; atualizar a tabela de progresso (Total 187 → 196; concluídas +9). No doc 16, marcar B3 como concluído (F38).

- [ ] **Step 5: Bump de versão**

Em `pubspec.yaml`: `version: 1.5.0+9`.

- [ ] **Step 6: Validação final**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: verde.

Run: `supabase db reset` e os testes SQL novos
Expected: `push_tokens_tests.sql` e `notificar_push_tests.sql` verdes.

- [ ] **Step 7: Commit**

```bash
git add docs pubspec.yaml
git commit -m "F38-T09: docs donos, runbook e fechamento da Fase 38 (RF-30)"
```

- [ ] **Step 8 (operação externa, sob demanda): deploy e distribuição**

```bash
supabase db push
supabase functions deploy enviar-push
flutter build apk --release --dart-define-from-file=dart_defines_prod.json
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --groups testadores
```

(Exige os secrets e o Vault configurados; sem eles o push é no-op. Registrar no histórico do 09 §2.6.)

---

## Self-Review

- **Cobertura da spec:** eventos (§2 → Tasks 3/4); `push_tokens`+RLS (§4.1/§4.2 → Task 2); triggers (§4.3 → Task 3); Edge Function (§5 → Task 4); app/FCM/permissão/toggle/token (§6.1–§6.3 → Tasks 5–7); deep link/foreground (§6.4 → Task 8); testes/rollout/riscos (§7 → Tasks 2–4, 9); decisões/RF-30/ADR-014/Fase 38 (§8 → Task 1). Sem lacunas.
- **Placeholders:** nenhum "TODO/TBD"; todo step de código tem bloco real.
- **Consistência de tipos:** `NotificacoesPush`/`PermissaoPush` (Tasks 5–8), `PushTokensRepository.registrar/remover` (Tasks 6–7), `rotaDaNotificacao` (Task 8), payload `{tipo, lista_id, token?, titulo, corpo}` e webhook `{evento, destinatario_id, lista_id, token?, titulo_lista}` (Tasks 3–4, 8) batem entre si.
