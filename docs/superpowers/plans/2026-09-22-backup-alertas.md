# Fase 34 — Backup Agendado + Alertas do Sentry (RNF-08): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatizar o backup do banco de produção (dump cifrado via GitHub Actions, mensal) e documentar as regras de alerta do Sentry para os eventos 1-2.

**Architecture:** Um workflow agendado faz `supabase db dump` de produção, cifra com `openssl` (AES-256/PBKDF2) e publica o `.enc` como artefato. Nenhum segredo entra no repo (só referências a secrets). Docs donos 09 (backup) e 07 (observabilidade) atualizados.

**Tech Stack:** GitHub Actions · Supabase CLI · `openssl` · Markdown.

**Spec:** `docs/superpowers/specs/2026-09-22-backup-alertas-design.md`

## Global Constraints

- **Nenhum segredo** no repo/CI/logs: só `${{ secrets.SUPABASE_DB_URL }}` e `${{ secrets.BACKUP_PASSPHRASE }}`; nunca `set -x`/`echo` de segredos.
- Sem código de app, sem `lib/`, sem `supabase/migrations/`, sem `docs/01/02/03`.
- Não alterar o `ci.yml` existente (o backup é workflow separado, agendado).
- Uma tarefa = um commit, `F34-Tnn: <resumo>` em pt-BR.
- Gate por tarefa: `dart format . && flutter analyze && flutter test` verdes (nenhum teste novo de app; baseline 589).
- Push/merge só com autorização do dono.

---

### Task 1: Workflow de backup agendado

**Files:**
- Create: `.github/workflows/backup.yml`

**Interfaces:** Consome secrets `SUPABASE_DB_URL`, `BACKUP_PASSPHRASE`; produz o artefato `backup-<YYYYMMDD>` (apenas `*.sql.enc`).

- [ ] **Step 1: Criar o workflow**

`.github/workflows/backup.yml`:

```yaml
# Backup agendado do banco de produção — doc dono: docs/09-runbook-operacoes.md §2.2
# Dump + cifra (AES-256/PBKDF2) + artefato. Requer os secrets do repositório
# SUPABASE_DB_URL e BACKUP_PASSPHRASE (Settings → Secrets and variables → Actions).
name: backup

on:
  schedule:
    - cron: '0 6 1 * *'   # mensal: dia 1 às 06:00 UTC
  workflow_dispatch:        # rodar sob demanda / testar

jobs:
  dump:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: supabase/setup-cli@v3
        with:
          version: 2.116.0  # pinado ao CLI do dev
      - name: Dump do banco de produção
        id: dump
        env:
          SUPABASE_DB_URL: ${{ secrets.SUPABASE_DB_URL }}
        run: |
          if [ -z "$SUPABASE_DB_URL" ]; then
            echo "secret SUPABASE_DB_URL ausente"; exit 1
          fi
          data="$(date +%Y%m%d)"
          echo "data=$data" >> "$GITHUB_OUTPUT"
          supabase db dump --db-url "$SUPABASE_DB_URL" --file "backup_${data}.sql"
      - name: Cifra o dump (AES-256 + PBKDF2)
        env:
          BACKUP_PASSPHRASE: ${{ secrets.BACKUP_PASSPHRASE }}
        run: |
          if [ -z "$BACKUP_PASSPHRASE" ]; then
            echo "secret BACKUP_PASSPHRASE ausente"; exit 1
          fi
          openssl enc -aes-256-cbc -pbkdf2 -salt \
            -pass env:BACKUP_PASSPHRASE \
            -in "backup_${{ steps.dump.outputs.data }}.sql" \
            -out "backup_${{ steps.dump.outputs.data }}.sql.enc"
          rm -f "backup_${{ steps.dump.outputs.data }}.sql"
      - name: Publica o artefato cifrado
        uses: actions/upload-artifact@v4
        with:
          name: backup-${{ steps.dump.outputs.data }}
          path: '*.sql.enc'
          retention-days: 90
```

- [ ] **Step 2: Validar sintaxe do YAML**

Run: `Get-Content .github/workflows/backup.yml -Raw | ConvertFrom-Yaml | Out-Null` (se o módulo `powershell-yaml` existir); caso contrário, validar visualmente a indentação e conferir que o arquivo é UTF-8.
Expected: sem erro de parsing. (Não há runner local; a validação real é o `workflow_dispatch` após os secrets — documentado no 09.)

- [ ] **Step 3: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde (589).

```bash
git add .github/workflows/backup.yml
git commit -m "F34-T01: workflow de backup agendado cifrado (RNF-08)"
```

