# Frente — Transferência de Dono (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 7)
> **Fase:** 24 · **Requisito:** RF-14 (transferência de dono)
> **Docs donos:** [01](../01-banco-de-dados.md) (schema/trigger), [02](../02-seguranca-rls.md) (RPC/policies),
> [08 §6](../08-compartilhamento-colaborativo.md) (fluxo), [05](../05-app-flutter.md) (UI),
> [10](../10-wireframes-telas.md) (layout), [06 §3.3.1](../06-mvp-entregas.md) (R-17), [12](../12-prd.md), [14](../14-tarefas.md)

---

## 1. Motivação

Hoje o dono **não consegue sair da lista**: o trigger `sync_dono` ([01 §6](../01-banco-de-dados.md)) impede
remover/rebaixar o único `papel='dono'`, e a policy de `listas` torna `dono_id` imutável por UPDATE. O doc
[08 §6](../08-compartilhamento-colaborativo.md) já desenhou a transferência (RPC `transferir_dono` + ajuste do
trigger), mas a rodada link-only adiou a entrega (RF-14).

Consequências de não existir: um casal que se separa, ou quem passa a lista para outra pessoa, fica preso — só
resolve excluindo a conta. A transferência fecha o último buraco de colaboração do MVP.

A operação é **entre usuários** e precisa ser atômica no servidor: **online-only**. Diferente das demais escritas
do app, não passa pelo Drift/fila (papéis não vivem no Drift — [08 §4](../08-compartilhamento-colaborativo.md)).

## 2. Escopo

**Dentro:**
- RPC `transferir_dono(p_lista, p_novo_dono)` + `sync_dono` v3 com a flag `app.transferindo_dono` (migration `0016`).
- UI: "Transferir dono" no menu do membro (só dono) com confirmação dupla; após o sucesso o ex-dono vira editor.
- Realtime: SnackBar genérico ao **novo dono** ("Você agora é dono de uma lista").
- **R-17:** FK `convites.criado_por` passa a `on delete cascade` (a transferência torna o risco real).

**Fora (frentes seguintes):** convite por e-mail (RF-13, fluxo B), notificações push, transferência a não-membro,
transferência por proposta/aceite (o destino é promovido imediatamente).

## 3. Banco — migration `0016_transferir_dono.sql`

### 3.1. RPC `transferir_dono`

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

  -- Libera o trigger apenas nesta transação (padrão da exclusão de conta).
  perform set_config('app.transferindo_dono', 'true', true);

  -- Ordem importa: demove o antigo ANTES de promover o novo, para o contador
  -- de "1 dono" do trigger nunca ver dois donos simultâneos.
  update public.lista_membros set papel = 'editor'
  where lista_id = p_lista and user_id = auth.uid();

  update public.lista_membros set papel = 'dono'
  where lista_id = p_lista and user_id = p_novo_dono;
end;
$$;

revoke execute on function public.transferir_dono(uuid, uuid) from public, anon;
grant execute on function public.transferir_dono(uuid, uuid) to authenticated;
```

- **`listas.dono_id` NÃO é atualizado pelo RPC**: o trigger `sync_dono` já o faz ao ver `new.papel = 'dono'`
  ([01 §6](../01-banco-de-dados.md)) — fonte única da denormalização. Isso evita depender da policy de UPDATE de `listas`
  (que bloqueia `dono_id` imutável) e mantém o invariante num só lugar.
- É `security definer` (dono `postgres`), como `aceitar_convite`/`excluir_conta`, então atravessa o
  `force row level security` das tabelas.

### 3.2. `sync_dono` v3

Só muda a exceção que libera o downgrade do dono — passa a aceitar também a flag da transferência:

```sql
  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    if coalesce(current_setting('app.excluindo_conta', true),  '') <> 'true'
       and coalesce(current_setting('app.transferindo_dono', true), '') <> 'true' then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;
```

O restante do trigger (bloqueio de 2º dono e atualização de `dono_id`) fica igual.

### 3.3. R-17 — cascata de `convites.criado_por`

```sql
alter table public.convites drop constraint convites_criado_por_fkey;
alter table public.convites
  add constraint convites_criado_por_fkey
  foreign key (criado_por) references auth.users(id) on delete cascade;
