# 12 — PRD (Product Requirements Document)

> Navegação: [← 11 Usabilidade](11-usabilidade-fase5.md) · [13 Pré-modelo →](13-premodelo-tecnico.md)

**Este documento é a fonte única de REQUISITOS** (o "o quê" e o "porquê"). O **como** vive nos documentos donos — aqui apenas apontamos. Regra: **nenhum requisito novo entra no código sem ID aqui**.

Fluxo spec-driven: `13 pré-modelo` (contexto rápido) → `este doc` (o quê) → `14 tarefas` (o quê fazer) → **doc dono** (como) → `07` (como verificar).

---

## 1. Personas

| ID | Persona | Contexto |
| :--- | :--- | :--- |
| P1 | **Comprador solo** | Faz compras sozinho, anota em qualquer lugar, usa o celular no mercado |
| P2 | **Casal/família compartilhando** | Dois ou mais mantêm a mesma lista; quem sai compra, quem fica adiciona |
| P3 | **Anotador caótico** | Anota listas em texto livre (WhatsApp, bloco de notas), quer que "a máquina organize" |

## 2. Requisitos Funcionais

Formato: **ID** — requisito · *dono* (implementação) · fase · aceite.

| ID | Requisito | Dono (doc) | Fase | Aceite |
| :--- | :--- | :--- | :--- | :--- |
| RF-01 | Autenticação: registro com verificação de e-mail, login, recuperação de senha | 05 §6.1 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-02 | Criar, renomear e excluir listas (delete lógico + confirmação) | 05 §6.2 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-03 | CRUD de itens com quantidade, unidade (enum [01 §3](01-banco-de-dados.md)) e checkbox | 05 §6.3 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-04 | Item concluído move para seção dobrável; ações em massa (desmarcar todos, limpar concluídos) | 05 §6.3 | F3 | [06 §1](06-mvp-entregas.md) |
| RF-05 | Reordenar itens via drag-and-drop (coluna `ordem`) | 05 §6.3 | F3–F4 | [05 §8](05-app-flutter.md) |
| RF-06 | Importação por texto livre via IA com pré-visualização editável e confirmação | 04 + 05 §6.4 | F4 | [06 §1](06-mvp-entregas.md) |
| RF-07 | Sincronização em tempo real entre dispositivos (Realtime) | 03 §4 | F4 | [06 §1](06-mvp-entregas.md) |
| RF-08 | Funcionamento 100% offline com sincronização automática ao reconectar | 03 | F4 | [06 §1](06-mvp-entregas.md) + [11 §3.1](11-usabilidade-fase5.md) (T3 bloqueante) |
| RF-09 | Indicador de status de sincronização na UI | 03 §6 + 10 §3.2 | F4 | [03 §8](03-sincronizacao-offline.md) |
| RF-10 | Deduplicação de itens (unique parcial + aumento de quantidade no sync) | 01 §4.3 + 03 §5 | F4 | [01 §8](01-banco-de-dados.md) |
| RF-11 | Exclusão de conta com delete físico em cascata (LGPD) | 06 §3.3.1 | F5 | [06 §3.3.1](06-mvp-entregas.md) |
| RF-12 | Observabilidade: Sentry com privacidade (sem conteúdo de listas em logs) | 07 §4 | F5 | [07](07-qualidade-ci.md) |
| RF-13 | Compartilhamento por convite (link/e-mail) com papéis — **Fase 6** | 08 | F6 | [08 §9](08-compartilhamento-colaborativo.md) |
| RF-14 | Transferência de dono — **Fase 6** | 08 §6 | F6 | [08 §9](08-compartilhamento-colaborativo.md) |

## 3. Requisitos Não-Funcionais

| ID | Requisito | Meta | Verificação |
| :--- | :--- | :--- | :--- |
| RNF-01 | Latência de sync (online) | Mudança visível < 1s em outro dispositivo | Teste T4 de [11](11-usabilidade-fase5.md) |
| RNF-02 | Offline completo | Leitura/escrita/marcação sem rede; zero perda ao reconectar | Checklist [03 §8](03-sincronizacao-offline.md) |
| RNF-03 | Segurança | Usuário não acessa lista alheia (RLS) | Negações N-01…N-10 de [02 §5](02-seguranca-rls.md) |
| RNF-04 | Proteção da IA | Sem API key no client; rate limit 10/min; erros amigáveis | Checklist [04 §9](04-ia-edge-function.md) |
| RNF-05 | Privacidade (LGPD) | Exclusão de conta funcional; logs sem dados de conteúdo | [06 §3](06-mvp-entregas.md) |
| RNF-06 | Acessibilidade | Alvos ≥ 48dp, contraste AA, escala de fonte respeitada | Revisão de UI ([05 §7](05-app-flutter.md)) |
| RNF-07 | Custo | R$ 0 no MVP (free tiers) | Riscos R-01/R-02 com gatilho definido ([00 §4](00-visao-geral.md)) |
| RNF-08 | Qualidade | CI verde obrigatório; sync e RLS com prioridade máxima de testes | [07 §1](07-qualidade-ci.md) |

