# Planejamento: Lista de Compras "Minhas Listas"

> **Índice de documentação.** O planejamento detalhado vive em `docs/` — cada tema tem um único documento dono. Atualize sempre o documento dono, nunca duplique conteúdo.

App **local e offline-first** (Android, iOS, Web e Desktop) para gerenciamento de listas de compras, com entrada manual, importação de lista por texto e backup JSON. Roda 100% no aparelho — **sem conta, sem nuvem, sem sincronização** (Fase 48).

---

## Documentos

| # | Documento | Conteúdo | Dono de |
| :--- | :--- | :--- | :--- |
| [00](docs/00-visao-geral.md) | **Visão Geral** | Produto, stack, setup & pré-requisitos, riscos & mitigações, ADRs, cronograma por fases | Visão, stack, ADRs, cronograma, riscos |
| [04](docs/04-importacao-lista.md) | **Importação de lista (parser local)** | Contrato RF-16, limites, enum, sugestão de categoria | Importação de lista |
| [05](docs/05-app-flutter.md) | **App Flutter** | Arquitetura, providers, rotas, telas, UX e design system | UI/UX e arquitetura do app |
| [06](docs/06-mvp-entregas.md) | **MVP & Entregas** | Critérios de aceite, DoD por fase, LGPD/privacidade, publicação, métricas | Aceite, LGPD, publicação |
| [07](docs/07-qualidade-ci.md) | **Qualidade & CI** | Estratégia de testes, GitHub Actions, observabilidade | Testes, CI, observabilidade |
| [09](docs/09-runbook-operacoes.md) | **Runbook de Operações** | Builds, distribuição, publicação Play, hotfix | Operação pós-lançamento |
| [10](docs/10-wireframes-telas.md) | **Wireframes** | Layout ASCII de todas as telas, estados, modais | Layout visual (comportamento no 05) |
| [11](docs/11-usabilidade-fase5.md) | **Usabilidade (Fase 5)** | Roteiro, tarefas, métricas, critério de aprovação | Testes de usabilidade |
| [12](docs/12-prd.md) | **PRD** | Requisitos funcionais/não-funcionais com IDs, user stories, matriz de rastreabilidade | Requisitos de produto |
| [13](docs/13-premodelo-tecnico.md) | **Pré-modelo Técnico** | Contexto condensado para implementação (ler primeiro) | Resumo — nunca sobrepõe o doc dono |
| [14](docs/14-tarefas.md) | **Tarefas** | Breakdown executável por fase (F1–F48) com dependências e critério de pronto | Execução e progresso |
| [15](docs/15-design-system.md) | **Design System** | Tokens, tema M3 Expressive, componentes, motion e acessibilidade | Design system (tokens, componentes, acessibilidade) |
| [16](docs/16-roadmap-pos-mvp.md) | **Roadmap Pós-MVP** | Backlog de frentes futuras (ondas A–E), ainda sem spec; ordem combinada e governança | Backlog de frentes futuras |

---

## Stack em uma linha

**Flutter + Riverpod + Drift/SQLite** (app local offline-first) · **GitHub Actions** (CI).

## Cronograma (resumo)

1. **Importação local (parser)** → 2. **App Flutter core** → 3. **Publicação MVP (Web + Android)** → 4. **Pós-MVP** (iOS, Desktop) → 5. **Revisão visual e UX** (design system, refresh das telas e navegação — Fase 8+, spec em `docs/superpowers/specs/2026-09-11-revisao-visual-ux-design.md`) → 6. **Acessibilidade, fluxos e polimento de UX** (RNF-06 — Fase 14, spec em `docs/superpowers/specs/2026-09-14-ux-acessibilidade-design.md`) → 7. **Busca e filtro** (busca local por título no painel e por nome na lista — Fase 16/RF-17, spec em `docs/superpowers/specs/2026-09-16-busca-filtro-design.md`) → 8. **Suporte a Web e Desktop** (Fase 18/ADR-012, spec em `docs/superpowers/specs/2026-09-17-suporte-web-desktop-design.md`) → 9. **Publicação do Lite na Play** (Fase 47/RF-32, spec em `docs/superpowers/specs/2026-09-29-publicacao-lite-play-design.md`) → 10. **App único "Minhas Listas"** (remoção do Supabase — Fase 48/RF-31, spec em `docs/superpowers/specs/2026-09-29-app-unico-lite-sem-supabase-design.md`).

Detalhes e DoD por fase: [00 §6](docs/00-visao-geral.md) · Breakdown executável: [14](docs/14-tarefas.md).

## Fluxo spec-driven

> Como usar esta documentação para implementar:
> **`AGENTS.md`** (fluxo de trabalho) → **`13`** (contexto em 1 leitura) → **`14`** (tarefa com critério de pronto) → **doc dono** (como implementar) → **`12`** (requisito/ID) → **`07`** (como verificar).

## Decisões-chave (resumo)

| Decisão | ADR |
| :--- | :--- |
| App único local ("Minhas Listas", Lite); sem conta/nuvem/sync | ADR-015 |
| Android/iOS/Web/Desktop; **Desktop suportado (Fase 18)** e Web como Lite | ADR-001 / ADR-012 |
| Riverpod · Drift/SQLite · IDs client-side | ADR-002/003/006 |
| Enum fechado de unidades · categorias (sugestão local em camadas) | ADR-005 / ADR-011 |
| Backup JSON local (exportar/importar) · GitHub Actions | ADR-015 / ADR-010 |

Tabela completa com justificativas: [00 §5](docs/00-visao-geral.md).
