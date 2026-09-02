# 07 — Qualidade, Testes, CI e Observabilidade

> Navegação: [← 06 MVP & Entregas](06-mvp-entregas.md) · [← Índice](../planejamento_lista_compras.md)

**Este documento é o dono da estratégia de qualidade.** Princípio: **cobertura por risco, não por percentual** — os componentes mais arriscados (Sync Engine, RLS) recebem os testes mais pesados.

---

## 1. Estratégia de testes (pirâmide adaptada)

| Camada | Ferramenta | O quê | Prioridade |
| :--- | :--- | :--- | :--- |
| **Sync Engine** (unit) | `flutter_test` | LWW, coalescing, tombstones, retry, casos-limite de [03 §5](03-sincronizacao-offline.md) | **Máxima** (RF-08) |
| **RLS** (integração SQL) | Testes com 2 usuários reais em Supabase dev | Casos N-01…N-10 e P-01…P-05 de [02 §5](02-seguranca-rls.md) | **Máxima** (RNF-03) |
| **Repositórios** (unit) | `flutter_test` + Drift in-memory | CRUD local + enfileiramento de mutações | Alta (RF-03) |
| **Edge Function** (integração) | Deno test / Supabase local | Contrato de [04 §2](04-ia-edge-function.md), rate limit, erros | Alta (RF-06, RNF-04) |
| **Widgets** | `flutter_test` + `golden_toolkit` (opcional) | Telas críticas: lista, importação IA, auth | Média (RF-01…RF-06) |
| **E2E** (integração app) | `integration_test` (opcional, pós-MVP) | Fluxo completo offline→online | Baixa (RNF-02) |

**Convenções:**
* Nomes: `deve_<resultado>_quando_<condição>` (ex.: `deve_manter_item_removido_offline_ao_receber_edicao_remota_antiga`).
* Sync Engine testado com fake de conectividade + fake do Supabase (determinístico, sem rede real no CI).
* Fila de mutações testada com cenários do checklist [03 §8](03-sincronizacao-offline.md).

## 2. O que é testado vs. aceito sem teste

| Testado | Aceito sem teste (MVP) |
| :--- | :--- |
| Sync Engine, RLS, repositórios, Edge Function, widgets críticos | UI de detalhe (animações), theming visual, i18n (pt-BR único), performance fino |

---

## 3. CI — GitHub Actions (desde a Fase 1)

Pipeline único `.github/workflows/ci.yml`, disparado em PR e push em `main`:

```
┌────────────────────────────────────────────────┐
│ job: flutter                                   │
│  1. dart format --set-exit-if-changed .        │
│  2. flutter analyze                            │
│  3. flutter test (unit + widget)               │
├────────────────────────────────────────────────┤
│ job: supabase (paralelo)                       │
│  1. supabase db reset (aplica migrations)      │
│  2. testes SQL de negação/positivos RLS        │
│  3. (Fase 2+) deno test nas Edge Functions     │
└────────────────────────────────────────────────┘
```

* PR só mergea com CI verde (branch protection).
* Segurança no CI: secrets do Supabase de **ambiente de teste**, nunca produção; JWTs de teste criados na hora.
* Tempo alvo do pipeline: < 10 min.

### Esqueleto de referência

```yaml
name: ci
on: [pull_request, push]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test

  supabase:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase db reset   # valida migrations
      # Fase 2: deno test supabase/functions
      # Fase 1: script de testes de negação RLS contra DB local
```

---

## 4. Observabilidade

* **Sentry (plano free)** no Flutter e nas Edge Functions (ADR-009):
  * Crash nativos, erros não tratados, `syncStatus = Erro` persistente.
  * **Regra de privacidade:** logs **nunca** contêm nomes de itens nem conteúdo de listas ([06 §3.1](06-mvp-entregas.md)); apenas IDs técnicos.
* Eventos mínimos monitorados:
  1. Falha de flush com fila > 10 mutações ou mutação com > 5 tentativas.
  2. Divergência grosseira de relógio (`ts_local` vs servidor — ver [03 §5](03-sincronizacao-offline.md)).
  3. Erros 422/500 da Edge Function.
* Dashboards: Sentry issues + métricas da Seção 5 de [06](06-mvp-entregas.md) (manual no MVP).

---

## 5. Checklist de qualidade por PR (disciplina leve)

- [ ] `dart format` e `flutter analyze` sem queixas.
- [ ] Novo comportamento de sync/RLS tem teste correspondente.
- [ ] CI verde antes do merge.
- [ ] Sem segredo/chave em código ou logs.

---

## Documentos relacionados
- [02 Segurança RLS](02-seguranca-rls.md) — testes de negação que rodam no CI
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — prioridade máxima de testes
- [06 MVP & Entregas](06-mvp-entregas.md) — DoD por fase e privacidade dos logs