## 4. User Stories

Formato: Como [persona], quero [ação], para [benefício]. **GWT:** Given/When/Then.

### Comprador solo (P1)

**US-01 — Adicionar item rápido**
Como P1, quero digitar o item e salvar com um toque, para não perder o fluxo no mercado.
- Given estou na lista, when digito "Leite" e pressiono Enter, then o item aparece marcado como pendente com quantidade 1 un.

**US-02 — Importar lista anotada**
Como P3, quero colar uma anotação bagunçada e receber itens estruturados, para não digitar um por um.
- Given colo "1kg de arroz, 2 leites, 500g de queijo prato", when confirmo a extração, then vejo pré-visualização com esses 3 itens e unidades corretas antes de salvar.

**US-03 — Comprar sem sinal**
Como P1, quero marcar itens no mercado sem internet, para não depender do sinal da loja.
- Given estou offline com itens pendentes, when marco 3 itens e o sinal retorna, then as marcações aparecem no outro dispositivo sem duplicar nem perder nada.

### Casal compartilhando (P2)

**US-04 — Mesma lista em tempo real** *(Fase 6)*
Como P2, quero que itens adicionados pelo meu parceiro apareçam na hora no meu celular, para decidirmos juntos.
- Given ambos estamos na lista, when o parceiro adiciona "Pão", then ele aparece no meu app em < 1s.

**US-05 — Convidar parceiro** *(Fase 6)*
Como P2, quero enviar um link para meu parceiro acessar minha lista, para compartilharmos sem cadastro complicado.
- Given sou dono, when gero convite por link e ele abre, then ele entra como editor e a lista aparece no painel dele.

**US-06 — Papel leitor**
Como P2, quero dar acesso só de leitura ao filho, para que ele acompanhe sem alterar.
- Given um membro é `leitor`, when ele abre a lista, then vê banner de somente leitura e não consegue editar (UI bloqueia + RLS nega).

## 5. Mapa do Design (o "SDD" — onde cada decisão vive)

> **Regra:** este mapa apenas APONTA. O conteúdo técnico vive exclusivamente no doc dono — alterações de design são feitas lá.

| Área do design | Doc dono | Resumo |
| :--- | :--- | :--- |
| Schema, migrations, triggers | [01](01-banco-de-dados.md) | Tabelas, enum de unidades, LWW cols, cascades |
| Segurança de acesso | [02](02-seguranca-rls.md) | `is_member`, policies, testes de negação |
| Sincronização e conflitos | [03](03-sincronizacao-offline.md) | Fila, flush, LWW, tombstones |
| IA e contrato serverless | [04](04-ia-edge-function.md) | Prompt, responseSchema, rate limit |
| Arquitetura do app e UX | [05](05-app-flutter.md) | Riverpod, rotas, telas, Material 3 |
| Layout visual | [10](10-wireframes-telas.md) | Wireframes de todas as telas |
| Compartilhamento (F6) | [08](08-compartilhamento-colaborativo.md) | Convites, papéis, transferência |
| Operação | [09](09-runbook-operacoes.md) | Runbook pós-lançamento |
| Qualidade | [07](07-qualidade-ci.md) | Testes, CI, Sentry |

## 6. Matriz de Rastreabilidade

Cada requisito liga story → design → tarefas ([14](14-tarefas.md)) → verificação ([07](07-qualidade-ci.md)):

| Requisito | US | Fase | Tarefas (14) | Testes (07) |
| :--- | :--- | :--- | :--- | :--- |
| RF-01 | — | F3 | F3-T04…T07 | Widget auth |
| RF-02/03/04 | US-01 | F3 | F3-T08…T12 | Repositórios + widgets |
| RF-05 | US-01 | F3–F4 | F4-T05 | Widget reordenar |
| RF-06 | US-02 | F4 | F2-T01…T05, F4-T01…T02 | Edge Function integração |
| RF-07/08/09 | US-03, US-04 | F4 | F4-T03…T08 | Sync Engine (máxima) |
| RF-10 | US-02 | F4 | F4-T06 | Sync + SQL |
| RF-11 | — | F5 | F5-T02, F5-T03 | Integração RPC |
| RF-12 | — | F5 | F5-T04 | Sentry smoke |
| RF-13/14 | US-05, US-06 | F6 | (planejar na F6) | N-11…N-14 |

## 7. Fora de escopo (MVP)

Receitas/menus, preço/orçamento, histórico de compras, cupons, push notifications, scan de código de barras, importação de foto/nota fiscal, app iOS (F6), desktop (F6), compartilhamento na UI (F6).

---

## Documentos relacionados
- [13 Pré-modelo Técnico](13-premodelo-tecnico.md) — contexto condensado para implementação
- [14 Tarefas](14-tarefas.md) — breakdown executável por fase
- [00 Visão Geral](00-visao-geral.md) — ADRs e riscos que embasam estes requisitos
