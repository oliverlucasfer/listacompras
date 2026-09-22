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

### 2.7. Auth → URL Configuration (web + nativo)

Dashboard Supabase → **Authentication → URL Configuration** (ADR-012, [05 §2.1](05-app-flutter.md)). Necessário para o cadastro (verificação de e-mail), a recuperação de senha e o link de convite funcionarem no web:

| Campo | Valor |
| :--- | :--- |
| **Site URL** | Produção: `https://<domínio>` · Dev: `http://localhost:<porta>` |
| **Redirect URLs** | `http://localhost:<porta>/**` (dev) e `https://<domínio>/**` (produção) |
| **Nativo (manter)** | `br.com.oliverlucas.listacompras://login-callback` |

O web usa `<origem>/login-callback` (http em dev, https em produção) como `redirectTo` de auth ([05 §2.1](05-app-flutter.md)); o `/**` cobre também `/entrar` (convite). Sem a URL na whitelist, o Supabase recusa o `redirectTo` ("redirect_uri not allowed") e o link de confirmação cai na Site URL errada.

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