---

### Task 2: Docs donos — backup (09) e observabilidade (07)

**Files:**
- Modify: `docs/09-runbook-operacoes.md` (§2.2)
- Modify: `docs/07-qualidade-ci.md` (§4)

- [ ] **Step 1: doc 09 §2.2 — backup agendado + restore**

Reescrever §2.2 para incluir, mantendo o formato do arquivo:
- **Backup automatizado:** `.github/workflows/backup.yml` roda **mensal** (`0 6 1 * *`, dia 1 às 06:00 UTC) e sob demanda (Actions → *backup* → *Run workflow*); faz `supabase db dump` de produção, **cifra** o `.sql` e publica o artefato `backup-YYYYMMDD` (retenção 90 dias).
- **Secrets necessários** (cadastrar em Settings → Secrets and variables → Actions; nunca no repo): `SUPABASE_DB_URL` (connection string do Postgres de produção) e `BACKUP_PASSPHRASE`.
- **Restore a partir do artefato** (baixar `backup_YYYYMMDD.sql.enc`):
  ```bash
  openssl enc -d -aes-256-cbc -pbkdf2 -pass env:BACKUP_PASSPHRASE \
    -in backup_YYYYMMDD.sql.enc -out backup_YYYYMMDD.sql
  psql "$DATABASE_URL" -f backup_YYYYMMDD.sql
  ```
- Manter o **dump manual** (`supabase db dump --file ...`) como **fallback** e a rotina mínima (antes de migration destrutiva).

- [ ] **Step 2: doc 07 §4 — regras de alerta do Sentry**

Após a lista "Eventos mínimos monitorados", acrescentar a subseção **"Regras de alerta (Sentry)"** com a tabela (mantendo o formato do arquivo):

| Regra (Issue Alert) | Evento/tag | Condição | Severidade |
| :--- | :--- | :--- | :--- |
| Fila travada | `sync_falha_fila_grande` (`fila`) | `fila > 10` | Error |
| Muitas tentativas | `sync_falha_tentativas_altas` (`tentativas`) | `tentativas > 5` | Error |
| Relógio divergente | `sync_relogio_adiantado` (`atraso_horas`) | `atraso_horas > 24` | Warning |

Mais uma linha: passos no dashboard (Alerts → Create Alert → Issues; filtrar por mensagem/tag; canal **e-mail** do dono); nota de que os três eventos já são emitidos pelo Sync Engine e os códigos/tags vêm de `lib/features/sync/providers/sync_providers.dart` (`Sentry.captureMessage` + `setTag`); `sync_falha_tentativas_altas` é o único sem teste unitário (follow-up).

- [ ] **Step 3: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/09-runbook-operacoes.md docs/07-qualidade-ci.md
git commit -m "F34-T02: docs donos - backup agendado e alertas sentry (RNF-08)"
```

---

### Task 3: Fechamento — tarefas (14) e roadmap (16)

**Files:**
- Modify: `docs/14-tarefas.md`
- Modify: `docs/16-roadmap-pos-mvp.md`

- [ ] **Step 1: doc 14 — Fase 34**
  - Bloco `## Fase 34 — Backup agendado + alertas do Sentry` com `Spec: docs/superpowers/specs/2026-09-22-backup-alertas-design.md · Requisito: RNF-08 · Docs donos: 07, 09`, e F34-T01…T03 `[x]` com `Dep:`/`Docs:`/`CP:` no mesmo estilo da F33.
  - Tabela "Progresso por fase": `| F34 Backup + alertas | 3 | 3 |` e total `| **Total** | **177** | **175** |`.

- [ ] **Step 2: doc 16 — C3 concluído**
  - Linha C3 → `concluído (F34-T01…T03) — backup mensal cifrado via GitHub Actions (`backup.yml`); regras de alerta do Sentry (eventos 1-2) documentadas`, no mesmo estilo de C2.

- [ ] **Step 3: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F34-T03: fechamento da Fase 34 (RNF-08)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 backup → T01 (+09 em T02); §4 alertas → T02 (07); §5 docs donos → T02/T03; §6 verificação → T01 Step 2 + gate em todas.
- **Placeholders:** nenhum "TBD"; YAML e trechos de doc completos.
- **Consistência:** progresso 174→177 / 172→175; nenhum arquivo compartilhado entre tarefas (T01 só workflow; T02 docs 07+09; T03 docs 14+16).
- **Segurança:** nenhum segredo no repo; apenas referências a secrets + guards de ausência.
