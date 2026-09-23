# B3 — Notificações push de convite e entrada (RF-30) (design)

> **Status:** aprovado em 23/09/2026 (decisões na Seção 8)
> **Fase:** 38 · **Requisito:** RF-30 (novo) · **ADR:** ADR-014 · **Doc dono:** [08](../08-compartilhamento-colaborativo.md), [09](../09-runbook-operacoes.md), [01](../01-banco-de-dados.md), [02](../02-seguranca-rls.md), [05](../05-app-flutter.md), [12](../12-prd.md)
> **Onda B (B3):** fecha a colaboração prometida no [08 §7](../08-compartilhamento-colaborativo.md) ("sem push notifications no MVP").

---

## 1. Motivação

Hoje a descoberta de convites e de novos membros depende de o usuário **abrir o app**:
o painel "Convites pendentes" ([08 §4](../08-compartilhamento-colaborativo.md)) é fetch-on-open
e o aviso de "membro entrou" é um SnackBar na lista já aberta ([08 §7](../08-compartilhamento-colaborativo.md)).
Quem não abre o app não sabe que foi convidado nem que alguém entrou numa lista sua.
O B3 leva esses dois eventos até o aparelho via **notificação push**.

## 2. Escopo

**Dentro:**
- Dois eventos: **convite por e-mail recebido** (RF-13, fluxo B) e **novo membro numa lista sua**.
- Tabela `push_tokens` (Postgres + RLS) e registro do token no app.
- Edge Function `enviar-push` (Deno) + triggers no banco (`pg_net`) para disparar o envio.
- Permissão contextual + toggle "Notificações" em Configurações.
- Deep link no toque (abre `/entrar?token=…` ou `/lista/:id`).
- RF-30 no doc 12, docs donos (08/09/01/02/05), ADR-014 e Fase 38.

**Fora:**
- iOS/APNs (Onda E — depende de conta Apple Developer) e Web/Desktop (Web é local, ADR-013).
- Outros eventos de lista (remoção, mudança de papel, transferência de dono, lista excluída/arquivada).
- Preferências por evento, horário de silêncio, histórico/caixa de notificações, notificação rica/imagem.
- Envio automático de e-mail de convite (RF-13 continua adiado, [08 §4](../08-compartilhamento-colaborativo.md)).
- Garantia de entrega/retry (ver §7 riscos).

## 3. Arquitetura (visão geral)

```
[dono cria convite por e-mail]                      [membro aceita convite]
        │ INSERT convites (tipo=email,pendente)              │ INSERT lista_membros (papel<>dono)
        ▼                                                     ▼
   trigger notificar_push() ── pg_net net.http_post ──► Edge Function `enviar-push`
                                                              │ valida segredo do webhook
                                                              │ resolve destinatário(s)
                                                              │ lê tokens (service_role)
                                                              ▼
                                                        FCM HTTP v1 ──► aparelho do destinatário
```

O app **nunca** envia para o outro aparelho; o disparo é **server-side**, a partir do banco
(Abordagem A, decidida em 23/09/2026). Configuração fora do repositório é evitada: triggers e
function são versionados.

## 4. Banco: `push_tokens` + triggers

### 4.1. Tabela `push_tokens` (migration `0021`, doc dono 01)

```sql
create table public.push_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  token         text not null unique,
  plataforma    text not null default 'android' check (plataforma in ('android','ios')),
  atualizado_em timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index idx_push_tokens_user on public.push_tokens (user_id);
```

- `token unique` + RPC `registrar_push_token(p_token, p_plataforma)` (`security definer`): quando
  outro usuário loga no mesmo aparelho, o token é **reatribuído** (`user_id` muda), nunca duplicado.
  O RPC apaga a linha do token que pertença a outro usuário e faz o upsert para `auth.uid()`
  (owner-only RLS tornaria um upsert direto impossível).
- `on delete cascade` em `user_id`: a exclusão de conta (RF-11) apaga os tokens.
- **Sem** publication (não precisa de Realtime) e **sem** entrada no Drift (device-only, online,
  como o papel em `papel_repository.dart`).

### 4.2. RLS de `push_tokens` (doc dono 02)

