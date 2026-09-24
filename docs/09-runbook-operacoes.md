# 09 — Runbook de Operações

> Navegação: [← 08 Compartilhamento](08-compartilhamento-colaborativo.md) · [10 Wireframes →](10-wireframes-telas.md)

**Este documento é o dono dos procedimentos operacionais** pós-lançamento: incidentes, manutenção do Supabase, migrations, secrets e hotfixes. Guia prático — cada procedimento em passos copiáveis.

---

## 1. Acessos e localização de credenciais

| Recurso | Onde está | Acesso usado para |
| :--- | :--- | :--- |
| Dashboard Supabase | https://supabase.com/dashboard | Banco, auth, logs, backup, billing |
| Service role key | Dashboard Supabase → Settings → API | RPCs admin, exclusão de conta |
| Sentry | https://sentry.io | Erros do app |
| Play Console | https://play.google.com/console | Publicação/rollout Android |

> Nunca colar secrets em issues, chat ou código.

---

## 2. Supabase

### 2.1. Projeto pausado (R-01 — vai acontecer no free tier)

**Sintoma:** app não conecta; API retorna erros de DNS/540; dashboard mostra "Project paused".

**Procedimento:**
1. Dashboard → projeto → botão **Restore project** (leva ~2–5 min).
2. Validar saúde: abrir o app Web, logar, marcar um item em 2 dispositivos.
3. Comunicar usuários se a pausa foi longa (aplicativo volta sozinho ao reconectar — o Sync Engine enfileira tudo, [03](03-sincronizacao-offline.md); dados não se perdem).

**Prevenção:** atividade periódica de qualquer usuário mantém o projeto ativo. Lançamento público → **upgrade para Pro** (gatilho ADR-007, [00 §4](00-visao-geral.md)).

### 2.2. Backup e restore

* **Free tier:** backups automáticos limitados; o banco é pequeno, mas **não confie só nisso**.
* **Backup automatizado** (`.github/workflows/backup.yml`): roda **mensal** (`0 6 1 * *` — dia 1 às 06:00 UTC) e sob demanda (GitHub → **Actions** → *backup* → *Run workflow*). Faz **dois** `supabase db dump` de produção — **schema** (`backup_YYYYMMDD_schema.sql`) e **dados** (`backup_YYYYMMDD_data.sql`, com `--data-only --use-copy`) — valida que o dump de dados tem registros (`COPY`/`INSERT INTO`), **cifra** os dois `.sql` com `openssl` (AES-256 + PBKDF2) e publica o artefato `backup-YYYYMMDD` (apenas os `*.sql.enc`, **retenção 90 dias**). O `.sql` cru nunca é publicado.
* **O que o backup contém:** **schema + dados do app**. O `supabase db dump` **exclui os schemas gerenciados** (`auth`, `storage` e schemas de extensão) — **contas/usuários (`auth.users`) não vão no dump**; ao restaurar num projeto/target novo, recrie o projeto e os usuários conforme o procedimento padrão do Supabase.
* **Secrets necessários** (GitHub → Settings → Secrets and variables → Actions; nunca no repo): `SUPABASE_DB_URL` (connection string do Postgres de produção) e `BACKUP_PASSPHRASE` (senha da cifra). Um preflight no início do job falha explicitamente se algum estiver vazio.
* **Restore a partir do artefato** (baixar `backup_YYYYMMDD_schema.sql.enc` e `backup_YYYYMMDD_data.sql.enc` do run, decifrar e aplicar **schema primeiro, depois os dados**):
  ```bash
  openssl enc -d -aes-256-cbc -pbkdf2 -pass env:BACKUP_PASSPHRASE -in backup_YYYYMMDD_schema.sql.enc -out backup_YYYYMMDD_schema.sql
  openssl enc -d -aes-256-cbc -pbkdf2 -pass env:BACKUP_PASSPHRASE -in backup_YYYYMMDD_data.sql.enc -out backup_YYYYMMDD_data.sql
  psql "$SUPABASE_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f backup_YYYYMMDD_schema.sql
  psql "$SUPABASE_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f backup_YYYYMMDD_data.sql
  ```
