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

### Função auxiliar de dono (para policies de `lista_membros`)

```sql
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
```

> **Por que não um `EXISTS` direto sobre `listas`?** Subqueries dentro de policies são avaliadas com as policies do usuário invocante. Quando o dono cria a lista e a associação do dono é criada (trigger `trg_listas_cria_dono`, migration `0010`) ou quando o dono adiciona membros, ele **ainda não é membro** — `is_member` é falso e o `EXISTS` não veria a própria lista, tornando o fluxo de criação (doc [02 §4.3](#43-lista_membros)) impossível. A função `SECURITY DEFINER` contorna o RLS do invocante.

### Função auxiliar de e-mail (para policies de `convites`, Fase 6)

```sql
create or replace function public.email_autenticado()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select u.email from auth.users u where u.id = auth.uid()
$$;
```

Mesma justificativa das demais: `auth.users` não é legível pelo role `authenticated` dentro de uma policy — a função `SECURITY DEFINER` resolve. Usada pela policy de SELECT de convites dirigidos ao próprio e-mail ([08 §2](08-compartilhamento-colaborativo.md)).

---

## 2. Habilitar RLS

```sql
alter table public.listas        enable row level security;
alter table public.lista_membros enable row level security;
alter table public.itens_lista   enable row level security;
alter table public.convites      enable row level security;
alter table public.listas        force row level security;
alter table public.lista_membros force row level security;
alter table public.itens_lista   force row level security;
alter table public.convites      force row level security;
```

> `convites` (Fase 6, migration `0007`) segue as mesmas regras das demais: RLS habilitada e forçada, policies em [§4.4](#44-convites-fase-6--08-2).

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
| `lista_membros` | INSERT | Dono (adicionar membro) | `is_dono_de(lista_id)` **e** (`papel in ('editor','leitor')` **ou** `user_id = auth.uid()`) — terceiros nunca entram como `dono` (migration `0015`, R-18); a associação do próprio dono é criada pelo servidor ao inserir a lista (migration `0010`) |
| `lista_membros` | UPDATE | Dono (papel de outro membro) | `is_dono_de(lista_id)` e alvo `user_id <> auth.uid()`; papel destino `in ('editor','leitor')` (F7-T07, migration 0009) |
| `lista_membros` | DELETE | Dono remove outros **ou** o próprio membro sai | dono: `is_dono_de(lista_id)` e `user_id <> auth.uid()`; saída: `user_id = auth.uid()` e `not is_dono_de(lista_id)` (F7-T07, migration 0009) |
| `convites` | SELECT | Dono da lista | papel `dono` em `lista_membros` |
| `convites` | SELECT | Qualquer autenticado | só convite `email` dirigido a si, `pendente` |
| `convites` | INSERT | Dono da lista | `criado_por = auth.uid()` e é dono |
| `convites` | UPDATE | Dono da lista | idem (revogar) |
| `convites` | DELETE | Dono da lista | idem (limpeza de convites antigos) |

**Regras complementares:**
* `leitor` tem acesso apenas de leitura — políticas de INSERT/UPDATE/DELETE checam explicitamente o papel.
* Realtime respeita as mesmas políticas (usuário só recebe broadcast de listas de que participa).
* `auth.uid()` é sempre avaliado do JWT — **nunca** confiar em campos enviados pelo cliente.
* **Associação do dono garantida:** toda lista tem exatamente um `papel='dono'` em `lista_membros` (trigger `trg_listas_cria_dono`, migrations `0010`/`0011`). O app deriva o papel do dono de `listas.dono_id` (offline, independente de carregar os papéis) e a tela de membros mescla o dono da lista local quando o servidor não devolve a linha.

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
  with check (
    public.papel_na_lista(id) in ('dono', 'editor')
    -- dono_id é imutável via UPDATE (transferência é processo explícito, Fase 6);
    -- a subquery lê a snapshot antiga da linha e nega qualquer alteração.
    -- Sem isto, um editor poderia se autoprometer a dono contornando o
    -- trigger sync_dono ([01 §6](01-banco-de-dados.md)), que só reage a lista_membros.
    -- ATENÇÃO: a linha externa precisa ser qualificada (`listas.id`); usar `id`
    -- não qualificado resolve para o `l.id` do próprio subselect (`l.id = l.id`,
    -- sempre verdadeiro) — bug corrigido pela migration `0012` (F12-T04).
    and dono_id = (
      select l.dono_id from public.listas l where l.id = listas.id
    )
  );

create policy "listas_delete_dono"
  on public.listas for delete
  using (dono_id = auth.uid());
```

> **Orçamento da lista (RF-28, F36):** `orcamento_centavos` **não cria policy** — herda o UPDATE de `listas` (`listas_update_editores`, dono/editor).

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
    public.is_dono_de(lista_id)
    -- 'dono' só para o próprio usuário; terceiros apenas como editor/leitor
    -- (migration 0015, R-18: antes aceitava qualquer user_id com papel 'dono'
    -- e o invariante ficava só com o trigger `sync_dono`)
    and (papel in ('editor', 'leitor') or user_id = auth.uid())
  );

create policy "membros_delete_dono"
  on public.lista_membros for delete
  using (
    public.is_dono_de(lista_id)
    -- dono não remove a si mesmo por aqui (evita lista sem dono)
    and user_id <> auth.uid()
  );

-- F7-T07 (migration 0009): troca de papel (`mudarPapel`) e saída
-- voluntária (`sairDaLista`) — na 0002 o UPDATE era "não permitido no
-- MVP" e sem estas policies ambas as operações eram no-ops silenciosos.
create policy "membros_update_papel_dono"
  on public.lista_membros for update
  using (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
  )
  with check (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
    -- nunca promove a dono: transferência é processo explícito (08 §6)
    and papel in ('editor', 'leitor')
  );

create policy "membros_delete_proprio"
  on public.lista_membros for delete
  using (
    user_id = auth.uid()
    and not public.is_dono_de(lista_id)
  );
```

> **Notas:** o trigger `sync_dono` ([01 §6](01-banco-de-dados.md)) permanece intacto — é ele quem bloqueia qualquer mudança na linha do dono e a remoção/downgrade do dono (as policies acima já negam ao dono alterar/remover a própria linha). As policies de DELETE são permissivas e se somam (OR): dono remove outros, membro remove a própria linha.

> **Nota sobre o próprio dono:** ao criar a lista, o fluxo é (1) INSERT em `listas` com `dono_id = auth.uid()`, (2) INSERT em `lista_membros` com `papel = 'dono'`. O trigger `sync_dono` ([01 §6](01-banco-de-dados.md)) valida a unicidade.

### 4.4. `convites` (Fase 6 — [08 §2](08-compartilhamento-colaborativo.md))

```sql
create policy "convites_select_email_proprio"
  on public.convites for select
  using (
    tipo = 'email'
    and estado = 'pendente'
    and lower(email) = lower(public.email_autenticado())
  );

create policy "convites_select_dono"
  on public.convites for select
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_insert_dono"
  on public.convites for insert
  with check (
    criado_por = auth.uid()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_update_dono"
  on public.convites for update
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  )
  with check (
    criado_por = auth.uid()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_delete_dono"
  on public.convites for delete
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );
```

> **Convite por link é "capacidade":** quem tem o token entra via RPC `aceitar_convite` (security definer, [08 §3.1](08-compartilhamento-colaborativo.md)) — contorna RLS por design, pois o convidado não é dono. O dono revoga com UPDATE direto (`estado = 'revogado'`).

### 4.5. RPC `agora_servidor` (relógio do servidor — F20)

```sql
create or replace function public.agora_servidor()
returns timestamptz language sql stable set search_path = ''
as $$ select now(); $$;

revoke execute on function public.agora_servidor() from public, anon;
grant execute on function public.agora_servidor() to authenticated;
```

> **Por que existe:** a detecção de relógio de dispositivo adiantado compara `ts_local` com o `now()` do **banco** ([03 §5](03-sincronizacao-offline.md), evento 2 de [07 §4](07-qualidade-ci.md)). Não expõe dado algum — só o horário do servidor — e não precisa de `security definer` (não toca tabelas). Migration `0014`.

### 4.6. RPC `transferir_dono` (RF-14, F24)

```sql
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

  -- Só o dono atual transfere.
  if not exists (
    select 1 from public.listas
    where id = p_lista and dono_id = auth.uid()
  ) then
    raise exception 'APENAS_O_DONO_PODE_TRANSFERIR';
  end if;

  -- O destino precisa ser membro (editor/leitor) e ≠ eu.
  if p_novo_dono = auth.uid() then
    raise exception 'NAO_PODE_TRANSFERIR_PARA_SI';
  end if;
  select papel into papel_novo
  from public.lista_membros
  where lista_id = p_lista and user_id = p_novo_dono;
  if papel_novo is null then
    raise exception 'NOVO_DONO_PRECISA_SER_MEMBRO';
  end if;

  -- Libera o trigger sync_dono apenas nesta transação (padrão do excluir_conta).
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
```

> **Nenhuma policy nova:** o RPC é `security definer` (dono `postgres`, migration `0016`) e atravessa o `force row level security` de `lista_membros`, como `aceitar_convite`/`excluir_conta`. A autorização é interna (só o dono da lista) e `listas.dono_id` continua sendo ajustado **só pelo trigger** `sync_dono` ([01 §6](01-banco-de-dados.md)). O `set_config` de namespace customizado não é acessível via PostgREST — clientes não forjam `app.transferindo_dono`. Fluxo e UX em [08 §6](08-compartilhamento-colaborativo.md).

### 4.7. RPCs de convite por e-mail (RF-13, F32)

O convidado por e-mail **não é membro** da lista: o RLS de `convites` só lhe permite SELECT do convite dirigido ao próprio e-mail ([§4.4](#44-convites-fase-6--08-2)) — ele não lê `listas` (para o título) nem faz UPDATE (para recusar). O caminho para o painel e a recusa são RPCs `security definer` (migration `0019`):

```sql
create or replace function public.meus_convites_pendentes()
returns table (
  id uuid, token uuid, lista_titulo text,
  papel_oferecido text, expira_em timestamptz
)
language sql security definer set search_path = public stable
as $$
  select c.id, c.token, l.titulo, c.papel_oferecido, c.expira_em
  from public.convites c
  join public.listas l on l.id = c.lista_id
  where c.tipo = 'email'
    and c.estado = 'pendente'
    and c.expira_em >= now()
    and lower(c.email) = lower(public.email_autenticado())
  order by c.created_at desc
$$;

create or replace function public.recusar_convite(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.convites
  set estado = 'revogado', atualizado_em = now()
  where id = p_id
    and tipo = 'email'
    and estado = 'pendente'
    and expira_em >= now()
    and lower(email) = lower(public.email_autenticado());
  if not found then
    raise exception 'CONVITE_INVALIDO';
  end if;
end;
$$;

revoke execute on function public.meus_convites_pendentes() from public, anon;
revoke execute on function public.recusar_convite(uuid) from public, anon;
grant execute on function public.meus_convites_pendentes() to authenticated;
grant execute on function public.recusar_convite(uuid) to authenticated;
```

> **Nenhuma policy nova:** os dois RPCs são `security definer` (dono `postgres`, migration `0019`) e atravessam o RLS de `convites`, como `aceitar_convite`/`transferir_dono`. A autorização é interna: o filtro `lower(email) = lower(public.email_autenticado())` garante que cada usuário só vê/recusa o convite dirigido ao **próprio** e-mail. O aceite **não** tem RPC novo — reusa `aceitar_convite` (idempotente, [08 §3.1](08-compartilhamento-colaborativo.md)).
> **Guarda de expiração:** as duas funções exigem `expira_em >= now()` — `meus_convites_pendentes` não lista convites vencidos e `recusar_convite` rejeita com `CONVITE_INVALIDO` a recusa de um convite expirado do próprio e-mail (o estado `expirado` nunca é gravado, [08 §2](08-compartilhamento-colaborativo.md)); `recusar_convite` também exige `estado = 'pendente'`, então não "recusa" um convite já aceito.

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
| N-10 | Usuário A insere 2º membro `papel='dono'` na própria lista | violação de policy (`0015`, R-18) ou exceção do trigger `sync_dono` |
| N-11 | Não-membro faz SELECT de convites da lista de outrem | 0 linhas (F7-T01) |
| N-13 | `editor` tenta INSERT de convite | violação de policy (F7-T01) |
| N-14 | `editor` tenta revogar convite (UPDATE) | 0 linhas (policy nega) (F7-T01) |
| N-15 | `editor` tenta mudar papel de outro membro (UPDATE em `lista_membros`) | 0 linhas (F7-T07) |
| N-16 | `editor` tenta remover linha de outro membro (DELETE em `lista_membros`) | 0 linhas (F7-T07) |
| N-17 | Dono tenta promover membro a `dono` via UPDATE | violação de policy (`with check`, F7-T07) |
| N-18 | Dono insere terceiro **sem membresia** como `papel='dono'` | negado — a linha não existe (`0015`, R-18) |
| R-19 | UPDATE em `convites` como dono | `atualizado_em` carimbado pelo trigger (`0015`) |

> N-12 é **positivo** apesar do prefixo N (cobria a leitura legítima dos convites pelo dono) — movido para a tabela "DEVEM passar" abaixo.

Casos que **DEVEM passar**:

| # | Cenário | Expectativa |
| :--- | :--- | :--- |
| P-01 | Dono cria lista + insere a si em `lista_membros` | sucesso |
| P-02 | Dono convida `editor` e `leitor` | sucesso |
| P-03 | `editor` cria/edita/soft-deleta itens | sucesso |
| P-04 | `leitor` lê lista e itens | sucesso |
| P-05 | Realtime entrega eventos apenas das listas do usuário | sucesso |
| N-12 | Dono faz SELECT dos convites da própria lista | > 0 linhas (F7-T01) |
| P-06 | Dono muda papel de membro `leitor`→`editor` (UPDATE em `lista_membros`) | 1 linha (F7-T07) |
| P-07 | Membro comum sai da lista (DELETE da própria linha em `lista_membros`) | sucesso (F7-T07) |
| P-08 | INSERT em `listas` cria o membro dono automaticamente | 1 dono (`0010`) |
| P-09 | Dono renomeia lista com >1 lista no banco | 1 linha (F12-T04) |
| P-10 | Dono tenta mudar `listas.dono_id` via UPDATE | violação de policy (F12-T04) |
| P-11 | Dono se insere como `dono` em lista nova | sucesso (`0015`, R-18) |

Ferramentas: testes de integração com dois usuários reais (ver [07 Qualidade](07-qualidade-ci.md)) ou script SQL com `set local role authenticated; set local request.jwt.claims = ...` em ambiente dev.

> **Transferência de dono (RF-14, F24):** coberta por `supabase/tests/transferir_dono_tests.sql` (T-01…T-07) rodado no CI — papéis e `listas.dono_id` após a transferência (editor e leitor viram dono), erros `APENAS_O_DONO_PODE_TRANSFERIR`/`NOVO_DONO_PRECISA_SER_MEMBRO`/`NAO_PODE_TRANSFERIR_PARA_SI`, defesa em profundidade sem a flag (o downgrade direto segue bloqueado) e a cascata de `convites.criado_por` (R-17).

> **Convite por e-mail (RF-13, F32):** coberto por `supabase/tests/convites_email_tests.sql` (CE-01…CE-04 + CE-02b) rodado no CI — `meus_convites_pendentes()` devolve o convite do próprio e-mail (com título e token) e esconde o alheio (CE-01) e o expirado (CE-03); `recusar_convite` revoga só o próprio e rejeita o alheio com `CONVITE_INVALIDO` (CE-02); a **guarda de expiração** rejeita a recusa de um convite vencido do próprio e-mail (CE-02b); `anon` não executa os RPCs — grant restrito a `authenticated` (CE-04).

---

## 6. Checklist de validação (Fase 1)

- [ ] `force row level security` aplicado em todas as tabelas.
- [ ] Todos os casos de negação (N-01…N-17; N-12 é positivo — ver §5) falham como esperado.
- [ ] Todos os casos positivos (P-01…P-07, exceto P-05 Realtime) passam.
- [ ] Policies versionadas na migration `0002_rls_policies.sql`.
- [ ] Realtime recebe apenas eventos autorizados (teste com 2 contas).

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — schema protegido por estas policies
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — escritas do sync passam pelas mesmas policies
- [07 Qualidade & CI](07-qualidade-ci.md) — como os testes de negação rodam no CI