```

Sem isso, depois de transferir, o ex-dono com convites criados não consegue excluir a conta (FK sem cascade).
Com a cascata, os convites que ele criou somem junto com a conta.

## 4. App

### 4.1. Repositório (`ConvitesRepository.transferirDono`)

```dart
Future<void> transferirDono({required String listaId, required String novoDonoId});
```

Chama `rpc('transferir_dono', params: {'p_lista': listaId, 'p_novo_dono': novoDonoId})` (online-only, como
`criarLink`/`aceitar`). Erros viram `ErroConvite` com mensagem amigável:
- `APENAS_O_DONO_PODE_TRANSFERIR` → `AppStrings.transferirApenasDono`;
- `NOVO_DONO_PRECISA_SER_MEMBRO` / `NAO_PODE_TRANSFERIR_PARA_SI` → `AppStrings.transferirDestinoInvalido`;
- rede → `sem_conexao` → `AppStrings.erroSemConexao` / `AppStrings.transferirSemConexao`.

### 4.2. Tela de membros (`tela_membros_screen.dart`)

- No `PopupMenuButton` de cada membro, quando `_eDono` e o alvo **não é** o próprio usuário: novo item
  **"Transferir dono"** (`AppStrings.transferirDono`).
- Ação: **confirmação dupla** — `AppDialog.confirmarDestrutivo` com o título "Transferir dono?" e a mensagem
  de que o usuário **deixará de ser dono e passará a editor** (o texto deixa claro que ele poderá sair depois).
- Sucesso: `ref.read(papelRepositoryProvider).atualizar(listaId, Papel.editor)`,
  `ref.invalidate(membrosDaListaProvider(listaId))`, SnackBar `AppStrings.donoTransferido`. Como o usuário vira
  editor, o botão "Sair da lista" passa a aparecer (a policy já permite sair de lista onde não é dono).
- Falha: SnackBar com a mensagem do `ErroConvite` (ex.: `transferirSemConexao`).

### 4.3. Realtime — aviso ao novo dono

Espelha o padrão do "membro entrou" (F7-T07):

- `PapelRepository` ganha `ValueNotifier<String?> donoTransferido` + `notificarDono(String listaId)` /
  `consumirDono()` (limpo no `limpar()`).
- `aplicarEventoMembro` (`papel_realtime.dart`): no `update` em que `user_id == usuarioAtual`, após atualizar o
  papel, se `newRecord['papel'] == 'dono'` e `oldRecord['papel'] != 'dono'`, chama `notificarDono(listaId)`.
  O `update` de `lista_membros` já chega completo (a tabela tem `replica identity full`, migration `0008`).
- `tela_lista_screen.dart` escuta `donoTransferido` (como faz com `membroEntrou`) e mostra o SnackBar
  `AppStrings.voceAgoraDono` ("Você agora é dono de uma lista" — sem nome; o RLS não expõe perfis).

### 4.4. Strings novas (`AppStrings`)

`transferirDono`, `transferirDonoTitulo`, `transferirDonoMensagem`, `donoTransferido`, `transferirApenasDono`,
`transferirDestinoInvalido`, `transferirSemConexao`, `voceAgoraDono`.

## 5. Testes

**SQL (`supabase/tests/transferir_dono_tests.sql`, rodado no CI como os demais):**
- T-01: dono transfere para membro `editor` → papéis trocam (`antigo=editor`, `novo=dono`) e `listas.dono_id = novo`.
- T-02: dono transfere para membro `leitor` → idem (leitor vira dono).
- T-03: não-dono tenta → `APENAS_O_DONO_PODE_TRANSFERIR`.
- T-04: destino sem membership → `NOVO_DONO_PRECISA_SER_MEMBRO`.
- T-05: transferir para si → `NAO_PODE_TRANSFERIR_PARA_SI`.
- T-06: **sem a flag**, `update` que rebaixa o dono continua lançando "Transferência de dono deve ser processo
  explícito" (defesa em profundidade preservada).
- T-07 (R-17): excluir a conta do ex-dono com convite criado não falha e o convite some (cascade).

**Unit (`test/features/convites/convites_repository_test.dart`, `ServidorFake`):**
- `deve_chamar_rpc_de_transferencia_quando_transfere` (payload `p_lista`/`p_novo_dono`).
- `deve_mapear_erros_do_contrato_quando_transferir_falha` (`APENAS_*`, `NOVO_DONO_*`, `NAO_PODE_*`).
- `deve_retornar_sem_conexao_quando_transferir_offline`.

**Realtime (unit, padrão de `papel_repository_test.dart`):**
- update de si para `dono` → `donoTransferido` sinalizado; update para `editor` não sinaliza.

**Widget (`test/features/convites/tela_membros_screen_test.dart`):**
- item "Transferir dono" aparece só para dono e não no próprio usuário;
- confirmação dupla (cancelar não chama o RPC);
- sucesso: chama o RPC, atualiza o papel local e mostra SnackBar; "Sair da lista" passa a aparecer.

**CI:** adicionar `transferir_dono_tests.sql` ao job `supabase` do `.github/workflows/ci.yml` e ao esqueleto do
[07 §3](../07-qualidade-ci.md).

## 6. Decisões registradas (21/09/2026)

1. RPC + flag no trigger (Abordagem A); `listas.dono_id` continua sendo ajustado **só pelo trigger**.
2. **Online-only** — papel não passa pelo Drift; offline → erro amigável.
3. R-17: `convites.criado_por` → `on delete cascade`.
4. Destino precisa ser **membro** existente; promovido imediatamente (sem aceite).
5. Ex-dono vira **editor** e pode sair da lista em seguida (policy já permite).
6. Aviso ao novo dono por **SnackBar via Realtime** (genérico, sem nome), no padrão do "membro entrou".
7. Fase **24**, requisito **RF-14**. Sem ADR novo (segue decisão de [01 §6](../01-banco-de-dados.md)/[08 §6](../08-compartilhamento-colaborativo.md)).

## 7. Documentos relacionados
- [01 Banco de Dados](../01-banco-de-dados.md) — trigger `sync_dono` v3 e cascata (R-17)
- [02 Segurança RLS](../02-seguranca-rls.md) — RPC e matriz de policies
- [08 Compartilhamento](../08-compartilhamento-colaborativo.md) — fluxo final (§6)
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — UI e layout
- [14 Tarefas](../14-tarefas.md) — Fase 24
