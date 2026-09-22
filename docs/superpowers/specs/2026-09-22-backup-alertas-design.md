# C3 — Backup Agendado + Alertas do Sentry (design)

> **Status:** aprovado em 22/09/2026 (decisões na Seção 7)
> **Fase:** 34 · **Requisito:** RNF-08 (robustez/observabilidade)
> **Docs donos:** [07](../07-qualidade-ci.md) (observabilidade/CI), [09](../09-runbook-operacoes.md) (backup/operações), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

O free tier do Supabase tem backups automáticos limitados e o runbook só cobre **dump manual** ([09 §2.2](../09-runbook-operacoes.md)). Os eventos de observabilidade do Sync Engine (doc 07 §4) já são emitidos e testados, mas **não há regra de alerta** documentada — um erro em produção só seria visto ao abrir o Sentry. Esta frente fecha as duas lacunas: **backup automatizado** e **alertas documentados**.

## 2. Escopo

**Dentro:**
- Workflow agendado `.github/workflows/backup.yml` (dump de produção + cifra + artefato).
- Regras de alerta do Sentry (eventos 1-2) documentadas no doc 07 §4.
- Docs donos: 09 §2.2 (backup agendado + restore), 07 §4 (alertas), 14, 16.

**Fora:**
- Sem código de app, sem migrations, sem RLS/sync, sem RF novo.
- Sem segredos no repo/CI (apenas **referências** a secrets do GitHub).
- Sentry *config-as-code* (Terraform/provider): fora — o dashboard não vive no repo.

## 3. Backup agendado (GitHub Actions)

`.github/workflows/backup.yml`:

- **Gatilhos:** `schedule: '0 6 1 * *'` (mensal, alinhado ao doc 09) + `workflow_dispatch` (rodar sob demanda e testar).
- **Job** (`ubuntu-latest`, `permissions: contents: read`): preflight dos secrets → `supabase/setup-cli@v3` (versão pinada ao CLI do dev) → **dump** (schema + dados) → **validação de conteúdo** → **cifra** → `actions/upload-artifact@v4`. Sem `actions/checkout` (o job apenas dumpa um banco remoto).
- **Dump (dois arquivos):** `supabase db dump --db-url "$SUPABASE_DB_URL" -f "backup_<data>_schema.sql"` e `supabase db dump --db-url "$SUPABASE_DB_URL" -f "backup_<data>_data.sql" --data-only --use-copy` — **schema e dados** do app (o dump padrão é só schema).
- **Validação de conteúdo:** falha o job se o arquivo de dados estiver ausente/vazio ou sem `COPY`/`INSERT INTO` — um dump schema-only não passa.
- **Limitação (schemas gerenciados):** o `supabase db dump` exclui `auth`, `storage` e schemas de extensão — **`auth.users` (contas) não entra no dump**; ao restaurar num projeto/target novo, recrie o projeto e os usuários pelo procedimento padrão do Supabase.
- **Cifra (obrigatória):** `openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:BACKUP_PASSPHRASE` sobre cada `backup_<data>_*.sql` → `.enc`; o `.sql` cru é removido e **nunca** enviado.
- **Artefato:** nome `backup-YYYYMMDD`, `retention-days: 90`, path `*.sql.enc` (os dois arquivos cifrados).
- **Secrets (cadastrados pelo dono no GitHub; nunca no repo):** `SUPABASE_DB_URL` (connection string do Postgres de produção) e `BACKUP_PASSPHRASE`.
- **Higiene:** nunca `set -x`, nunca `echo` de segredos; o GitHub mascara os secrets.

**Restore (documentado no 09 §2.2):** baixar os dois arquivos `.enc` → `openssl enc -d -aes-256-cbc -pbkdf2 -pass env:BACKUP_PASSPHRASE -in backup_<data>_schema.sql.enc -out backup_<data>_schema.sql` (e idem para `_data`) → `psql "$SUPABASE_DB_URL" --single-transaction --variable ON_ERROR_STOP=1 -f backup_<data>_schema.sql` **e depois** `-f backup_<data>_data.sql` (schema primeiro, dados depois; projeto novo ou mesmo projeto). O dump manual (`supabase db dump`) permanece como **fallback**.

## 4. Alertas do Sentry (eventos 1-2)

Os três eventos já são emitidos pelo Sync Engine com tags de contexto (`sync_providers.dart` → `Sentry.captureMessage` + `setTag`) e testados (`test/features/sync/sync_engine_test.dart`). Falta a **regra de alerta** — documentada no doc 07 §4:

| Regra (Issue Alert) | Evento/tag | Condição | Severidade |
| :--- | :--- | :--- | :--- |
| Fila travada | `sync_falha_fila_grande` (`fila`) | `fila > 10` | Error |
| Muitas tentativas | `sync_falha_tentativas_altas` (`tentativas`) | `tentativas > 5` | Error |
| Relógio divergente | `sync_relogio_adiantado` (`atraso_horas`) | `atraso_horas >= 24` | Warning |

- Passos no dashboard Sentry (Alerts → Create Alert → Issues): filtrar por mensagem/tag, severidade e canal (**e-mail** do dono).
- Nota: `sync_falha_tentativas_altas` é o único dos três sem teste unitário hoje — fora do escopo desta frente (follow-up).

## 5. Documentos donos no mesmo PR
- `09 §2.2` (backup agendado: o que faz, secrets a cadastrar, cadência, retenção, restore a partir do artefato; dump manual = fallback).
- `07 §4` (regras de alerta do Sentry para os eventos 1-2).
- `14` (Fase 34) e `16` (C3 concluído).

## 6. Verificação
- YAML do workflow válido; job roda com `workflow_dispatch` **após** o dono cadastrar os secrets → artefato `backup-YYYYMMDD` presente e cifrado, com os dois `*.sql.enc` (schema + dados); conferir que o dump de dados contém `COPY`/`INSERT INTO` (o job falha se vier vazio/sem registros).
- Gate de CI inalterado (nenhum teste novo de app); `dart format`/`flutter analyze`/`flutter test` seguem verdes.

## 7. Decisões registradas (22/09/2026)

1. Backup via **GitHub Actions agendado** (nuvem, sem depender da máquina do dev).
2. Credencial: secret `SUPABASE_DB_URL`; artefato **cifrado** com `BACKUP_PASSPHRASE` (LGPD — o dump contém e-mails/IDs).
3. **Mensal** (`0 6 1 * *`), retenção de artefato **90 dias**.
4. Alertas do Sentry: **documentados** (não config-as-code).
5. Fase **34**; sem ADR novo; sem RF novo.

## 8. Documentos relacionados
- [09 Runbook de Operações](../09-runbook-operacoes.md) — backup/restore, monitoramento
- [07 Qualidade & CI](../07-qualidade-ci.md) — observabilidade (Sentry)
- [14 Tarefas](../14-tarefas.md) — Fase 34 · [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda C (C3)
