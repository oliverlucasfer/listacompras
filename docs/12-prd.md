# 12 — PRD (Product Requirements Document)

> Navegação: [← 11 Usabilidade](11-usabilidade-fase5.md) · [13 Pré-modelo →](13-premodelo-tecnico.md)

**Este documento é a fonte única de REQUISITOS** (o "o quê" e o "porquê"). O **como** vive nos documentos donos — aqui apenas apontamos. Regra: **nenhum requisito novo entra no código sem ID aqui**.

Fluxo spec-driven: `13 pré-modelo` (contexto rápido) → `este doc` (o quê) → `14 tarefas` (o que fazer) → **doc dono** (como) → `07` (como verificar).

---

## 1. Personas

| ID | Persona | Contexto |
| :--- | :--- | :--- |
| P1 | **Comprador solo** | Faz compras sozinho, anota em qualquer lugar, usa o celular no mercado |
| P2 | **Anotador caótico** | Anota listas em texto livre (WhatsApp, bloco de notas), quer que "a máquina organize" |

## 2. Requisitos Funcionais

Formato: **ID** — requisito · *dono* (implementação) · fase · aceite.

| ID | Requisito | Dono (doc) | Fase | Aceite |
| :--- | :--- | :--- | :--- | :--- |
| RF-02 | Criar, renomear e excluir listas (delete lógico + confirmação) | 05 §6.2 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-03 | CRUD de itens com quantidade, unidade (enum em `lib/core/dominio/unidade.dart`) e checkbox | 05 §6.3 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-04 | Item concluído move para seção dobrável; ações em massa (desmarcar todos, limpar concluídos) | 05 §6.3 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-05 | Reordenar itens via drag-and-drop (coluna `ordem`) | 05 §6.3 | F3 | [05 §8](05-app-flutter.md) |
| RF-15 | Agrupamento da lista por categoria (enum fechado em `lib/core/dominio/categoria.dart`) com sugestão local em camadas (memória por nome → dicionário estático → `outros`) | 05 §6.3 | F6 | [05 §8](05-app-flutter.md) |
| RF-16 | Importação de lista por texto livre (parser local determinístico, offline) com pré-visualização editável | 05 §6.4 + 10 §4 | F11 | [05 §8](05-app-flutter.md) |
| RF-17 | Busca/filtro **local (offline)** de listas pelo título (painel) e de itens pelo nome (tela da lista) | 05 §6.2 + §6.3 | F16 | [05 §8](05-app-flutter.md) |
| RF-18 | Modo mercado: tela focada para comprar no corredor (pendentes em destaque, contador, faixa "Marcados") acessível por botão na tela da lista | 05 §6.5 + 10 §3.3 | F22 | [05 §8](05-app-flutter.md) |
| RF-19 | Itens frequentes: chips de sugestão derivados do histórico local (offline), com peso por escopo | 05 §3 + §6.3 + 10 §3.1 | F22 | [05 §8](05-app-flutter.md) |
| RF-20 | Duplicar lista ("comprar de novo"): cria uma lista nova a partir dos itens pendentes de uma lista existente | 05 §6.2 + 10 §2.4 | F23 | [05 §8](05-app-flutter.md) |
| RF-21 | Preço unitário opcional por item + total ao vivo dos itens marcados ("no carrinho"), no rodapé da lista e no modo mercado | 05 §6.3/§6.5 + 10 §3.1/§3.3 | F25 | [05 §8](05-app-flutter.md) |
| RF-22 | Arquivar/desarquivar listas (estado global) | 05 §6.2 + 10 §2 | F26 | [05 §8](05-app-flutter.md) |
| RF-23 | Adicionar itens de outra lista (pendentes, multi-seleção, dedup) | 05 §6.3 + 10 §3 | F27 | [05 §8](05-app-flutter.md) |
| RF-24 | Ordem pessoal das categorias (global, local por dispositivo) | 05 §6 + 10 §5 | F28 | [05 §8](05-app-flutter.md) |
| RF-25 | Quantidades em fração na entrada e exibição (½, 1/2, 1 1/2) | 04 §3 + 05 §6.3 | F29 | [05 §8](05-app-flutter.md) |
| RF-26 | Adicionar item por voz (reconhecimento on-device, pt-BR, preenche o campo) | 05 §6.3 | F30 | [05 §8](05-app-flutter.md) |
| RF-27 | Boas-vindas (uma vez) + estados vazios explicativos + **tour guiado interativo do primeiro uso** (2 etapas, spotlight sobre a UI real, reabrível em Configurações) | 05 §6.8/§6.11 + 10 §2/§3/§5 | F31 · F46 | [05 §8](05-app-flutter.md) |
| RF-28 | Orçamento (limite de gasto) por lista, comparado ao total do carrinho (RF-21), editável | 05 §6.3/§6.5 + 10 §3.1/§3.3 | F36 | [05 §8](05-app-flutter.md) |
| RF-29 | Comparação de preços entre idas: "Última compra: R$ X (dd/mm)" + variação no editor, a partir do histórico **local por dispositivo** | 05 §6.3 + 10 §3.1 | F37 | [05 §8](05-app-flutter.md) |
| RF-31 | **App único local "Minhas Listas" (Lite):** uso sem conta, 100% no aparelho (sem login, sem convites, sem notificações, sem sincronização), com backup local exportar/importar; identidade visual própria (índigo/cesta, nome "Minhas Listas") | 05 §2.3 + 05 §6.10 | F48 | [05 §2.3](05-app-flutter.md) |
| RF-32 | Publicação do app ("Minhas Listas") na Google Play em produção: app 100% local (sem rede/push/Firebase), AAB assinado, política de privacidade pública e Declaração de Dados | 06 §4 + 09 §2.10 + 05 §2.3 | F47 | [06 §4](06-mvp-entregas.md) |
| RF-33 | Compartilhar lista sem nuvem: exportar (texto/arquivo/QR-código) e importar (texto/arquivo/QR) sempre criando uma lista nova, 100% offline | 05 §6.12 + 10 | F49 | [05 §8](05-app-flutter.md) |
| RF-34 | Histórico de compras: ação "Finalizar compra" grava uma ida (snapshot dos itens concluídos) + aba Histórico (lista/resumo/detalhe); estatísticas na Fase 51 | 05 §6.13 + 10 | F50 · F51 | [05 §8](05-app-flutter.md) |