* **Dump manual (fallback)** — máquina local com Supabase CLI linkado; use se o workflow falhar ou para conferência. Assim como o automatizado, exige **schema + dados** (o `supabase db dump` sem flags é **schema-only**):
  ```powershell
  $d = Get-Date -Format yyyyMMdd
  supabase db dump --file "backup_${d}_schema.sql"
  supabase db dump --file "backup_${d}_data.sql" --data-only --use-copy
  ```
* Rotina mínima recomendada: o agendamento mensal cobre o ciclo normal; faça um dump manual **antes de qualquer migration destrutiva**.

### 2.3. Monitorar uso e limites

| O quê | Onde | Alerta |
| :--- | :--- | :--- |
| Uso de banco/storage/egress | Dashboard → Reports | > 70% do free tier |
| Realtime (conexões/mensagens) | Dashboard → Realtime | mensagens/mês > 70% |
| Auth users | Dashboard → Auth | — |

### 2.4. Aplicar migrations em produção

```bash
# 1. Sempre testar local antes
supabase db reset

# 2. Gerar diff se o schema mudou fora de migrations (evitar! usar migrations sempre)
supabase db diff -f nome_da_mudanca

# 3. Aplicar em produção
supabase db push
```

**Seed local:** `supabase/seed.sql` popula o banco de desenvolvimento (2 usuários `dev-*@local.test`, 1 lista e 3 itens) — roda **somente** no `db reset`, nunca no `db push`. Para logar no app local, crie o usuário pelo próprio app/Studio: as contas do seed não têm senha utilizável.

**Regra:** nenhuma migration direto no SQL editor do dashboard em produção — tudo via CLI versionado ([01 §2](01-banco-de-dados.md)).

**Rollback:** migrations não têm down automático. Estratégia: criar migration **inversa** nova (`0009_rollback_0008.sql`), testar em local, `db push`. Restaurar backup (2.2) só em caso catastrófico.

### 2.5. Upgrade Supabase Pro (quando disparar)

1. Gatilho: lançamento público próximo OU pausa incomodando usuários ativos.
2. Billing → Upgrade → Pro (~US$ 25/mês): projeto não pausa, backups diários, 8 GB banco.
3. Após upgrade: revalidar Realtime (sem mudança de URL/keys).

### 2.6. Histórico de operações em produção

