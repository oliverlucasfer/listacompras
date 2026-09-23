# 01 — Banco de Dados (PostgreSQL)

> Navegação: [← 00 Visão Geral](00-visao-geral.md) · [02 Segurança RLS →](02-seguranca-rls.md)

**Este documento é o dono do schema.** Outros documentos apenas referenciam este (ex.: o [04 Importação](04-importacao-lista.md) usa o enum de unidades definido aqui).

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
    ├── 0003_realtime.sql        # publication do Realtime
    ├── 0004_ia_rate_limit.sql   # rate limit da IA — removido na 0013 (F17)
    ├── 0005_excluir_conta.sql   # RPC de exclusão de conta (ver 06)
    ├── 0006_categorias.sql      # enum de categorias + coluna (ver §3.2, ADR-011)
    ├── ...                      # 0007–0012 (ver histórico de migrations)
    ├── 0013_remover_ia_rate_limit.sql # remove rate limit da IA (F17)
    ├── 0014_agora_servidor.sql  # RPC do relógio do servidor (ver 02 §4.5)
    ├── 0015_membros_insert_dono_e_convites_updated.sql # R-18 + touch de convites
    ├── 0016_transferir_dono.sql # RPC transferir_dono + sync_dono v3 (RF-14)
    ├── 0017_preco_item.sql      # coluna preco_centavos (RF-21)
    ├── 0018_arquivar_listas.sql # coluna arquivada_em + trigger (RF-22)
    ├── 0019_convites_email.sql  # RPCs de convite por e-mail (RF-13, ver 02 §4.7)
    ├── 0020_orcamento_lista.sql # coluna orcamento_centavos (RF-28, F36)
    └── 0021_push_tokens.sql     # tabela push_tokens + RLS + RPC (RF-30, F38)
```

---

## 3. Enums Fechados

> **Fonte única da verdade.** O [04 Importação](04-importacao-lista.md) documenta o parser local; o [05 App](05-app-flutter.md) replica no enum Dart.

### 3.1. Unidades (`unidade_item`)

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

### 3.2. Categorias (`categoria_item`, ADR-011)

```sql
create type public.categoria_item as enum (
  'hortifruti', 'mercearia', 'frios', 'laticinios', 'congelados',
  'padaria', 'bebidas', 'pet', 'limpeza', 'higiene', 'outros'
);
```

A **ordem do enum é o padrão da ordem dos grupos na UI** (doc 05 §6.3); o usuário pode reordenar as categorias — ordem pessoal, global e local por dispositivo (RF-24). Labels pt-BR: Hortifrúti, Mercearia, Frios, Laticínios, Congelados, Padaria, Bebidas, Pet, Limpeza, Higiene, Outros.

| Valor | Significado |
| :--- | :--- |
| `hortifruti` | Frutas, verduras e legumes |
| `mercearia` | Secos e embalados (arroz, enlatados, grãos) |
| `frios` | Fatiados e perecíveis de balcão (queijo, presunto) |
| `laticinios` | Leite, iogurte, manteiga |
| `congelados` | Congelados e sorvetes |
| `padaria` | Pães e bolos |
| `bebidas` | Água, sucos, refrigerantes |
| `pet` | Produtos para animais |
| `limpeza` | Produtos de limpeza da casa |
| `higiene` | Higiene e cuidados pessoais |
| `outros` | Fallback — não classificado (default) |

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
| `arquivada_em` | `timestamptz` nullable | Arquivada nesse instante (RF-22, F26) — `null` = **ativa**; `timestamptz` = arquivada (reversível: volta a `null`). Só o **dono** muda a coluna (trigger). Coluna aditiva da `0018` |
| `orcamento_centavos` | `integer` nullable | Orçamento (limite de gasto) em centavos (RF-28, F36) — `null` = sem orçamento; `0` é válido; CHECK `null ou 0..99999999`. Coluna aditiva da `0020` |

```sql
create table public.listas (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  titulo      text not null check (length(btrim(titulo)) between 1 and 120),
  dono_id     uuid not null references auth.users(id) on delete cascade,
  deletado_em timestamptz,
  arquivada_em timestamptz,
  orcamento_centavos integer
    check (orcamento_centavos is null
           or (orcamento_centavos >= 0 and orcamento_centavos <= 99999999))
);

