# 01 — Banco de Dados (PostgreSQL)

> Navegação: [← 00 Visão Geral](00-visao-geral.md) · [02 Segurança RLS →](02-seguranca-rls.md)

**Este documento é o dono do schema.** Outros documentos apenas referenciam este (ex.: o [04 IA](04-ia-edge-function.md) usa o enum de unidades definido aqui).

---

## 1. Diagrama de Relacionamentos

```
               ┌────────────────┐
               │  auth.users    │
               └───────┬────────┘
                       │ 1
                       │
                       │ N
               ┌───────┴────────┐
               │ lista_membros  │
               └───────┬────────┘
                       │ N
                       │
                       │ 1
┌──────────────┐ 1   N ┌┴───────────────┐
│ itens_lista  ├───────┤    listas      │
└──────────────┘       └────────────────┘
```

## 2. Convenções

* Tabelas no plural, `snake_case`.
* PKs `uuid` gerados por `gen_random_uuid()` **ou pelo cliente** (UUID v4, para suportar criação offline — ver [03 Sincronização](03-sincronizacao-offline.md)).
* Timestamps sempre `timestamptz` (UTC).
* Soft delete via coluna `deletado_em timestamptz nullable` (*tombstone* de sincronização).
* Toda alteração de schema é uma **migration versionada** via Supabase CLI.

### Convenção de migrations
```
supabase/
└── migrations/
    ├── 0001_init.sql            # enum, tabelas, índices, triggers
    ├── 0002_rls_policies.sql    # políticas RLS (ver 02)
    └── 0003_realtime.sql        # publication do Realtime
```

---

## 3. Enum de Unidades

> **Fonte única da verdade.** O [04 IA](04-ia-edge-function.md) replica estes valores no `responseSchema`; o [05 App](05-app-flutter.md) replica no enum Dart.

```sql
create type public.unidade_item as enum (
  'un', 'kg', 'g', 'l', 'ml', 'caixa', 'pacote', 'pct', 'dz'
);
```

| Valor | Significado |
| :--- | :--- |
| `un` | Unidade |
| `kg` / `g` | Massa |
| `l` / `ml` | Volume |
| `caixa` / `pacote` / `pct` | Embalagens |
| `dz` | Dúzia |

---

## 4. Tabelas

### 4.1. `listas`

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `id` | `uuid` (PK) | `gen_random_uuid()` **ou gerado no cliente quando offline** |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | Criação |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | Última modificação — **base do last-write-wins** (ver [03](03-sincronizacao-offline.md)) |
| `titulo` | `text NOT NULL` | Nome da lista (ex: "Compras da Semana") |
| `dono_id` | `uuid NOT NULL FK → auth.users(id)` | Criador. **Denormalização** de `lista_membros` para queries RLS rápidas; consistência por trigger (Seção 6) |
| `deletado_em` | `timestamptz` nullable | Soft delete / tombstone |

```sql
create table public.listas (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  titulo      text not null check (length(btrim(titulo)) between 1 and 120),
  dono_id     uuid not null references auth.users(id) on delete cascade,
  deletado_em timestamptz
);

create index idx_listas_dono on public.listas (dono_id) where deletado_em is null;
```

### 4.2. `lista_membros`

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `id` | `uuid` (PK) | `gen_random_uuid()` |
| `lista_id` | `uuid NOT NULL FK → listas.id ON DELETE CASCADE` | Lista vinculada |
| `user_id` | `uuid NOT NULL FK → auth.users.id ON DELETE CASCADE` | Usuário membro |
| `papel` | `text NOT NULL` | `'dono'`, `'editor'`, `'leitor'` |

**Constraints:**
* `UNIQUE (lista_id, user_id)` — impede membros duplicados.
* **Trigger de consistência do dono** (Seção 6): linha com `papel = 'dono'` atualiza `listas.dono_id`; **impede mais de um `'dono'` por lista**.

```sql
create table public.lista_membros (
  id       uuid primary key default gen_random_uuid(),
  lista_id uuid not null references public.listas(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  papel    text not null check (papel in ('dono', 'editor', 'leitor')),
  unique (lista_id, user_id)
);

create index idx_membros_user on public.lista_membros (user_id);
```

> **Nota (exclusão de conta / LGPD):** `ON DELETE CASCADE` em `user_id` garante que, ao excluir o usuário do Auth, suas participações somem; a exclusão da conta dispara também a remoção das listas de que é dono (cascade em `listas.dono_id`). Detalhes operacionais em [06 MVP & Entregas](06-mvp-entregas.md).

### 4.3. `itens_lista`

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `id` | `uuid` (PK) | `gen_random_uuid()` **ou gerado no cliente quando offline** |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | Criação |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | Base do last-write-wins |
| `lista_id` | `uuid NOT NULL FK → listas.id ON DELETE CASCADE` | Lista vinculada |
| `nome` | `text NOT NULL` | Nome do item (ex: "Leite") |
| `quantidade` | `numeric NOT NULL DEFAULT 1 CHECK (quantidade > 0)` | Quantidade |
| `unidade` | `unidade_item NOT NULL DEFAULT 'un'` | Enum (Seção 3) |
| `concluido` | `boolean NOT NULL DEFAULT false` | Estado da checkbox |
| `ordem` | `integer NOT NULL DEFAULT 0` | Posição na lista (drag-and-drop) |
| `deletado_em` | `timestamptz` nullable | Soft delete / tombstone |

