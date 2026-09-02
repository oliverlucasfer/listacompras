# 08 — Compartilhamento Colaborativo (Fase 6)

> Navegação: [← 07 Qualidade & CI](07-qualidade-ci.md) · [09 Runbook →](09-runbook-operacoes.md)

**Este documento é o dono do compartilhamento de listas** — schema de convites, fluxos, papéis e transferência de dono. O schema base (`lista_membros`, papéis) vive em [01](01-banco-de-dados.md); as policies de leitura/escrita base em [02](02-seguranca-rls.md).

Objetivo: transformar a arquitetura que "nasce pronta" no produto colaborativo completo, sem retrabalho no banco existente.

---

## 1. Papéis e permissões

Papéis já definidos no enum de `lista_membros.papel` ([01 §4.2](01-banco-de-dados.md)):

| Ação | `leitor` | `editor` | `dono` |
| :--- | :---: | :---: | :---: |
| Ver lista e itens | ✔ | ✔ | ✔ |
| Marcar/desmarcar itens | ✘ | ✔ | ✔ |
| Criar/editar/soft-deletar itens | ✘ | ✔ | ✔ |
| Reordenar itens | ✘ | ✔ | ✔ |
| Renomear lista | ✘ | ✔ | ✔ |
| Excluir lista (físico) | ✘ | ✘ | ✔ |
| Remover itens fisicamente | ✘ | ✘ | ✔ |
| Convidar/remover membros | ✘ | ✘ | ✔ |
| Transferir dono | ✘ | ✘ | ✔ (só transfere) |
| Excluir a própria participação | ✔ | ✔ | ✘ (ver [01 §4.3](01-banco-de-dados.md) — transferência obrigatória antes) |

**Regra de ouro:** exatamente **um** dono por lista, em qualquer momento (garantido pelo trigger `sync_dono`).

---

## 2. Novo schema: `convites`

```sql
create table public.convites (
  id              uuid primary key default gen_random_uuid(),
  lista_id        uuid not null references public.listas(id) on delete cascade,
  criado_por      uuid not null references auth.users(id),
  token           uuid not null default gen_random_uuid() unique,
  tipo            text not null check (tipo in ('link', 'email')),
  email           text, -- preenchido quando tipo = 'email'
  papel_oferecido text not null check (papel_oferecido in ('editor', 'leitor')),
  estado          text not null default 'pendente'
                    check (estado in ('pendente', 'aceito', 'expirado', 'revogado')),
  expira_em       timestamptz not null default now() + interval '7 days',
  created_at      timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

create index idx_convites_lista on public.convites (lista_id) where estado = 'pendente';
create index idx_convites_email on public.convites (lower(email)) where estado = 'pendente';
```

**Regras:**
* `papel_oferecido` nunca é `'dono'` — transferência de dono é processo separado (Seção 6).
* Convite `link`: quem acessar o token válido entra; convite `email`: só o usuário com aquele e-mail.
* Expiração padrão de 7 dias; dono pode revogar a qualquer momento.
* Um mesmo e-mail com convite `pendente` na mesma lista não gera novo token (reutiliza/atualiza o existente).

### RLS de `convites` (resumo — policy completa pertence ao [02](02-seguranca-rls.md))

| Operação | Quem | Condição |
| :--- | :--- | :--- |
| SELECT | Dono da lista | vê todos os convites dela |
| SELECT | Qualquer usuário autenticado | vê **apenas** convites `email` direcionados ao próprio e-mail |
| INSERT | Dono da lista | `criado_por = auth.uid()` e é dono |
| UPDATE (revogar) | Dono da lista | idem |
| DELETE | Dono | convites antigos/revogados |

> Segurança do token: convite por link é "capacidade" — quem tem o token entra. Por isso: expiração curta, revogação fácil e papel mínimo (`editor` ou `leitor`, nunca implícito `dono`).

---

## 3. Fluxo A — Convite por link

