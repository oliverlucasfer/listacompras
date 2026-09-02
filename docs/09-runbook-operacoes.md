# 09 — Runbook de Operações

> Navegação: [← 08 Compartilhamento](08-compartilhamento-colaborativo.md) · [10 Wireframes →](10-wireframes-telas.md)

**Este documento é o dono dos procedimentos operacionais** pós-lançamento: incidentes, manutenção do Supabase, cota do Gemini, migrations, secrets e hotfixes. Guia prático — cada procedimento em passos copiáveis.

---

## 1. Acessos e localização de credenciais

| Recurso | Onde está | Acesso usado para |
| :--- | :--- | :--- |
| Dashboard Supabase | https://supabase.com/dashboard | Banco, auth, logs, backup, billing |
| `GEMINI_API_KEY` | Supabase Secrets (`supabase secrets list`) | Edge Function de IA |
| Service role key | Dashboard Supabase → Settings → API | RPCs admin, exclusão de conta |
| Sentry | https://sentry.io | Erros de app e Edge Function |
| Play Console | https://play.google.com/console | Publicação/rollout Android |
| Google AI Studio | https://aistudio.google.com | Cota e nova API key |

> Nunca colar secrets em issues, chat ou código. Rotação: Seção 6.

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
* Backup manual sob demanda (máquina local com Supabase CLI linkado):
  ```powershell
  supabase db dump --file backup_$(Get-Date -Format yyyyMMdd).sql
  ```
* **Restore** (projeto novo ou mesmo projeto):
  ```bash
  psql "$DATABASE_URL" -f backup_YYYYMMDD.sql
  ```
* Rotina mínima recomendada: dump mensal + antes de qualquer migration destrutiva.

### 2.3. Monitorar uso e limites

| O quê | Onde | Alerta |
| :--- | :--- | :--- |
| Uso de banco/storage/egress | Dashboard → Reports | > 70% do free tier |
| Realtime (conexões/mensagens) | Dashboard → Realtime | mensagens/mês > 70% |
| Edge Function invocations | Dashboard → Edge Functions | crescimento anômalo (possível abuso) |
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

**Regra:** nenhuma migration direto no SQL editor do dashboard em produção — tudo via CLI versionado ([01 §2](01-banco-de-dados.md)).

**Rollback:** migrations não têm down automático. Estratégia: criar migration **inversa** nova (`0009_rollback_0008.sql`), testar em local, `db push`. Restaurar backup (2.2) só em caso catastrófico.

### 2.4. Upgrade Supabase Pro (quando disparar)

1. Gatilho: lançamento público próximo OU pausa incomodando usuários ativos.
2. Billing → Upgrade → Pro (~US$ 25/mês): projeto não pausa, backups diários, 8 GB banco.
3. Após upgrade: revalidar Realtime e Edge Functions (sem mudança de URL/keys).

---

## 3. Gemini / Edge Function

### 3.1. Cota excedida (R-02)

**Sintoma:** Edge Function responde 429 `cota_ia`; app mostra "Limite diário atingido".

**Procedimento:**
1. Confirmar em https://aistudio.google.com o consumo do dia.
2. Curto prazo: nada a fazer — cota reseta diariamente; o app já degrada bem (importação manual continua 100%).
3. Se recorrente e o uso cresceu: avaliar plano pago do Gemini **ou** reduzir rate limit por usuário ([04 §3](04-ia-edge-function.md)).

### 3.2. Edge Function com erro

1. Sentry → issue da função; log completo no Dashboard → Edge Functions → Logs.
2. Reproduzir local: `supabase functions serve parse-lista`.
3. Corrigir → deploy: `supabase functions deploy parse-lista`.

### 3.3. Rotação da `GEMINI_API_KEY`

```bash
# 1. Gerar nova key no Google AI Studio
# 2. Atualizar secret
supabase secrets set GEMINI_API_KEY=<novo_valor>
# 3. Redeploy das funções que usam
supabase functions deploy parse-lista
# 4. Revogar a key antiga no AI Studio
```

Tempo total: ~5 min, sem downtime perceptível.

---

## 4. Incidentes comuns

### 4.1. "Sincronização parou" (usuários reportam listas desatualizadas)

1. Verificar status Supabase (https://status.supabase.com) e se o projeto não está pausado (2.1).
2. Sentry: `syncStatus = Erro` persistente? Erro de auth (token expirado) ou de rede?
3. Testar manualmente: 2 dispositivos, mesma conta, marcar item — verificar < 1s.
4. Se fila travada (mutação com muitas tentativas): checar erros no log do Postgres (violations de RLS/unique) — erro de negócio na fila deve aparecer no `Erro` da UI ([03 §6](03-sincronizacao-offline.md)).

### 4.2. "Meus itens desapareceram"

1. Confirmar que não é tombstone legítimo: `select * from itens_lista where lista_id = '...'` (deletado_em preenchido = remoção válida em algum dispositivo).
2. Checar Sentry por erro de flush no período.
3. Último recurso: restaurar backup (2.2) — **nunca** editar dados de produção manualmente sem backup prévio.

### 4.3. Suspeita de abuso da Edge Function

1. Dashboard → Edge Functions → invocations anômalas por horário.
2. Reduzir temporariamente `LIMITE_POR_MINUTO` e redeploy.
3. Verificar `ia_rate_limit` para identificar user_id anômalo; bloqueio manual: UPDATE do papel do membro ou remoção da lista.

---

## 5. Hotfix do app publicado

**Android (Play Store):**
1. Correção em branch `hotfix/...` a partir da tag de release.
2. CI verde ([07](07-qualidade-ci.md)) + bump de versão (`pubspec.yaml`, patch).
3. Build AAB → Play Console → produção (se rollout aberto) ou teste interno.
4. **Rollout gradual** (10% → 50% → 100%) em correções arriscadas.

**Web:**
1. Merge do hotfix → `flutter build web` → deploy no hosting.
2. Rollback = redeploy do commit anterior (hosting mantém histórico).

**Dados/backend:** correções de schema/RLS seguem 2.4; Edge Function segue 3.2.

---

## 6. Checklist mensal de operação

- [ ] Backup manual (`supabase db dump`) baixado e guardado.
- [ ] Uso de quotas Supabase/Gemini revisado (< 70%).
- [ ] Sentry: issues abertas triadas; sem erro crítico antigo.
- [ ] Migrations locais = produção (`supabase db push --dry-run` vazio).
- [ ] Secrets listados e válidos (`supabase secrets list`).
- [ ] Dependências Flutter/Supabase CLI com atualizações de segurança.

---

## Documentos relacionados
- [00 Visão Geral](00-visao-geral.md) — riscos R-01/R-02 que este runbook endereça
- [03 Sincronização](03-sincronizacao-offline.md) — diagnóstico de sync parada
- [07 Qualidade & CI](07-qualidade-ci.md) — pipeline exigido antes de qualquer hotfix