create index idx_listas_dono on public.listas (dono_id) where deletado_em is null;

create index idx_listas_dono_ativas
  on public.listas (dono_id)
  where deletado_em is null and arquivada_em is null;
```

> **Arquivo da lista (RF-22, F26):** `arquivada_em` **não tem policy nova** — herda o RLS de `listas`. O trigger `trg_listas_arquivo_dono` (função `protege_arquivo_dono()`, migration `0018`) rejeita a mudança da coluna por quem não é o dono (`APENAS_O_DONO_PODE_ARQUIVAR`); renomear (dono **ou** editor) não toca `arquivada_em` e segue normal. O índice parcial `idx_listas_dono_ativas` cobre a leitura das listas ativas do painel (não deletada e não arquivada).

> **Orçamento da lista (RF-28, F36):** `orcamento_centavos` (RF-28, F36): `null` = sem orçamento; `0` válido; CHECK `null ou 0..99999999`; **sem policy nova** — herda o UPDATE de `listas` (dono/editor).

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
| `unidade` | `unidade_item NOT NULL DEFAULT 'un'` | Enum (Seção 3.1) |
| `categoria` | `categoria_item NOT NULL DEFAULT 'outros'` | Enum (Seção 3.2, ADR-011) — agrupa pendentes na UI; migrada aditivamente em `0006` (itens antigos → `outros`) |
| `concluido` | `boolean NOT NULL DEFAULT false` | Estado da checkbox |
| `ordem` | `integer NOT NULL DEFAULT 0` | Posição na lista (drag-and-drop) |
| `preco_centavos` | `integer` nullable | Preço unitário em centavos (RF-21, F25) — `null` = sem preço (item fora do total); `0` é válido; CHECK `null ou 0..99999999`. Coluna aditiva da `0017` |
| `deletado_em` | `timestamptz` nullable | Soft delete / tombstone |

**Constraints e índices:**
* `UNIQUE (lista_id, lower(nome)) WHERE deletado_em IS NULL` — deduplicação de itens ativos (o usuário não cria item repetido na mesma lista).
* `CHECK (preco_centavos IS NULL OR (preco_centavos >= 0 AND preco_centavos <= 99999999))` (migration `0017`) — dinheiro em **centavos inteiros** (sem `float`); teto de R$ 999.999,99; negativo rejeitado.
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
  categoria  public.categoria_item not null default 'outros',
  concluido  boolean not null default false,
  ordem      integer not null default 0,
  preco_centavos integer
    check (preco_centavos is null or (preco_centavos >= 0 and preco_centavos <= 99999999)),
  deletado_em timestamptz
);

create unique index uq_item_ativo
  on public.itens_lista (lista_id, lower(nome))
  where deletado_em is null;

create index idx_itens_lista_ordem
  on public.itens_lista (lista_id, ordem)
  where deletado_em is null;
```

> **Compatibilidade (spec F6 §7):** clientes antigos que escrevem sem `categoria` recebem o default `outros` no INSERT; o upsert LWW do sync **não toca** a coluna quando ela não está no payload — a categoria existente é preservada.

> **Preço do item (RF-21, F25):** `preco_centavos` **herda as policies de `itens_lista`** (quem edita item edita preço — `dono`/`editor`) — **sem policy nova**. Item com `null` fica fora do total do carrinho; `0` (R$ 0,00) é preço válido.

---

## 4.4. `convites` (Fase 6)

Tabela de convites por link/e-mail: `id`, `lista_id` (CASCADE), `criado_por` (FK `auth.users`), `token` (uuid único), `tipo` (`link`/`email`), `email`, `papel_oferecido` (`editor`/`leitor` — nunca `dono`), `estado` (`pendente`/`aceito`/`expirado`/`revogado`), `expira_em` (7 dias), `created_at`, `atualizado_em`.