```
[dono] Tela da Lista → Menu → "Convidar"
        │ escolhe papel (editor/leitor) e gera link
        ▼
INSERT convites (tipo='link') ──► link: https://app.../listas/entrar?token=<uuid>
        │ dono compartilha (WhatsApp, e-mail, etc.)
        ▼
[convidado] abre deep link (app instalado) ou web
        │ rota /listas/entrar?token=... ([05 §4](05-app-flutter.md))
        ▼
        ├─ não autenticado → tela de login/registro com contexto "Você foi
        │  convidado para a lista X" → após autenticar, retoma o aceite
        ▼
App chama RPC `aceitar_convite(token)` (Seção 3.1)
        │
        ├─ token válido, pendente, não expirado → INSERT em lista_membros
        │   + convite.estado = 'aceito' → navega para /listas/<id>
        ├─ expirado/revogado → erro amigável
        └─ já é membro → apenas navega para a lista
```

### 3.1. RPC `aceitar_convite`

```sql
create or replace function public.aceitar_convite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.convites%rowtype;
  novo_membro_id uuid;
begin
  select * into c from public.convites
  where token = p_token for update;

  if c.id is null or c.estado <> 'pendente' or c.expira_em < now() then
    raise exception 'CONVITE_INVALIDO';
  end if;

  if c.tipo = 'email' and lower(c.email) <> lower(
      (select email from auth.users where id = auth.uid())) then
    raise exception 'CONVITE_NAO_DIRIGIDO_A_VOCE';
  end if;

  -- idempotente: já sendo membro, apenas marca o convite
  insert into public.lista_membros (lista_id, user_id, papel)
  values (c.lista_id, auth.uid(), c.papel_oferecido)
  on conflict (lista_id, user_id) do nothing;

  update public.convites set estado = 'aceito', atualizado_em = now()
  where id = c.id;

  return c.lista_id;
end;
$$;
```

* **Idempotente:** acessar o link duas vezes não duplica membro nem quebra.
* Concorre com o trigger `sync_dono` sem risco: `papel_oferecido` nunca é `dono`.

## 4. Fluxo B — Convite por e-mail

| Situação | Comportamento |
| :--- | :--- |
| Convidado **já tem conta** | Convite aparece no app ("Convites pendentes" no painel Minhas Listas, alimentado por SELECT nos convites com o próprio e-mail) + opcionalmente e-mail transacional via Edge Function |
| Convidado **não tem conta** | Convite fica `pendente` vinculado ao e-mail; ao se registrar com aquele e-mail, o painel mostra o convite pendente → aceite via mesmo RPC |
| E-mail de usuário já membro | RPC retorna erro amigável "Este usuário já participa" (o dono vê na lista de membros) |

**Envio de e-mail (opcional, Fase 6):** Edge Function `enviar-convite` chamando provedor transacional (Resend/SMTP). Semprovedor definido — decisão adiada; o app cobre o caso via convites pendentes no painel.

## 5. Remoção de membro e revogação

* Dono remove membro: DELETE em `lista_membros` ([02 §4.3](02-seguranca-rls.md) já permite).
* **Itens criados pelo membro removido permanecem na lista** — decisão de produto (o item pertence à lista, não ao autor; não há coluna de autoria em `itens_lista` e o RLS não depende dela).
* Membro removido perde acesso no ato (RLS) e o Realtime derruba seus streams; seu cache local é limpo ao detectar perda de acesso (ou no próximo bootstrap).
* Membro pode **sair voluntariamente** (DELETE da própria linha, exceto dono).
* Revogar convite pendente: dono marca `estado = 'revogado'`; token deixa de ser aceito.

## 6. Transferência de dono (processo explícito)