**Constraints e índices:**
* `UNIQUE (lista_id, lower(nome)) WHERE deletado_em IS NULL` — deduplicação de itens ativos (a IA e o usuário não criam item repetido na mesma lista).
* Índice `(lista_id, ordem)` para leitura ordenada.

```sql
create table public.itens_lista (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  lista_id   uuid not null references public.listas(id) on delete cascade,
  nome       text not null check (length(btrim(nome)) between 1 and 120),
  quantidade numeric not null default 1 check (quantidade > 0),
  unidade    public.unidade_item not null default 'un',
  concluido  boolean not null default false,
  ordem      integer not null default 0,
  deletado_em timestamptz
);

create unique index uq_item_ativo
  on public.itens_lista (lista_id, lower(nome))
  where deletado_em is null;

create index idx_itens_lista_ordem
  on public.itens_lista (lista_id, ordem)
  where deletado_em is null;
```

---

## 5. Trigger de `updated_at`

Todo UPDATE deve atualizar `updated_at` automaticamente (base do LWW):

```sql
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_listas_updated
  before update on public.listas
  for each row execute function public.touch_updated_at();

create trigger trg_itens_updated
  before update on public.itens_lista
  for each row execute function public.touch_updated_at();
```

> **Cuidado com o LWW:** o cliente envia seu próprio `updated_at` quando a mutação foi feita offline. O trigger acima só deve sobrescrever quando o valor recebido for **mais antigo** que o atual — caso contrário o timestamp do cliente se perde. Implementação recomendada:
> ```sql
> create or replace function public.touch_updated_at_lww()
> returns trigger
> language plpgsql
> as $$
> begin
>   if new.updated_at is not distinct from old.updated_at then
>     new.updated_at = now();  -- update sem timestamp explícito do cliente
>   end if;
>   return new;                -- cliente enviou ts: preserva (LWW no sync engine)
> end;
> $$;
> ```
> A decisão de qual versão vence fica no **Sync Engine** ([03](03-sincronizacao-offline.md)), não no banco.

---

## 6. Trigger de Consistência do Dono

Garante que `listas.dono_id` reflita sempre o único membro com `papel = 'dono'`:

```sql
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

    -- Atualiza a denormalização
    update public.listas
    set dono_id = new.user_id
    where id = new.lista_id;
  end if;

  -- Impede remoção/downgrade do dono (transferência é processo explícito, Fase 6)
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and new.papel <> 'dono') then
    if exists (
      select 1 from public.lista_membros
      where lista_id = coalesce(old.lista_id, new.lista_id)
        and user_id = old.user_id
        and papel = 'dono'
    ) then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_membros_dono
  after insert or update or delete on public.lista_membros
  for each row execute function public.sync_dono();
```

**Regras de negócio implementadas:**
1. Ao criar a lista, o dono insere a própria linha em `lista_membros` com `papel = 'dono'` (a policy de INSERT de `listas` exige `dono_id = auth.uid()` — ver [02](02-seguranca-rls.md)).
2. Não é possível ter 2 donos.
3. Não é possível remover ou rebaixar o dono sem processo explícito de transferência — **planejado na Fase 6, ver [08 §6](08-compartilhamento-colaborativo.md)** (RPC `transferir_dono` + alteração neste trigger).

---

## 7. Realtime

```sql
alter publication supabase_realtime add table public.listas;
alter publication supabase_realtime add table public.itens_lista;
```

* `lista_membros` **não** vai ao publication por enquanto (raramente muda; evita ruído). Reavaliar na Fase 6.
* O Realtime respeita as policies RLS — usuários só recebem eventos de listas de que participam (ver [02](02-seguranca-rls.md)).

---

## 8. Checklist de validação (Fase 1)

- [ ] `supabase db reset` aplica todas as migrations sem erro.
- [ ] `insert` em `lista_membros` com 2º dono falha com exceção.
- [ ] `update` em `itens_lista` reflete em `updated_at`.
- [ ] `insert` de item duplicado (mesmo nome, ativo) na mesma lista falha por unique parcial.
- [ ] `insert` de `unidade = 'quilos'` falha (fora do enum).
- [ ] Excluir `auth.users` em cascata remove listas/membros/itens (teste em ambiente dev).
- [ ] Policies RLS aplicadas e testes de negação passando (ver [02](02-seguranca-rls.md)).

---

## Documentos relacionados
- [02 Segurança RLS](02-seguranca-rls.md) — policies deste schema
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — como este schema suporta LWW/tombstones
- [00 Visão Geral](00-visao-geral.md) — cronograma e riscos