- SELECT/INSERT/UPDATE/DELETE permitidos apenas quando `user_id = auth.uid()`.
- O usuário **nunca** lê token de terceiros.
- A Edge Function usa `service_role` (bypassa RLS) **somente** para resolver os tokens dos
  destinatários do evento.
- Testes de negação adicionados ao [02 §5](../02-seguranca-rls.md) (N-19…N-22, incluindo a
  negação de execução do RPC a `anon`) e um positivo de reatribuição (P-12, via RPC).

### 4.3. Triggers (migration `0022`, doc dono 01)

- `create extension if not exists pg_net;` (disponível no Supabase).
- Função `public.notificar_push()` `security definer`: faz `net.http_post` para a Edge Function
  com o corpo `{evento, registro}` e o segredo do webhook no header. **URL e segredo são lidos do
  Vault** (nunca hardcoded).
- `AFTER INSERT ON public.convites` quando `tipo = 'email' AND estado = 'pendente'` →
  evento `convite_email_criado`.
  - `criarConviteEmail` (F32) **reusa/atualiza** convite pendente; só o INSERT notifica, o UPDATE
    do papel não — sem spam.
- `AFTER INSERT ON public.lista_membros` quando `papel <> 'dono'` → evento `membro_entrou`.
  - Exclui a linha do dono que o trigger de criação de lista insere
    ([01 §6](../01-banco-de-dados.md)), senão notificaria ao criar qualquer lista.
  - O aceite idempotente (`on conflict do nothing`) não gera INSERT → não notifica de novo.

## 5. Edge Function `enviar-push` (Deno)

Pasta nova `supabase/functions/enviar-push/` (a `parse-lista` foi removida na F17; esta é a
primeira function desde então).

1. **Autenticação:** valida o segredo compartilhado no header (Vault). Ausente/errado → `401`.
2. **Destinatários:**
   - `convite_email_criado`: o `user_id` do e-mail do convite (via `auth.users`), **ignorando** o
     próprio autor. E-mail sem conta → não envia (o painel de pendentes cobre depois).
   - `membro_entrou`: o **dono** da lista.
3. **Tokens:** lê `push_tokens` dos destinatários (`service_role`).
4. **Envio:** FCM HTTP v1 com a **service account JSON** em secret. Secret ausente → **no-op**
   (mantém local/dev/testes funcionando sem credencial).
5. **Limpeza:** resposta `UNREGISTERED`/`INVALID_ARGUMENT` do FCM → **remove** a linha de
   `push_tokens`.
6. **Conteúdo (decidido 23/09/2026):** inclui o **título da lista**.
   - Convite: "Você recebeu um convite para 'Compras da Semana'".
   - Entrada: "Um novo membro entrou em 'Compras da Semana'".
   - Sem nome de pessoa (o RLS não expõe perfis). Nenhum item/conteúdo de lista no payload.
   - Payload `data`: `{tipo, lista_id, token?}` (`token` só no convite, para o deep link).

## 6. App (Flutter)

### 6.1. Abstração e plataforma
- Domínio `NotificacoesPush` + impl `NotificacoesPushFirebase` (`firebase_core` +
  `firebase_messaging`) + fake para teste — mesmo padrão de `ReconhecimentoVoz` (F30-T01).
- `notificacoesPushProvider` e `plataformaComPush()`: **Android = true**; iOS entra depois reusando
  a abstração; **Web/Desktop = false**.
- Android: plugin Gradle `google-services` (o `android/app/google-services.json` já está no repo,
  do App Distribution).

### 6.2. Permissão contextual + toggle
- `requestPermission()` dispara **uma vez**, no primeiro momento relevante: **primeira lista criada
  ou primeiro convite aceito** (o que vier primeiro). Nunca pede de novo sozinho.
- Toggle **"Notificações"** em Configurações via `notificacoesAtivasProvider` (local em
  `SharedPreferences`, como tema/onboarding): ligado → pede permissão + registra token; desligado →
  apaga o token (interrompe a entrega). O app não revoga a permissão do SO, apenas para de registrar.

