# Planejamento: Sistema de Lista de Compras Inteligente e Colaborativo

> **Índice de documentação.** O planejamento detalhado vive em `docs/` — cada tema tem um único documento dono. Atualize sempre o documento dono, nunca duplique conteúdo.

Sistema multiplataforma (MVP: Android, iOS e Web) para gerenciamento de listas de compras com entrada manual e importação por IA (texto livre), sincronização em tempo real e funcionamento offline-first.

---

## Documentos

| # | Documento | Conteúdo | Dono de |
| :--- | :--- | :--- | :--- |
| [00](docs/00-visao-geral.md) | **Visão Geral** | Produto, stack, setup & pré-requisitos, riscos & mitigações, ADRs, cronograma por fases | Visão, stack, ADRs, cronograma, riscos |
| [01](docs/01-banco-de-dados.md) | **Banco de Dados** | Schema completo, SQL das migrations, enum de unidades, triggers, índices, Realtime | Schema e enum de unidades |
| [02](docs/02-seguranca-rls.md) | **Segurança RLS** | Funções auxiliares, `CREATE POLICY`, matriz de acesso, testes de negação | Políticas de acesso |
| [03](docs/03-sincronizacao-offline.md) | **Sincronização Offline-First** | Sync Engine, fila de mutações, LWW, tombstones, casos-limite, estados de sync | Regras de sync e conflitos |
| [04](docs/04-ia-edge-function.md) | **IA / Edge Function** | Contrato HTTP, prompt de sistema, `responseSchema`, rate limit, códigos de erro | Integração com Gemini |
| [05](docs/05-app-flutter.md) | **App Flutter** | Arquitetura, providers, rotas, telas, UX e design system | UI/UX e arquitetura do app |
| [06](docs/06-mvp-entregas.md) | **MVP & Entregas** | Critérios de aceite, DoD por fase, LGPD/privacidade, publicação, métricas | Aceite, LGPD, publicação |
| [07](docs/07-qualidade-ci.md) | **Qualidade & CI** | Estratégia de testes, GitHub Actions, Sentry/observabilidade | Testes, CI, observabilidade |
| [08](docs/08-compartilhamento-colaborativo.md) | **Compartilhamento (Fase 6)** | Convites (link/e-mail), papéis, transferência de dono, RPCs, Realtime | Compartilhamento colaborativo |
| [09](docs/09-runbook-operacoes.md) | **Runbook de Operações** | Incidentes, pausa/backup Supabase, cota Gemini, migrations, hotfix | Operação pós-lançamento |
| [10](docs/10-wireframes-telas.md) | **Wireframes** | Layout ASCII de todas as telas, estados, modais | Layout visual (comportamento no 05) |
| [11](docs/11-usabilidade-fase5.md) | **Usabilidade (Fase 5)** | Roteiro, tarefas, métricas, critério de aprovação | Testes de usabilidade |
| [12](docs/12-prd.md) | **PRD** | Requisitos funcionais/não-funcionais com IDs, user stories, matriz de rastreabilidade | Requisitos de produto |
| [13](docs/13-premodelo-tecnico.md) | **Pré-modelo Técnico** | Contexto condensado para implementação (ler primeiro) | Resumo — nunca sobrepõe o doc dono |
| [14](docs/14-tarefas.md) | **Tarefas** | Breakdown executável por fase (F1–F5) com dependências e critério de pronto | Execução e progresso |

---

## Stack em uma linha

**Flutter + Riverpod + Drift** (cliente offline-first) · **Supabase** (Postgres + Auth + Realtime + Edge Functions + RLS) · **Gemini 2.0 Flash** (parser de texto livre, JSON mode) · **GitHub Actions + Sentry**.

## Cronograma (resumo)

1. **Infraestrutura & BD** → 2. **Edge Function de IA** → 3. **App Flutter core** → 4. **IA + Sync offline-first** → 5. **Publicação MVP (Web + Android)** → 6. **Pós-MVP** (iOS, Desktop, compartilhamento).

Detalhes e DoD por fase: [00 §6](docs/00-visao-geral.md) · Breakdown executável: [14](docs/14-tarefas.md).

## Fluxo spec-driven

> Como usar esta documentação para implementar (com IA ou pessoas):
> **`AGENTS.md`** (fluxo de trabalho) → **`13`** (contexto em 1 leitura) → **`14`** (tarefa com critério de pronto) → **doc dono** (como implementar) → **`12`** (requisito/ID) → **`07`** (como verificar).

## Decisões-chave (resumo)

| Decisão | ADR |
| :--- | :--- |
| MVP = Android/iOS/Web; Desktop na Fase 6 | ADR-001 |
| Riverpod · Drift/SQLite · LWW · IDs client-side | ADR-002/003/004/006 |
| Enum fechado de unidades | ADR-005 |
| Free tier aceito no MVP; Supabase Pro como gatilho de lançamento público | ADR-007 |
| Exclusão de conta (delete em cascata) na Fase 5 · Sentry · GitHub Actions | ADR-008/009/010 |

Tabela completa com justificativas: [00 §5](docs/00-visao-geral.md).