* **Dono do detalhe:** [08 §2](08-compartilhamento-colaborativo.md) (tabela e índices) e [02 §4.4](02-seguranca-rls.md) (policies). Migration `0007`; entram no publication (§7).
* **`atualizado_em`:** carimbado pelo trigger `trg_convites_updated` (`touch_convites_updated_at`, migration `0015`) — mesmo contrato de `listas`/`itens_lista` (§5).
* **R-17 resolvido (migration `0016`):** `criado_por` ganhou `ON DELETE CASCADE` — com a transferência de dono (RF-14), o ex-dono pode deixar de ser dono e ainda ter convites criados; sem a cascata, excluir a conta dele falharia por FK.
* **RPCs de convite por e-mail (RF-13, F32 — migration `0019`):** `meus_convites_pendentes()` (devolve `id`, `token`, `lista_titulo`, `papel_oferecido`, `expira_em` — só convites `email` `pendente` **não expirados** dirigidos ao e-mail do chamador) e `recusar_convite(p_id)` (revoga só o convite do próprio e-mail, exigindo `expira_em >= now()`). Ambos `security definer` com grant apenas a `authenticated`; o RLS de `convites` fica **intacto** — SQL e racional em [02 §4.7](02-seguranca-rls.md).

---

### 4.5. `push_tokens` (RF-30, F38)

| Coluna | Tipo | Regra |
| :--- | :--- | :--- |
| `id` | `uuid` | PK, `gen_random_uuid()` |
| `user_id` | `uuid` | FK `auth.users(id)` `on delete cascade` (RF-11) |
| `token` | `text` | **unique** — o RPC `registrar_push_token` faz upsert por token; o mesmo aparelho reatribui o token ao novo usuário |
| `plataforma` | `text` | `check (plataforma in ('android','ios'))`, default `android` |
| `atualizado_em` | `timestamptz` | atualizado pelo RPC `registrar_push_token` no upsert |
| `created_at` | `timestamptz` | `now()` |

Índice `idx_push_tokens_user (user_id)`. Device-only: **não** entra no Realtime nem no sync.

* **RPC `registrar_push_token(p_token, p_plataforma)` (RF-30, F38 — migration `0021`):** `security definer`; reatribui o token a `auth.uid()` (apaga a linha de outro dono com o mesmo token e insere/atualiza a do chamador), viabilizando o *device handoff* — o RLS owner-only impede o upsert direto do cliente sobre a linha de outro dono. Grant apenas a `authenticated` (anon não executa). SQL e racional em [02 §4.8](02-seguranca-rls.md).

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

Garante que `listas.dono_id` reflita sempre o único membro com `papel = 'dono'`. A versão atual (`v3`, migration `0016`) reconhece as duas marcas de processo explícito: exclusão de conta (`app.excluindo_conta`, `0005`) e transferência de dono (`app.transferindo_dono`, RPC `transferir_dono` — [08 §6](08-compartilhamento-colaborativo.md)):

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

    -- Atualiza a denormalização SOMENTE quando o registro é do dono
    -- (insert/update de editor/leitor não pode alterar dono_id).
    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  -- Impede remoção/downgrade do dono (transferência é processo explícito).
  -- Exceções: exclusão de conta (migration 0005) e RPC transferir_dono
  -- (migration 0016). Usa old.papel (snapshot do trigger) — consultar a tabela
  -- num trigger AFTER veria a linha já alterada/apagada e nunca bloquearia.
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

create trigger trg_membros_dono
  after insert or update or delete on public.lista_membros
  for each row execute function public.sync_dono();
```

**Associação automática do dono (migration `0010`, correção):** ao inserir uma lista, o servidor cria a linha do dono em `lista_membros` — o cliente nunca precisou (nem conseguiu, offline) fazer esse self-insert:

```sql
create or replace function public.criar_membro_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.lista_membros (lista_id, user_id, papel)
  values (new.id, new.dono_id, 'dono')
  on conflict (lista_id, user_id) do nothing;
  return new;
end;
$$;

create trigger trg_listas_cria_dono
  after insert on public.listas
  for each row execute function public.criar_membro_dono();

