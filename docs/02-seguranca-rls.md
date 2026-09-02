# 02 — Segurança (Row Level Security)

> Navegação: [← 01 Banco de Dados](01-banco-de-dados.md) · [03 Sincronização →](03-sincronizacao-offline.md)

**Este documento é o dono das políticas RLS.** O Row Level Security é a camada de segurança primária: **nenhuma requisição direta ao Postgres pode confiar no cliente**. Todas as tabelas terão RLS habilitado.

---

## 1. Função auxiliar `is_member` (performance e anti-recursão)

```sql
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
```

* `SECURITY DEFINER` **evita recursão infinita de policies** em `lista_membros` (a policy consulta a tabela através da função, que roda com privilégio de dono e não reavalia as policies dela mesma).
* `STABLE` permite ao planner reutilizar o resultado dentro da mesma statement.
* Usada por todas as policies de SELECT e por INSERT/UPDATE de itens.

### Função auxiliar de papel (para políticas de escrita)

```sql
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
```

---

## 2. Habilitar RLS

```sql
alter table public.listas        enable row level security;
alter table public.lista_membros enable row level security;
alter table public.itens_lista   enable row level security;
alter table public.listas        force row level security;
alter table public.lista_membros force row level security;
alter table public.itens_lista   force row level security;
```

---

## 3. Matriz de Políticas

| Tabela | Operação | Quem pode | Condição |
| :--- | :--- | :--- | :--- |
| `listas` | SELECT | Qualquer membro | `is_member(id)` |
| `listas` | INSERT | Dono (criação) | `dono_id = auth.uid()` |
| `listas` | UPDATE | Membros `dono`/`editor` | `papel_na_lista(id) in ('dono','editor')` |
| `listas` | DELETE | Só dono | `dono_id = auth.uid()` |
| `itens_lista` | SELECT | Qualquer membro | `is_member(lista_id)` |
| `itens_lista` | INSERT | Membros `dono`/`editor` | `papel_na_lista(lista_id) in ('dono','editor')` |
| `itens_lista` | UPDATE | Membros `dono`/`editor` | `papel_na_lista(lista_id) in ('dono','editor')` |
| `itens_lista` | DELETE | Só dono da lista | join com `listas.dono_id` |
| `lista_membros` | SELECT | Qualquer membro | `is_member(lista_id)` |
| `lista_membros` | INSERT / DELETE | Só dono | lista em que `dono_id = auth.uid()` |
| `lista_membros` | UPDATE | *(não permitido no MVP)* | — (transferência de papel é Fase 6) |

**Regras complementares:**
* `leitor` tem acesso apenas de leitura — políticas de INSERT/UPDATE/DELETE checam explicitamente o papel.
* Realtime respeita as mesmas políticas (usuário só recebe broadcast de listas de que participa).
* `auth.uid()` é sempre avaliado do JWT — **nunca** confiar em campos enviados pelo cliente.

---

## 4. SQL das Policies

### 4.1. `listas`

```sql
create policy "listas_select_membros"
  on public.listas for select
  using (public.is_member(id));

create policy "listas_insert_dono"
  on public.listas for insert
  with check (dono_id = auth.uid());

create policy "listas_update_editores"
  on public.listas for update
  using (public.papel_na_lista(id) in ('dono', 'editor'))
  with check (public.papel_na_lista(id) in ('dono', 'editor'));

create policy "listas_delete_dono"
  on public.listas for delete
  using (dono_id = auth.uid());
```

### 4.2. `itens_lista`

```sql
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
```

> **Decisão de design:** DELETE de item restrito ao dono da lista. Editores/removidos usam **soft delete** (`deletado_em` via UPDATE, permitido a editores) — assim o tombstone de sincronização continua funcionando ([03](03-sincronizacao-offline.md)) e quem criou o item não perde histórico por capricho de um editor.

### 4.3. `lista_membros`

```sql
create policy "membros_select_membros"
  on public.lista_membros for select
  using (public.is_member(lista_id));

create policy "membros_insert_dono"
  on public.lista_membros for insert
  with check (
    exists (
      select 1 from public.listas l
      where l.id = lista_id
        and l.dono_id = auth.uid()
    )
    -- o dono se insere com papel 'dono'; ninguém insere terceiros como 'dono'
    and papel in ('editor', 'leitor', 'dono')
  );

create policy "membros_delete_dono"
  on public.lista_membros for delete
  using (
    exists (
      select 1 from public.listas l
      where l.id = lista_id
        and l.dono_id = auth.uid()
    )
    -- dono não remove a si mesmo por aqui (evita lista sem dono)
    and user_id <> auth.uid()
  );
```

> **Nota sobre o próprio dono:** ao criar a lista, o fluxo é (1) INSERT em `listas` com `dono_id = auth.uid()`, (2) INSERT em `lista_membros` com `papel = 'dono'`. O trigger `sync_dono` ([01 §6](01-banco-de-dados.md)) valida a unicidade.

---

## 5. Testes de Negação (obrigatórios na Fase 1)

Casos que **DEVEM falhar** (executados como usuário autenticado sem acesso, via SQL ou testes de integração):

| # | Cenário | Expectativa |
| :--- | :--- | :--- |
| N-01 | Usuário A faz SELECT da lista de usuário B (não é membro) | 0 linhas |
| N-02 | Usuário A faz INSERT de item na lista de B | violação de policy |
| N-03 | Usuário `leitor` faz UPDATE em item | violação de policy |
| N-04 | Usuário `leitor` faz INSERT em item | violação de policy |
| N-05 | Usuário `editor` faz DELETE físico de item | violação de policy (só dono) |
| N-06 | Usuário `editor` tenta INSERT em `lista_membros` | violação de policy |
| N-07 | Usuário A tenta se remover da lista onde é dono | violação de policy |
| N-08 | Usuário anônimo (sem JWT) faz SELECT de qualquer tabela | 0 linhas |
| N-09 | Usuário A tenta UPDATE de `listas.dono_id` para si mesmo | violação de policy |
| N-10 | Usuário A insere 2º membro `papel='dono'` na própria lista | exceção do trigger `sync_dono` |

Casos que **DEVEM passar**:

| # | Cenário | Expectativa |
| :--- | :--- | :--- |
| P-01 | Dono cria lista + insere a si em `lista_membros` | sucesso |
| P-02 | Dono convida `editor` e `leitor` | sucesso |
| P-03 | `editor` cria/edita/soft-deleta itens | sucesso |
| P-04 | `leitor` lê lista e itens | sucesso |
| P-05 | Realtime entrega eventos apenas das listas do usuário | sucesso |

Ferramentas: testes de integração com dois usuários reais (ver [07 Qualidade](07-qualidade-ci.md)) ou script SQL com `set local role authenticated; set local request.jwt.claims = ...` em ambiente dev.

---

## 6. Checklist de validação (Fase 1)

- [ ] `force row level security` aplicado em todas as tabelas.
- [ ] Todos os 10 casos de negação (N-01…N-10) falham como esperado.
- [ ] Todos os 5 casos positivos (P-01…P-05) passam.
- [ ] Policies versionadas na migration `0002_rls_policies.sql`.
- [ ] Realtime recebe apenas eventos autorizados (teste com 2 contas).

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — schema protegido por estas policies
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — escritas do sync passam pelas mesmas policies
- [07 Qualidade & CI](07-qualidade-ci.md) — como os testes de negação rodam no CI