## 3. Requisitos Não-Funcionais

| ID | Requisito | Meta | Verificação |
| :--- | :--- | :--- | :--- |
| RNF-02 | Offline completo | Leitura/escrita/marcação sem rede; dados persistem ao fechar/reabrir (Drift é a fonte da verdade) | Testes de repositório + fluxo `T3` de [11](11-usabilidade-fase5.md) |
| RNF-05 | Privacidade (LGPD) | Nada sai do aparelho; sem conta/telemetria; backup local e política pública | [06 §3](06-mvp-entregas.md) |
| RNF-06 | Acessibilidade | Alvos ≥ 48dp, contraste AA, escala de fonte respeitada | Testes de a11y ([15 §4](15-design-system.md)) |
| RNF-08 | Qualidade | CI verde obrigatório; repositórios, parser e fluxos críticos cobertos no CI | [07 §1](07-qualidade-ci.md) |

## 4. User Stories

Formato: Como [persona], quero [ação], para [benefício]. **GWT:** Given/When/Then.

### Comprador solo (P1)

**US-01 — Adicionar item rápido**
Como P1, quero digitar o item e salvar com um toque, para não perder o fluxo no mercado.
- Given estou na lista, when digito "Leite" e pressiono Enter, then o item aparece marcado como pendente com quantidade 1 un.

**US-02 — Importar lista anotada**
Como P2, quero colar uma anotação bagunçada e receber itens estruturados, para não digitar um por um.
- Given colo "1kg de arroz, 2 leites, 500g de queijo prato", when confirmo a extração, then vejo pré-visualização com esses 3 itens e unidades corretas antes de salvar.

**US-03 — Comprar sem sinal**
Como P1, quero marcar itens no mercado sem internet, para não depender do sinal da loja.
- Given não tenho conexão com itens pendentes, when marco 3 itens e fecho/reabro o app, then as marcações continuam lá (os dados ficam no aparelho).

**US-07 — Lista por setores**
Como P1, quero os itens pendentes agrupados por categoria (Hortifrúti, Mercearia, Frios…), para comprar por setor sem voltar atrás na loja.
- Given a lista tem leite e queijo, when adiciono "arroz", then os pendentes aparecem em grupos fixos (Laticínios, Frios, Mercearia) com contagem em cada header.

**US-08 — Sugestão automática local**
Como P1, quero que itens comuns já venham categorizados mesmo offline, para não classificar manualmente.
- Given o app usa um dicionário local, when digito "detergente" e pressiono Enter, then o item entra em Limpeza; nomes fora do dicionário entram em Outros e passam a ser lembrados (memória por nome).

## 5. Mapa do Design (o "SDD" — onde cada decisão vive)

