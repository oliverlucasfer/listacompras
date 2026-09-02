-- 0002_rls_policies.sql — funções auxiliares, enable/force RLS e policies
-- Docs donos: docs/02-seguranca-rls.md (§1–§4)

-- ============================================================================
-- 02 §1 — Funções auxiliares (performance e anti-recursão)
-- SECURITY DEFINER evita recursão infinita de policies em lista_membros.
-- ============================================================================
create or replace function public.is_member(lista uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.lista_membros lm
    where lm.lista_id = lista
      and lm.user_id = auth.uid()
  );
$$;

create or replace function public.papel_na_lista(lista uuid)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select lm.papel
  from public.lista_membros lm
  where lm.lista_id = lista
    and lm.user_id = auth.uid()
$$;

-- Checa dono sem aplicar RLS ao usuário invocante: indispensable no
-- self-insert do dono em lista_membros logo após criar a lista (a subquery
-- direta sobre listas roda sob as policies de SELECT — is_member — e não
-- vê a lista da qual o dono ainda não é membro).
create or replace function public.is_dono_de(lista uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.listas l
    where l.id = lista
      and l.dono_id = auth.uid()
  );
$$;

-- ============================================================================
-- 02 §2 — Habilitar e forçar RLS
-- force: policies valem também para o dono da tabela (exceto role superuser)
-- ============================================================================
alter table public.listas        enable row level security;
alter table public.lista_membros enable row level security;
alter table public.itens_lista   enable row level security;
alter table public.listas        force row level security;
alter table public.lista_membros force row level security;
alter table public.itens_lista   force row level security;

-- ============================================================================
-- 02 §4.1 — Policies de `listas`
-- ============================================================================
create policy "listas_select_membros"
  on public.listas for select
  using (public.is_member(id));

create policy "listas_insert_dono"
  on public.listas for insert
  with check (dono_id = auth.uid());

create policy "listas_update_editores"
  on public.listas for update
  using (public.papel_na_lista(id) in ('dono', 'editor'))
  with check (
    public.papel_na_lista(id) in ('dono', 'editor')
    -- dono_id é imutável via UPDATE (transferência é processo explícito, Fase 6);
    -- a subquery lê a snapshot antiga da linha e nega qualquer alteração.
    and dono_id = (
      select l.dono_id from public.listas l where l.id = id
    )
  );

create policy "listas_delete_dono"
  on public.listas for delete
  using (dono_id = auth.uid());

-- ============================================================================
-- 02 §4.2 — Policies de `itens_lista`
-- DELETE físico só do dono; editores usam soft delete (tombstone, 03)
-- ============================================================================
create policy "itens_select_membros"
  on public.itens_lista for select
  using (public.is_member(lista_id));

create policy "itens_insert_editores"
  on public.itens_lista for insert
  with check (public.papel_na_lista(lista_id) in ('dono', 'editor'));

create policy "itens_update_editores"
  on public.itens_lista for update
  using (public.papel_na_lista(lista_id) in ('dono', 'editor'))
  with check (public.papel_na_lista(lista_id) in ('dono', 'editor'));

create policy "itens_delete_dono"
  on public.itens_lista for delete
  using (
    exists (
      select 1 from public.listas l
      where l.id = itens_lista.lista_id
        and l.dono_id = auth.uid()
    )
  );

-- ============================================================================
-- 02 §4.3 — Policies de `lista_membros`
-- UPDATE não permitido no MVP (transferência de papel é Fase 6, 08 §6)
-- ============================================================================
create policy "membros_select_membros"
  on public.lista_membros for select
  using (public.is_member(lista_id));

create policy "membros_insert_dono"
  on public.lista_membros for insert
  with check (
    public.is_dono_de(lista_id)
    -- o dono se insere com papel 'dono'; ninguém insere terceiros como 'dono'
    and papel in ('editor', 'leitor', 'dono')
  );

create policy "membros_delete_dono"
  on public.lista_membros for delete
  using (
    public.is_dono_de(lista_id)
    -- dono não remove a si mesmo por aqui (evita lista sem dono)
    and user_id <> auth.uid()
  );