-- Backfill das listas existentes sem dono membro (migration 0010).
insert into public.lista_membros (lista_id, user_id, papel)
select l.id, l.dono_id, 'dono'
from public.listas l
where not exists (
  select 1 from public.lista_membros lm
  where lm.lista_id = l.id and lm.papel = 'dono'
);
```

**Regras de negócio implementadas:**
1. Ao inserir uma lista, o **servidor** cria a linha do dono em `lista_membros` com `papel = 'dono'` (trigger `trg_listas_cria_dono`, migration `0010`). A policy de INSERT de `listas` exige `dono_id = auth.uid()` (ver [02](02-seguranca-rls.md)); a associação do dono é derivada dele.
2. Não é possível ter 2 donos.
3. Não é possível remover ou rebaixar o dono sem processo explícito de transferência — o RPC `transferir_dono` (migration `0016`, [08 §6](08-compartilhamento-colaborativo.md)) é esse processo: `security definer`, só o dono atual transfere para um membro existente; ele demove o antigo para `editor` e promove o novo na mesma transação, marcando `app.transferindo_dono` para o trigger liberar o downgrade. `listas.dono_id` continua sendo ajustado **só pelo trigger**.
4. **Exceção — exclusão de conta ([06 §3.3.1](06-mvp-entregas.md), migration `0005`):** o RPC `excluir_conta()` marca a transação com `set_config('app.excluindo_conta', 'true')` e o trigger reconhece a marca, permitindo a remoção do dono em cascata — a conta inteira está sendo apagada, junto com suas listas. O `set_config` de namespace customizado só é executável por SQL direto (não via PostgREST), e o RPC é `security definer` — clientes não conseguem forjar a marca. O `sync_dono` v3 reconhece as duas marcas (`app.excluindo_conta` e `app.transferindo_dono`).

---

## 7. Realtime

```sql
alter publication supabase_realtime add table public.listas;
alter publication supabase_realtime add table public.itens_lista;
alter publication supabase_realtime add table public.lista_membros;
alter publication supabase_realtime add table public.convites;
```

* `lista_membros` e `convites` entram no publication desde a **Fase 6** (migration `0007`): o membro removido precisa saber que perdeu acesso para limpar o cache local e o convite precisa aparecer para o destinatário.
* **Limite medido (R-11, [08 §9](08-compartilhamento-colaborativo.md)):** `replica identity full` (migration `0008`) **não basta** — o serviço Realtime v2.34 só emite o `old_record` quando o tenant está em `private_only`, coluna que o `config.toml` do CLI não expõe. Na prática, o DELETE de `lista_membros` chega com `old_record` vazio; a limpeza do cache do removido acontece por reconexão/bootstrap/`sairDaLista`, não pelo evento.
* O Realtime respeita as policies RLS — usuários só recebem eventos de listas de que participam (ver [02](02-seguranca-rls.md)).

---

## 8. Checklist de validação (Fase 1)

- [ ] `supabase db reset` aplica todas as migrations sem erro.
- [ ] `insert` em `lista_membros` com 2º dono falha com exceção.
- [ ] `update` em `itens_lista` reflete em `updated_at`.
- [ ] `insert` de item duplicado (mesmo nome, ativo) na mesma lista falha por unique parcial.
- [ ] `insert` de `unidade = 'quilos'` falha (fora do enum).
- [ ] `unnest(enum_range(null::categoria_item))` retorna os 11 valores na ordem dos grupos (F6-T01).
- [ ] `insert` com `categoria = 'alimentos'` falha (fora do enum).
- [ ] `insert` de item sem `categoria` grava `outros` (F6-T01).
- [ ] Excluir `auth.users` em cascata remove listas/membros/itens (teste em ambiente dev).
- [ ] Policies RLS aplicadas e testes de negação passando (ver [02](02-seguranca-rls.md)).

---

## Documentos relacionados
- [02 Segurança RLS](02-seguranca-rls.md) — policies deste schema
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — como este schema suporta LWW/tombstones
- [00 Visão Geral](00-visao-geral.md) — cronograma e riscos