### 6.3. Ciclo do token
- Com permissão concedida: `getToken()` → **upsert** em `push_tokens` (online-only); `onTokenRefresh`
  re-upsert; tentativa idempotente no start do app logado.
- **Logout:** apaga a linha deste dispositivo + `deleteToken()` — evita notificar o próximo usuário
  do mesmo aparelho.

### 6.4. Toque na notificação (deep link)
- `convite_email_criado` → abre `/entrar?token=…` (aceite direto).
- `membro_entrou` → abre `/lista/:id`.
- Ponte para o `go_router` (como o `deeplinkConviteProvider`), cobrindo app aberto
  (`onMessageOpenedApp`) e iniciado pela notificação (`getInitialMessage`).
- **Primeiro plano:** SnackBar (o Realtime já atualiza os dados) — evita a dependência
  `flutter_local_notifications`; em background/terminado o sistema exibe a notificação do payload.

## 7. Testes, rollout e riscos

**Testes (sem FCM real no CI):**
- **Dart unit:** fake de `NotificacoesPush`; registro/refresh/limpeza de token; roteamento do payload
  (convite → `/entrar?token`, membro → `/lista/:id`); `notificacoesAtivasProvider`.
- **Deno unit:** resolução de destinatários, montagem do payload e limpeza de token inválido, com
  `fetch` fake; secret ausente → no-op.
- **SQL:** `push_tokens` (negação N-18…N-20); trigger enfileira em `net.http_request_queue`.
- **Widget:** toggle em Configurações; disparo do prompt contextual.
- **CI:** volta o job Deno (setup-deno + `deno test`) para a function ([07 §3](../07-qualidade-ci.md)).

**Rollout:**
- Migrations `0021`/`0022` → `supabase db reset` (local) e `supabase db push` (produção, aditivas).
- `supabase functions deploy enviar-push`; `supabase secrets set` para a service account do FCM e o
  segredo do webhook; URL e segredo no **Vault** para o trigger.
- App `1.5.0+9` distribuído aos testadores (F5-T05b); smoke com **2 aparelhos** (convite real →
  notificação; entrada → notificação).
- Runbook no [09](../09-runbook-operacoes.md) (secrets, deploy, smoke, rotação de token).

**Riscos / operação externa (documentar no 09):**
- Habilitar a API **FCM/Cloud Messaging** e gerar a **service account** no console do Firebase
  (ação humana).
- `pg_net` é assíncrono e **sem retry**: falha da function perde a notificação (aceitável; limite
  documentado).
- Dispositivo precisa de **Google Play Services**.
- Tokens obsoletos acumulam se o FCM não os marcar como inválidos; limpeza no envio (§5, item 5) e
  no logout (§6.3) mitigam.

## 8. Decisões registradas (23/09/2026)

1. **Escopo:** apenas **convite por e-mail recebido** e **novo membro numa lista sua**.
2. **Abordagem A:** trigger Postgres + `pg_net` → Edge Function versionada (não webhook de dashboard,
   não envio pelo cliente).
3. **Provider:** **FCM HTTP v1**, reusando o projeto Firebase `lista-compras-34f93`; **Android agora**,
   iOS depois, Web/Desktop fora.
4. **Permissão contextual** (primeira lista criada ou primeiro convite aceito) + **toggle** em
   Configurações.
5. **Conteúdo:** inclui o **título da lista**; sem nome de pessoa; sem conteúdo de itens.
6. **Deep link:** convite → `/entrar?token=…`; entrada → `/lista/:id`; **SnackBar** em foreground.
7. Novo requisito **RF-30**; Fase **38**; **ADR-014** (push via FCM, Android-first).

## 9. Documentos relacionados
- [08 Compartilhamento](../08-compartilhamento-colaborativo.md) §4/§7 · [09 Runbook](../09-runbook-operacoes.md) §2
- [01 Banco de Dados](../01-banco-de-dados.md) · [02 Segurança RLS](../02-seguranca-rls.md) §5
- [05 App Flutter](../05-app-flutter.md) · [12 PRD](../12-prd.md) (RF-30)
- [14 Tarefas](../14-tarefas.md) (Fase 38) · [16 Roadmap](../16-roadmap-pos-mvp.md) (Onda B, B3)
