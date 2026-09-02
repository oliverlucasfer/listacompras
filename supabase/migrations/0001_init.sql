-- 0001_init.sql — enum de unidades, tabelas, índices e triggers
-- Docs donos: docs/01-banco-de-dados.md (§3–§6), docs/02-seguranca-rls.md (§1–§4)

-- ============================================================================
-- Enum de unidades (01 §3) — fonte única da verdade (ADR-005, enum fechado)
-- Replicado no Dart (05) e no responseSchema do Gemini (04). NUNCA alterar
-- sem atualizar os três.
-- ============================================================================
create type public.unidade_item as enum (
  'un', 'kg', 'g', 'l', 'ml', 'caixa', 'pacote', 'pct', 'dz'
);

-- ============================================================================
-- Tabelas (01 §4)
-- IDs: gerados no servidor OU no cliente (UUID v4, criação offline — ADR-006)
-- Timestamps: timestamptz UTC. Soft delete: tombstone `deletado_em`.
-- ============================================================================

-- 01 §4.1 — listas
create table public.listas (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  titulo      text not null check (length(btrim(titulo)) between 1 and 120),
  dono_id     uuid not null references auth.users(id) on delete cascade,
  deletado_em timestamptz
);

create index idx_listas_dono on public.listas (dono_id) where deletado_em is null;

-- 01 §4.2 — lista_membros
create table public.lista_membros (
  id       uuid primary key default gen_random_uuid(),
  lista_id uuid not null references public.listas(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  papel    text not null check (papel in ('dono', 'editor', 'leitor')),
  unique (lista_id, user_id)
);

create index idx_membros_user on public.lista_membros (user_id);

-- 01 §4.3 — itens_lista
create table public.itens_lista (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  lista_id    uuid not null references public.listas(id) on delete cascade,
  nome        text not null check (length(btrim(nome)) between 1 and 120),
  quantidade  numeric not null default 1 check (quantidade > 0),
  unidade     public.unidade_item not null default 'un',
  concluido   boolean not null default false,
  ordem       integer not null default 0,
  deletado_em timestamptz
);

-- Deduplicação de itens ativos na mesma lista (case-insensitive)
create unique index uq_item_ativo
  on public.itens_lista (lista_id, lower(nome))
  where deletado_em is null;

create index idx_itens_lista_ordem
  on public.itens_lista (lista_id, ordem)
  where deletado_em is null;

-- ============================================================================
-- Triggers (01 §5–§6)
-- ============================================================================

-- 01 §5 — updated_at com preservação LWW: cliente que enviou ts explícito
-- (mutação offline) tem o valor preservado; update sem ts recebe now().
-- A decisão de qual versão vence é do Sync Engine (03 §5), não do banco.
create or replace function public.touch_updated_at_lww()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at = now();
  end if;
  return new;
end;
$$;

create trigger trg_listas_updated
  before update on public.listas
  for each row execute function public.touch_updated_at_lww();

create trigger trg_itens_updated
  before update on public.itens_lista
  for each row execute function public.touch_updated_at_lww();

-- 01 §6 — consistência do dono: 1 dono por lista; denormalização dono_id;
-- impede remoção/downgrade do dono (transferência explícita na Fase 6, 08 §6)
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
    -- Impede mais de um dono
    if qtd_donos > 1 then
      raise exception 'Lista já possui um dono';
    end if;

    -- Atualiza a denormalização SOMENTE quando o registro é do dono
    -- (insert/update de editor/leitor não pode alterar dono_id).
    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  -- Impede remoção/downgrade do dono (transferência é processo explícito, Fase 6).
  -- Usa old.papel (snapshot do trigger) — consultar a tabela num trigger AFTER
  -- veria a linha já alterada/apagada e nunca bloquearia.
  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    raise exception 'Transferência de dono deve ser processo explícito';
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_membros_dono
  after insert or update or delete on public.lista_membros
  for each row execute function public.sync_dono();
