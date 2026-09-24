# 16 — Roadmap Pós-MVP (frentes futuras)

> Navegação: [← 15 Design System](15-design-system.md) · [Índice](../planejamento_lista_compras.md)

**Este documento é o dono do backlog de frentes pós-MVP.** Ele **não** é a fonte de requisitos (isso é o [12](12-prd.md)) nem o breakdown executável (isso é o [14](14-tarefas.md)). Aqui ficam as ideias **registradas e ainda não especificadas**, para que nenhuma se perca.

## Como usar (governança)

- Uma frente só vira **RF** ([12](12-prd.md)) e **fase/tarefa** ([14](14-tarefas.md)) depois de ter **spec aprovado** em `docs/superpowers/specs/` e **plano** em `docs/superpowers/plans/`. Até lá, vive aqui.
- Cada frente tem um **doc dono** previsto; a alteração de comportamento ocorre no dono, no mesmo PR da implementação.
- **Ordem combinada (21/09/2026):** F23 duplicar lista → transferência de dono → robustez do Realtime → preços/orçamento. As demais entram conforme prioridade.
- **Gates do dono:** F5-T05 (usabilidade) e F5-T06 (publicação Play) só executam sob solicitação explícita ([AGENTS.md](../AGENTS.md)).

## Em execução agora

| ID | Frente | Requisito | Fase | Spec | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | **Duplicar lista ("Comprar de novo")** | **RF-20** | F23 | [spec](superpowers/specs/2026-09-21-duplicar-lista-design.md) | concluído (F23-T01…T03) |
| B1 | **Transferência de dono** | **RF-14** | F24 | [spec](superpowers/specs/2026-09-21-transferencia-dono-design.md) | concluído (F24-T01…T05) |

## Onda A — Uso diário e retenção

Foco: fazer a lista recorrente render mais, tudo **offline-first**, sem schema/RLS/sync novos (salvo indicação).

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | Duplicar lista ("comprar de novo") | RF-20 | 05, 10 | Alto | M | concluído (F23-T01…T03) |
| A2 | Arquivar/desarquivar listas | RF-22 | 05, 10, 01 | Médio | M | concluído (F26-T01…T04) — coluna `arquivada_em` + trigger do dono, sem policy nova |
| A3 | Adicionar itens de outra lista | RF-23 | 05, 10 | Médio | M | concluído (F27-T01…T03) — lote a partir de uma lista escolhida, dedup do app (soma/replace), sem preço |
| A4 | Reordenar categorias por corredor | RF-24 | 01, 05, 10, 12 | Médio | P | concluído (F28-T01…T03) — ordem pessoal das 11 categorias, persistida local |
| A5 | Quantidades em fração/embalagem ("½ kg") | RF-25 | 04, 05 | Médio | M | concluído (F29-T01…T03) — parser/entrada e exibição com glifos, sem mudar schema (reais já suportam) |
| A6 | Adicionar item por voz | RF-26 | 05, 04 | Médio | M | concluído (F30-T01…T03) — microfone on-device (pt-BR) preenche o campo; Android pode cair para o reconhecedor de rede (limitação do plugin/SO); Web/Desktop ocultam |
| A7 | Onboarding curto + estados vazios | RF-27 | 05, 10, 15 | Médio | P | concluído (F31-T01…T03) — boas-vindas uma vez (flag local) + dica do vazio com caminhos |

## Onda B — Colaboração completa

Foco: fechar o compartilhamento prometido no [08](08-compartilhamento-colaborativo.md).

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| B1 | Transferência de dono | RF-14 | 08 §6 | Alto | M | concluído (F24-T01…T05) |
| B2 | Convite por e-mail (fluxo B) | RF-13 | 08 §4 | Alto | M | concluído (F32-T01…T04) — criar por e-mail + painel "Convites pendentes" (aceitar/recusar); **envio automático** (Edge Function `enviar-convite`) segue adiado |
| B3 | Notificações push (convite/entrada) | RF-30 | 08, 09 | Médio | G | concluído (F38-T01…T09) — convite por e-mail + novo membro; Android agora, iOS depois |

## Onda C — Robustez e lançamento

Foco: confiabilidade e preparação para publicação séria.

| ID | Frente | Referência | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C1 | Status do Realtime + re-sync automático | R-12 | 03 §4 | Alto | P/M | concluído (F20, `4ff9d11`) |
| C2 | E2E/integration dos fluxos críticos + goldens | 07 | 07 | Alto | M | concluído (F33-T01…T03) — fluxos críticos no widget (criar/adicionar/marcar/limpar, importar, entrar por código, offline) rodam no CI; **goldens e `integration_test` adiados** |
| C3 | Alertas do Sentry + backup automatizado | 07 §4, 09 §2.2 | 07, 09 | Médio | P | concluído (F34-T01…T03) — backup mensal cifrado via GitHub Actions (`backup.yml`); regras de alerta do Sentry (eventos 1-2) documentadas |
| C4 | CSP no Web (endurecimento) | R-21 | 06 §3.4 | Baixo | P | concluído (F35-T01…T02) — CSP recomendada (e COOP/COEP) documentada no 06 §3.4.1; aplicável quando o Web for servido/publicado (ADR-013) |
| — | **F5-T05 usabilidade / F5-T06 publicação Play** | F5 | 06, 11 | Alto | G | **Gate do dono** — só sob solicitação |

## Onda D — Monetização e preços

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| D1 | Preço por item, total ao vivo e comparação entre idas | RF-21 (preço/total), RF-28 (orçamento), RF-29 (comparação) | 01, 03, 05, 10 | Alto | G | concluído (F25-T01…T05, F36-T01…T05, F37-T01…T03) — preço/total (`preco_centavos` + faixa), orçamento (`orcamento_centavos`, faixa com progresso e alerta) e comparação entre idas (histórico de preços **local** + "Última compra"/variação no editor), sem policy nova |

## Onda E — Alcance

| ID | Frente | Requisito | Doc dono | Valor | Esforço | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| E1 | iOS | Fase 6 | 06, 09 | Alto | G | Depende de conta Apple Developer |
| E2 | i18n (en/es) | novo | 05, 15 | Médio | G | Infra de localização; hoje pt-BR único |
| E3 | Widget Android / quick-add no lançador | novo | 05 | Médio | G | Atalho para adicionar item sem abrir o app |
| E4 | Lite no iOS | RF-31 | 05, 09 | Baixo | P | configurar flavor/bundle id `.lite` e ícone — requer macOS para verificar (F41 deixou fora) |

## Dívidas técnicas registradas

_Nenhuma dívida aberta no momento._

- **`file_picker` pinado em `10.3.10` (F41) — resolvida (F42/RF-31, 24/09/2026):** o pin exato existia porque a linha **11.x** é incompatível com AGP 9 / Built-in Kotlin — o plugin não aplica o Kotlin Gradle Plugin quando `AGP >= 9`, então `FilePickerPlugin` nunca compila e o **build Android quebra**. Substituído por **`file_selector`** (plugin do time Flutter, sem a guarda condicional de KGP e sem pin), usado pelo backup JSON (RF-31, [05 §6.10](05-app-flutter.md)).

## Documentos relacionados
- [12 PRD](12-prd.md) — requisitos com IDs (fonte do "o quê")
- [14 Tarefas](14-tarefas.md) — breakdown executável por fase
- [00 Visão Geral](00-visao-geral.md) — ADRs, riscos e cronograma
- [relatorio-revisao-geral.md](relatorio-revisao-geral.md) — achados `R-xx` citados acima