Hoje o trigger `sync_dono` ([01 §6](01-banco-de-dados.md)) **impede** qualquer mudança de dono. A transferência será a única exceção, via RPC atômico:

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
  -- só o dono atual pode transferir
  if not exists (
    select 1 from public.listas
    where id = p_lista and dono_id = auth.uid()
  ) then
    raise exception 'APENAS_O_DONO_PODE_TRANSFERIR';
  end if;

  select papel into papel_novo from public.lista_membros
  where lista_id = p_lista and user_id = p_novo_dono;

  if papel_novo is null then
    raise exception 'NOVO_DONO_PRECISA_SER_MEMBRO';
  end if;

  -- rebaixa o dono atual para editor e promove o novo — mesma transação
  update public.lista_membros set papel = 'editor'
  where lista_id = p_lista and user_id = auth.uid();

  update public.lista_membros set papel = 'dono'
  where lista_id = p_lista and user_id = p_novo_dono;

  update public.listas set dono_id = p_novo_dono
  where id = p_lista;
end;
$$;
```

**Alteração necessária no trigger `sync_dono`:** permitir execução quando invocada dentro de `transferir_dono` (ex.: variável `current_setting('app.transferindo_dono', true)` setada pelo RPC, que faz o trigger pular os checks). Migration da Fase 6.

**UX da transferência:** dono abre lista de membros → "Transferir dono" → escolhe membro → confirmação dupla explicando que perderá poderes de dono. Novo dono notificado via Realtime.

## 7. Notificações e Realtime (Fase 6)

* **Publicar no Realtime:** `lista_membros` e `convites` passam ao publication (hoje fora — [01 §7](01-banco-de-dados.md)):
  ```sql
  alter publication supabase_realtime add table public.lista_membros;
  alter publication supabase_realtime add table public.convites;
  ```
* Eventos geram feedback na UI: "Fulano entrou na lista", "Você foi removido da lista X", "Novo convite pendente".
* Sem push notifications no MVP da feature (Fase 6); painel de convites pendentes cobre a descoberta.

## 8. UI necessária (complementa [05](05-app-flutter.md))

| Tela/Modal | Conteúdo |
| :--- | :--- |
| Sheet "Convidar" (dono/editor) | Escolha de papel + gerar link (copiar/compartilhar) ou convidar por e-mail |
| Lista de membros | Nome, papel, ações do dono (mudar papel entre editor↔leitor, remover, transferir dono) |
| Banner "Você é leitor" | Lista em modo somente leitura para `leitor` (inputs desabilitados com dica) |
| Painel "Convites pendentes" (Minhas Listas) | Cards: "João convidou você para **Compras da Semana**" → Aceitar/Recusar |
| Rota `/listas/entrar?token=` | Contexto de aceite (autenticado ou pós-login) |

* Wireframes destes componentes: [10 §4](10-wireframes-telas.md).
* Comportamento de roles na UI (desabilitar ações de leitor): [05 §6.3](05-app-flutter.md).

## 9. Checklist de validação (Fase 6)

- [ ] Convite por link: usuário novo e existente entram com sucesso; expirado/revogado rejeitado.
- [ ] Convite por e-mail aparece no painel de pendentes do convidado.
- [ ] `aceitar_convite` é idempotente (2º uso apenas navega).
- [ ] `leitor` vê banner de somente leitura e não consegue editar (RLS + UI).
- [ ] Membro removido perde acesso em < 5s em todos os dispositivos.
- [ ] Itens do membro removido permanecem na lista.
- [ ] Transferência de dono: novo dono tem poderes completos; antigo vira editor; sem duplicidade de donos.
- [ ] Testes de negação das policies de `convites` adicionados ao [02 §5](02-seguranca-rls.md) (N-11…N-14).

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — `lista_membros`, trigger de dono
- [02 Segurança RLS](02-seguranca-rls.md) — policies de membros (e futuras de `convites`)
- [05 App Flutter](05-app-flutter.md) — rota de deep link e comportamento de roles
- [10 Wireframes](10-wireframes-telas.md) — modais de convite e membros
