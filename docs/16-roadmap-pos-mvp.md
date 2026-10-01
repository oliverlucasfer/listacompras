# 16 — Roadmap Pós-MVP (frentes futuras)

> Navegação: [← 15 Design System](15-design-system.md) · [Índice](../planejamento_lista_compras.md)

**Este documento é o dono do backlog de frentes pós-MVP.** Ele **não** é a fonte de requisitos (isso é o [12](12-prd.md)) nem o breakdown executável (isso é o [14](14-tarefas.md)). Aqui ficam as ideias **registradas e ainda não especificadas**, para que nenhuma se perca. O app é **único e local** ("Minhas Listas", RF-31); as frentes de backend/colaboração foram removidas na F48.

## Como usar (governança)

- Uma frente só vira **RF** ([12](12-prd.md)) e **fase/tarefa** ([14](14-tarefas.md)) depois de ter **spec aprovado** em `docs/superpowers/specs/` e **plano** em `docs/superpowers/plans/`. Até lá, vive aqui.
- Cada frente tem um **doc dono** previsto; a alteração de comportamento ocorre no dono, no mesmo PR da implementação.
- **Ordem combinada (21/09/2026):** F23 duplicar lista → robustez de dados → preços/orçamento. As demais entram conforme prioridade.
- **Gates do dono:** F5-T05 (usabilidade) e F5-T06 (publicação Play) só executam sob solicitação explícita ([AGENTS.md](../AGENTS.md)).

## Em execução agora

| ID | Frente | Requisito | Fase | Spec | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | **Duplicar lista ("Comprar de novo")** | **RF-20** | F23 | [spec](superpowers/specs/2026-09-21-duplicar-lista-design.md) | concluído (F23-T01…T03) |
| A8 | **Compartilhar lista sem nuvem (texto/arquivo/QR)** | **RF-33** | F49 | [spec](superpowers/specs/2026-09-30-compartilhar-lista-design.md) | concluído (F49-T01…T06) |
| A9 | **Histórico de compras e estatísticas** | **RF-34** | F50 · F51 | [spec](superpowers/specs/2026-09-30-historico-compras-design.md) | concluído (F50-T01…T05 + F51-T01…T04) |
| A10 | **Preço por mercado** | **RF-35** | F52 | [spec](superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md) | concluído (F52-T01…T05) |
| A11 | **Alertas de orçamento** | **RF-36** | F53 | [spec](superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md) | concluído (F53-T01…T06) |
| A12 | **Importar por foto (OCR)** | **RF-37** | F54 | [spec](superpowers/specs/2026-09-30-importar-foto-ocr-design.md) | concluído (F54-T01…T03) |
| A13 | **Widget Android / quick-add** | **RF-38** | F55 | [spec](superpowers/specs/2026-09-30-widget-android-design.md) | concluído (F55-T01…T05) |

## Onda A — Uso diário e retenção

Foco: fazer a lista recorrente render mais, tudo **offline-first**, sem schema novo.

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | Duplicar lista ("comprar de novo") | RF-20 | 05, 10 | Alto | M | concluído (F23-T01…T03) |
| A2 | Arquivar/desarquivar listas | RF-22 | 05, 10 | Médio | M | concluído (F26-T01…T04) |
| A3 | Adicionar itens de outra lista | RF-23 | 05, 10 | Médio | M | concluído (F27-T01…T03) |
| A4 | Reordenar categorias por corredor | RF-24 | 05, 10, 12 | Médio | P | concluído (F28-T01…T03) — ordem pessoal das 11 categorias, persistida local |
| A5 | Quantidades em fração/embalagem ("½ kg") | RF-25 | 04, 05 | Médio | M | concluído (F29-T01…T03) |
| A6 | Adicionar item por voz | RF-26 | 05, 04 | Médio | M | concluído (F30-T01…T03) — microfone on-device (pt-BR); Web/Desktop ocultam |
| A7 | Onboarding curto + estados vazios + tour | RF-27 | 05, 10, 15 | Médio | P | concluído (F31-T01…T03, F46) |

## Onda B — Robustez e lançamento

Foco: confiabilidade e preparação para publicação séria.

| ID | Frente | Referência | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| B2 | E2E/integration dos fluxos críticos + goldens | 07 | 07 | Alto | M | concluído (F33-T01…T03) — fluxos críticos no widget rodam no CI; **goldens e `integration_test` adiados** |
| B4 | CSP no Web (endurecimento) | R-21 | 06 §3.4 | Baixo | P | concluído (F35-T01…T02) — CSP recomendada (e COOP/COEP) documentada no 06 §3.4.1 |
| — | **F5-T05 usabilidade / F5-T06 publicação Play** | F5 | 06, 11 | Alto | G | **Gate do dono** — só sob solicitação |

## Onda C — Monetização e preços

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C1 | Preço por item, total ao vivo e comparação entre idas | RF-21 (preço/total), RF-28 (orçamento), RF-29 (comparação) | 05, 10 | Alto | G | concluído (F25-T01…T05, F36-T01…T05, F37-T01…T03) — preço/total, orçamento e comparação entre idas (histórico de preços **local**) |
| C2 | Preço por mercado e alertas de orçamento | RF-35 (mercado), RF-36 (alertas) | 05, 10 | Alto | M · G | concluído — RF-35 (F52-T01…T05, frente A10) e RF-36 (F53-T01…T06, frente A11): preços derivados das idas, sem tabela nova; alertas progressivos + orçamento por categoria + notificação local |

## Onda D — Alcance

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| D1 | iOS na distribuição | Fase 6 | 06, 09 | Alto | G | Depende de conta Apple Developer |
| D2 | i18n (en/es) | novo | 05, 15 | Médio | G | Infra de localização; hoje pt-BR único |
| D3 | Widget Android / quick-add no lançador | RF-38 | 05, 09, 10, 12, 15 | Médio | G | concluído (F55-T01…T05, frente A13) — AppWidget de tela inicial com a última lista, nº de pendentes e botão "Adicionar item" que abre `/adicionar` (Android-only, offline) |
| D5 | Publicação do app na Play (produção) | RF-32 | 06, 09 | Alto | M | em execução (F47) — gate F5-T06 (prod) permanece separado |

## Dívidas técnicas registradas

_Nenhuma dívida aberta no momento._

- **`file_picker` pinado em `10.3.10` (F41) — resolvida (F42/RF-31, 24/09/2026):** o pin exato existia porque a linha **11.x** é incompatível com AGP 9 / Built-in Kotlin. Substituído por **`file_selector`** (plugin do time Flutter, sem a guarda condicional de KGP e sem pin), usado pelo backup JSON (RF-31, [05 §6.10](05-app-flutter.md)).

## Documentos relacionados
- [12 PRD](12-prd.md) — requisitos com IDs (fonte do "o quê")
- [14 Tarefas](14-tarefas.md) — breakdown executável por fase
- [00 Visão Geral](00-visao-geral.md) — ADRs, riscos e cronograma