> **Regra:** este mapa apenas APONTA. O conteúdo técnico vive exclusivamente no doc dono — alterações de design são feitas lá.

| Área do design | Doc dono | Resumo |
| :--- | :--- | :--- |
| Importação de lista (parser local) | [04](04-importacao-lista.md) | Parser determinístico RF-16, limites, enum, sugestão de categoria |
| Arquitetura do app e UX | [05](05-app-flutter.md) | Riverpod, rotas, telas, Material 3 |
| Layout visual | [10](10-wireframes-telas.md) | Wireframes de todas as telas |
| Design System (tokens, componentes) | [15](15-design-system.md) | Material 3 Expressive, componentes, acessibilidade |
| Operação | [09](09-runbook-operacoes.md) | Build, distribuição e publicação |
| Qualidade | [07](07-qualidade-ci.md) | Testes, CI |

## 6. Matriz de Rastreabilidade

Cada requisito liga story → design → tarefas ([14](14-tarefas.md)) → verificação ([07](07-qualidade-ci.md)):

| Requisito | US | Fase | Tarefas (14) | Testes (07) |
| :--- | :--- | :--- | :--- | :--- |
| RF-02/03/04 | US-01 | F3 | F3-T08…T12 | Repositórios + widgets |
| RF-05 | US-01 | F3 | F4-T05 | Widget reordenar |
| RF-15 | US-07, US-08 | F6 | F6-T01…T06 | Repo + sugestão + widgets |
| RF-16 | US-02 | F11 | F11-T01…T03; F17-T01…T03 | Unit parser + widgets |
| RF-17 | US-01 | F16 | F16-T01…T03 | Unit busca + widgets |
| RF-18 | US-01 | F22 | F22-T04, F22-T05 | Widget mercado + teste de gate |
| RF-19 | US-01 | F22 | F22-T02, F22-T03 | Unit frequentes + widgets de chips |
| RF-20 | US-01 | F23 | F23-T01, F23-T02 | Unit duplicar + widget do painel |
| RF-21 | US-01 | F25 | F25-T02…T04 | Unit preço/total + widgets |
| RF-22 | US-01 | F26 | F26-T02, F26-T03 | Unit arquivo + widgets |
| RF-23 | US-01 | F27 | F27-T01, F27-T02 | Unit dedup/lote + widgets |
| RF-24 | US-07 | F28 | F28-T01, F28-T02 | Unit ordem + provider + widgets |
| RF-25 | US-01, US-02 | F29 | F29-T01, F29-T02 | Unit parse/format + parser + editor |
| RF-26 | US-01 | F30 | F30-T01, F30-T02 | Unit fake + widgets (plugin real: smoke em device) |
| RF-27 | US-01 | F31 · F46 | F31-T01, F31-T02; F46-T01…T05 | Unit provider/widgets + motor/roteiro/overlay do tour |
| RF-28 | US-01 | F36 | F36-T02…T04 | Unit repo/aplicador + widgets |
| RF-29 | US-01 | F37 | F37-T01, F37-T02 | Unit repo/histórico + widgets |
| RF-31 | US-01 | F48 | F48-T01…T08 | Widget/unit + smoke em device |
| RF-32 | US-01 | F47 | F47-T01…T08 | Widget/unit + build AAB + teste de manifest + smoke em device |
| RF-33 | US-01 | F49 | F49-T01…F49-T06 | Unit codec/repo + widgets |
| RF-34 | US-01 | F50 · F51 | F50-T01…T05 (F51 depois) | Unit repo + widgets |
| RNF-02 | US-03 | F48 | F48-T02, F48-T04 | Testes de repositório + fluxo `T3` |
| RNF-06 | — | F8 · F14 | F14-T01…T02 | Guidelines de a11y + escala de fonte |
| RNF-08 | — | F33 · F39 | F33-T01…T03 | Fluxos críticos + consistência |

## 7. Fora de escopo (MVP)

Receitas/menus, cupons, scan de código de barras, importação de foto/nota fiscal, app iOS na distribuição, publicação de desktop, **colaboração/compartilhamento em nuvem** (removido na F48; o compartilhamento **local** volta como RF-33, pós-MVP/F49), **conta/nuvem/sync/push** (removidos na F48). O **histórico de compras** volta como RF-34 (pós-MVP: F50 núcleo, F51 estatísticas).

---

## Documentos relacionados
- [13 Pré-modelo Técnico](13-premodelo-tecnico.md) — contexto condensado para implementação
- [14 Tarefas](14-tarefas.md) — breakdown executável por fase
- [00 Visão Geral](00-visao-geral.md) — ADRs e riscos que embasam estes requisitos