**2026-09-08 — Provisionamento inicial** (F5-T05b):
- `supabase db push` — migrations 0001–0005 aplicadas (`migration list` local = remote).
- Auth → URL Configuration → Redirect URLs: `br.com.oliverlucas.listacompras://login-callback` (dashboard).
- Validação: anon bloqueado por RLS (`GET /rest/v1/listas` → `200 []`), `RPC excluir_conta` → `401` e e2e real do dono (conta → confirmação por deep link → lista → itens).
- Canal de distribuição de teste: Firebase App Distribution — build `1.0.0+2` para o grupo `testadores` ([06 §4](06-mvp-entregas.md)).
- **Fase 6 (agrupamento por categoria, 08/09/2026):** migration `0006_categorias.sql` em produção (`db push`, aditiva); app `1.1.0+3` (smoke: "E-mail ou senha incorretos." do Auth de produção) distribuído ao grupo `testadores` (App Distribution). Rollout especificado no spec F6 §7 (docs/superpowers/specs).
- **Correção (dono da lista, 11/09/2026):** migration `0010_dono_automatico.sql` aplicada em produção via `db push` — o trigger `trg_listas_cria_dono` cria a associação do dono em `lista_membros` ao inserir a lista e o backfill conserta as listas existentes sem dono membro. Causa do bug: a associação do dono nunca era criada (nem cliente nem banco), então `papel_na_lista()` retornava null (UI tratava o dono como leitor) e o RLS negava escrita de itens. Docs donos [01 §6](01-banco-de-dados.md) e [02 §1/§3](02-seguranca-rls.md).
- **Fases 8–11 + correções (11/09/2026):** design system/refresh visual, redesign de navegação (NavigationBar/Rail), importação local sem IA (RF-16) e correção do dono (migration `0011_dono_repair.sql` em produção, idempotente). App `1.2.0+6` distribuído ao grupo `testadores` (App Distribution): navegação abre lista/membros por `push` sobre o shell (voltar para a aba de origem; fallback para `/listas`/`/compartilhadas` sem pilha) e títulos contextualizados (aba/AppBar "Configurações", `Membros · {título}`, fallback "Lista"). Docs donos [05 §4](05-app-flutter.md), [10 §2/§3](10-wireframes-telas.md).
- **Fase 19 — Publicação Web (17/09/2026, cancelada em 18/09/2026):** a F19-T01 chegou a publicar o build web no Firebase Hosting (projeto `lista-compras-34f93`, site default) em `https://lista-compras-34f93.web.app`. **Por decisão do dono (18/09/2026, ADR-013) o Hosting foi desabilitado** (`firebase hosting:disable`) e **os artefatos de publicação foram removidos do repositório** (`firebase.json`, `.firebaserc`, `web/privacidade.html`, `web/robots.txt`). O Web passa a ser de **uso local**: `flutter run -d chrome` (dev) ou `flutter build web` + servir `build/web`. Reabilitar a publicação seria trabalho novo (reconstruir os artefatos).
- **Fases 12–22 + pendências (21/09/2026):** app **`1.3.0+7`** (bump de `1.2.0+6`) distribuído ao grupo `testadores` (Firebase App Distribution) — busca/filtro de itens (RF-17), remoção da IA, suporte Web/Desktop, correções da revisão (F20), **modo mercado (RF-18)** e **chips de itens frequentes (RF-19)** da F22 e pendências de fechamento (F21: política in-app no cadastro, revogar convites pendentes, Sentry sem `extra`). APK release assinado (keystore de `android/key.properties`) compilado com `--dart-define-from-file=dart_defines_prod.json` (Supabase de produção). Verificado `supabase migration list`: produção com `0001`…`0015` (local = remoto).
- **Fases 23–37 + pendências (22/09/2026):** migrations **`0016`…`0020`** aplicadas em produção (`supabase db push`, todas aditivas: transferência de dono, preço do item, arquivar listas, convites por e-mail e orçamento da lista); app **`1.4.0+8`** (bump de `1.3.0+7`) distribuído ao grupo `testadores` (Firebase App Distribution) — duplicar lista (RF-20), transferência de dono (RF-14), preço/total no carrinho (RF-21), orçamento por lista (RF-28), comparação com a última compra (RF-29), arquivar listas (RF-22), adicionar de outra lista (RF-23), ordem pessoal de categorias (RF-24), quantidades em fração (RF-25), adicionar por voz (RF-26), boas-vindas (RF-27) e convite por e-mail (RF-13). APK release assinado (`android/key.properties`) com `--dart-define-from-file=dart_defines_prod.json`. Verificado `supabase migration list`: produção com `0001`…`0020` (local = remoto).
- **Fase 38 — Notificações push (23/09/2026):** migrations **`0021_push_tokens.sql`** e **`0022_notificar_push.sql`** aplicadas em produção (`supabase db push`, aditivas); Edge Function **`enviar-push`** publicada (`supabase functions deploy enviar-push --no-verify-jwt`); secrets **`PUSH_WEBHOOK_SECRET`** e **`FCM_SERVICE_ACCOUNT`** setados e segredos do Vault **`push_function_url`**/**`push_webhook_secret`** criados (URL `https://smshgctdwxkqbvbdlhud.supabase.co/functions/v1/enviar-push`). Smoke: `POST` sem o segredo → `401 unauthorized` (fail-closed); `POST` com o segredo e um token de teste → `200 {"ok":true,"enviados":0}` com o token inválido removido (valida service account/JWT/OAuth/FCM ponta a ponta no servidor). App **`1.5.0+9`** (release assinado, `dart_defines_prod.json`) distribuído ao grupo `testadores` (Firebase App Distribution, release `1.5.0 (9)`). **Pendente:** smoke real com 2 aparelhos (convite por e-mail → notificação no convidado; entrada → notificação no dono; toque abre a tela certa).
- **`google-services.json` (23/09/2026):** `android/app/google-services.json` **permanece rastreado** —
  a API key Android do Firebase não é segredo por si (é restringível no console por package +
  SHA-1). **Ação de segurança (humana):** no console do Firebase, restringir a API key ao package
  `br.com.oliverlucas.listacompras` e aos SHA-1 de debug/release. Arquivos realmente secretos
  (`dart_defines_prod.json`, `android/key.properties`) seguem fora do git.
- **Fase 39 — Consistência arquitetural (23/09/2026):** fase **interna** (RNF-08), **sem mudança de comportamento** e **sem tocar em `supabase/`**. Vocabulário compartilhado movido para `lib/core/dominio/` (elimina `core → features`), providers de rede para `convites/providers/`, dedup de `emailValido`/`Papel.rotulo`, docs donos atualizados e `.gitignore` corrigido. O Drift subiu para **`schemaVersion 8`** espelhando as barreiras do Postgres (`CHECK`s de `itens_lista`/`listas` + índice único parcial `uq_item_ativo`, com dedup defensivo antes do índice). App **`1.5.0+10`** (release assinado, `dart_defines_prod.json`) distribuído ao grupo `testadores` (Firebase App Distribution, release `1.5.0 (10)`) para exercitar a migração local v7→v8. CI: jobs `flutter`/`desktop` verdes; o job `supabase` falhou por **rate-limit do `ghcr.io`** ao subir o stack local (falha de infraestrutura externa, alheia a esta fase) — rerunar depois. **Nota:** o rerun em 23/09 passou (todos os jobs verdes), fechando o residual.
- **Fase 40 — Editor de item em sheet e margens (23/09/2026):** fase de **UI** (RNF-06), sem tocar em `supabase/`. O editor de item deixou de ser `AlertDialog` e virou **bottom sheet** via `AppSheet.mostrar` (campos em blocos; teclado resolvido por `viewInsets` + scroll), com rodapé `Remover/Cancelar/Salvar` que **não estoura** em 360dp/1× nem em fonte 2× (nested `OverflowBar`). Margens: `IndicadorSync` de 8dp → **16dp** nos três usos (sem padding duplo), literais verticais tokenizados e o token sem uso `horizontalCompacto` removido; `AppDropdown` ganhou o parâmetro aditivo `expandido` (`isExpanded`) e o `web/version.json` foi ressincronizado com o `pubspec`. App **`1.5.0+11`** (release assinado, `dart_defines_prod.json`) distribuído ao grupo `testadores` (Firebase App Distribution, release `1.5.0 (11)`). **Pendente conhecido (fora do escopo):** o botão "Importar lista" estoura a 360dp com fonte 2×.

- **Fase 41 — Flavor Lite (24/09/2026):** fase **sem tocar em `supabase/`** (nenhuma migration, RLS, RPC ou Edge Function nova). O segundo flavor **`lite`** (`br.com.oliverlucas.listacompras.lite`, app Firebase `1:407606670898:android:1dfbf8ce7930a968bbae2b`) roda **100% no aparelho**: sem conta/Supabase, sem convites/membros, sem sync/Realtime e sem push; sessão local fixa com dono **`'local'`**, outbox de mutações **desligada** (a fila não é alimentada), rotas de conta/convite ausentes, abas só "Minhas listas"/"Configurações" e **backup JSON** (exportar/importar com merge por `id` e LWW por `updated_at`) em Configurações. O flavor **`prod`** (`br.com.oliverlucas.listacompras`) permanece **colaborativo e inalterado**. App **`1.5.0+12`** (release assinado, `--dart-define-from-file=dart_defines_prod.json`); APK prod `app-prod-release.apk` **gerado** (não distribuído nesta fase) e Lite `app-lite-release.apk` **distribuído** ao grupo `testadores` (Firebase App Distribution). **Dívidas da fase:** o `file_picker` estava pinado em `10.3.10` (a linha 11.x é incompatível com AGP 9/Built-in Kotlin) — **resolvido na F42** ao trocar por `file_selector`; e o import de backup passou a **alimentar a fila** no modo colaborativo ([03 §3](03-sincronizacao-offline.md), [16](16-roadmap-pos-mvp.md)). iOS do Lite segue como follow-up **adiado por decisão** (Onda E, [16](16-roadmap-pos-mvp.md)).

- **Correção da F42 (24/09/2026):** o `1.5.0 (12)` distribuído como "Lite" era, na verdade, **o app colaborativo** com o pacote `.lite` — o flavor sozinho não seleciona o modo Dart. Corrigido com `-t lib/main_lite.dart` nos comandos de build/CI ([§2.9](#29-build-e-distribuicao-flavors-prodlite--f41)), uma trava de debug em `bootstrap.dart` e o passo 1 do smoke; o Lite correto foi redistribuído como `1.5.0 (13)`. O import de backup foi validado em emulador de ponta a ponta (seletor abre, `.json` selecionável, lista restaurada com dono local).

### 2.7. Auth → URL Configuration (web + nativo)

Dashboard Supabase → **Authentication → URL Configuration** (ADR-012, [05 §2.1](05-app-flutter.md)). Necessário para o cadastro (verificação de e-mail), a recuperação de senha e o link de convite funcionarem no web:

| Campo | Valor |
| :--- | :--- |
| **Site URL** | Produção: `https://<domínio>` · Dev: `http://localhost:<porta>` |
| **Redirect URLs** | `http://localhost:<porta>/**` (dev) e `https://<domínio>/**` (produção) |
| **Nativo (manter)** | `br.com.oliverlucas.listacompras://login-callback` |

O web usa `<origem>/login-callback` (http em dev, https em produção) como `redirectTo` de auth ([05 §2.1](05-app-flutter.md)); o `/**` cobre também `/entrar` (convite). Sem a URL na whitelist, o Supabase recusa o `redirectTo` ("redirect_uri not allowed") e o link de confirmação cai na Site URL errada.

### 2.8. Notificações push (RF-30, F38)

- **Secrets:** `supabase secrets set PUSH_WEBHOOK_SECRET=... FCM_SERVICE_ACCOUNT='{...json...}'`.
- **Vault (usado pelos triggers):** `select vault.create_secret('<url da function>', 'push_function_url');`
  e `select vault.create_secret('<segredo>', 'push_webhook_secret');`.
- **Deploy:** `supabase functions deploy enviar-push --no-verify-jwt` (a função é chamada
  pelo `pg_net` sem `Authorization`; `verify_jwt = false` em `supabase/config.toml`, alinhado ao
  flag do deploy). A autenticação é o `x-webhook-secret` validado no handler.
- **Operação externa:** habilitar a API FCM/Cloud Messaging e gerar a service account no console do
  Firebase (projeto `lista-compras-34f93`).
- **Smoke:** 2 aparelhos; convidar por e-mail → notificação no convidado; aceitar → notificação no dono;
  tocar → abre a tela. Sem `FCM_SERVICE_ACCOUNT`, a função é no-op (dev/teste).
- **Rotação de token:** tokens inválidos são removidos no envio; tokens do usuário no logout.

### 2.9. Build e distribuição (flavors `prod`/`lite` — F41)

Com flavors, **todo build exige `--flavor`**; o flavor `prod` é o único que liga nuvem, colaboração e push. Para gerar os APKs release de teste (assinados via `android/key.properties` com fallback para debug quando ausente, e com os dart-defines de produção em `dart_defines_prod.json`, que fica **fora do git**):

> **⚠️ O flavor `lite` não seleciona o modo — o entrypoint é que seleciona.** Sem `-t lib/main_lite.dart`, `--flavor lite` empacota o **app colaborativo** com o pacote `.lite` (tela de login, mesmo backend). Isso aconteceu de verdade na F41: o `1.5.0 (12)` distribuído como "Lite" era o app colaborativo. Desde a F42 há uma trava em debug (`bootstrap.dart` compara o pacote com o modo) e o passo 1 do smoke abaixo pega o caso.

```bash
flutter build apk --release --flavor prod --dart-define-from-file=dart_defines_prod.json
# → build/app/outputs/flutter-apk/app-prod-release.apk

flutter build apk --release --flavor lite -t lib/main_lite.dart --dart-define-from-file=dart_defines_prod.json
# → build/app/outputs/flutter-apk/app-lite-release.apk
```

Distribuição ao grupo `testadores` (Firebase App Distribution; projeto `lista-compras-34f93` — o `--app` de cada flavor é o app Android correspondente no console):

```bash
# prod (colaborativo) — app Android `br.com.oliverlucas.listacompras`
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-prod-release.apk \
  --app "<app-id do prod (console do Firebase)>" --groups testadores

# lite (sem conta, 100% local) — app Android `br.com.oliverlucas.listacompras.lite`
# ATENÇÃO: o build acima leva `-t lib/main_lite.dart`; sem isso o APK é o colaborativo.
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-lite-release.apk \
  --app "1:407606670898:android:1dfbf8ce7930a968bbae2b" --groups testadores \
  --release-notes "Versao Lite (RF-31): uso sem conta, 100% no aparelho, com backup exportar/importar."
```

Os dois flavors instalam **lado a lado** (applicationIds distintos).

**Smoke do Lite em device (obrigatório a cada release do flavor):**

1. Abrir o app pelo ícone azul ("Lista de Compras Lite") — deve abrir direto em **Minhas listas**, sem login e sem aba "Compartilhadas". **Se aparecer tela de login, o build está errado** (flavor sem `-t lib/main_lite.dart`): não distribuir e refazer com o entrypoint.
2. Criar uma lista e alguns itens; fechar e reabrir — os dados persistem (100% local).
3. **Configurações → Exportar backup** — o arquivo `backup_<data>.json` deve ser compartilhado/baixado.
4. **Configurações → Importar backup** — escolher um `.json` **real** no seletor do sistema. Este é o ponto que o CI não cobre: confirmar que o seletor **abre** e que o arquivo aparece **selecionável** (o filtro de tipo foi removido justamente para não esconder backup válido; a validação do conteúdo fica no import, que rejeita arquivo inválido com mensagem clara).
5. Importar um arquivo inválido (ex.: um `.txt` renomeado) — deve mostrar a mensagem de backup inválido **sem** alterar os dados.

---

## 3. Incidentes comuns

### 3.1. "Sincronização parou" (usuários reportam listas desatualizadas)

1. Verificar status Supabase (https://status.supabase.com) e se o projeto não está pausado (2.1).
2. Sentry: `syncStatus = Erro` persistente? Erro de auth (token expirado) ou de rede?
3. Testar manualmente: 2 dispositivos, mesma conta, marcar item — verificar < 1s.
4. Se fila travada (mutação com muitas tentativas): checar erros no log do Postgres (violations de RLS/unique) — erro de negócio na fila deve aparecer no `Erro` da UI ([03 §6](03-sincronizacao-offline.md)).

### 3.2. "Meus itens desapareceram"

1. Confirmar que não é tombstone legítimo: `select * from itens_lista where lista_id = '...'` (deletado_em preenchido = remoção válida em algum dispositivo).
2. Checar Sentry por erro de flush no período.
3. Último recurso: restaurar backup (2.2) — **nunca** editar dados de produção manualmente sem backup prévio.

---

## 4. Hotfix do app publicado

**Android (Play Store):**
1. Correção em branch `hotfix/...` a partir da tag de release.
2. CI verde ([07](07-qualidade-ci.md)) + bump de versão (`pubspec.yaml`, patch).
3. Build AAB → Play Console → produção (se rollout aberto) ou teste interno.
4. **Rollout gradual** (10% → 50% → 100%) em correções arriscadas.

**Web:** **sem app publicado** desde 18/09/2026 (ADR-013). Rodar local: `flutter run -d chrome` (dev) ou `flutter build web` + servir `build/web`. Se um dia for reabilitado, o hotfix é: merge → `flutter build web` → `firebase deploy --only hosting`; rollback = redeploy do commit anterior (o Console mantém o histórico).

**Dados/backend:** correções de schema/RLS seguem 2.4.

---

## 5. Checklist mensal de operação

- [ ] Artefato do backup mensal (`backup-YYYYMMDD`, cifrado — schema + dados) baixado e conferido.
- [ ] Uso de quotas Supabase revisado (< 70%).
- [ ] Sentry: issues abertas triadas; sem erro crítico antigo.
- [ ] Migrations locais = produção (`supabase db push --dry-run` vazio).
- [ ] Secrets listados e válidos (`supabase secrets list`).
- [ ] Dependências Flutter/Supabase CLI com atualizações de segurança.

---

## Documentos relacionados
- [00 Visão Geral](00-visao-geral.md) — risco R-01 que este runbook endereça
- [03 Sincronização](03-sincronizacao-offline.md) — diagnóstico de sync parada
- [07 Qualidade & CI](07-qualidade-ci.md) — pipeline exigido antes de qualquer hotfix
