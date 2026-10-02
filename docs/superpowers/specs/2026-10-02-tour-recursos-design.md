# Fase 57 — Atualização do tutorial para os recursos novos (design)

> **Status:** aprovado em 02/10/2026 (decisões na Seção 8)
> **Fase:** 57 · **Requisito:** RF-27 (extensão: tour guiado cobre os recursos F49–F55)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout), [12](../12-prd.md) (PRD), [14](../14-tarefas.md) (tarefas), [15](../15-design-system.md) (tokens/componentes)
> **Origem:** o dono perguntou se o tutorial tinha sido atualizado para as melhorias/recursos novos (02/10/2026). Não tinha — o conteúdo estava congelado na F46; só os textos foram localizados na F56.

---

## 1. Motivação

1. **O roteiro do tour parou na F46.** Os passos cobrem criar/buscar/configurar e nome/adicionar/unidade/importar/marcar/mercado/orçamento, mas nada de **compartilhar lista** (RF-33), **histórico + estatísticas** (RF-34), **importar por foto/OCR** (RF-37), **preço por mercado** (RF-35), **alertas de orçamento** (RF-36), **idioma** (RF-39) e **widget** (RF-38).
2. **O Histórico é uma aba nova e sem descoberta.** `AppShell` tem 3 abas (Minhas listas, Histórico, Configurações) desde a F50; o tour não a menciona.
3. **Reaproveitar o motor da F46.** O motor (`TourController`/`TourStep`/`TourOverlay`/`TourLoader`) já suporta múltiplas etapas — uma por tela — com âncoras `GlobalKey` e flag própria. A extensão é **conteúdo + âncoras**, sem motor novo.

## 2. Escopo

**Dentro:**
- **3ª etapa** do tour na aba Histórico (resumo + estatísticas), com flag própria.
- **Etapa 1** ganha o passo da aba Histórico e atualiza o texto de Configurações (idioma + widget).
- **Etapa 2** tem os textos enriquecidos (importar por foto/OCR; mercado com preço por mercado; menu ⋮ com orçamento + compartilhar + finalizar compra + alertas).
- Âncoras novas em `TourKeys`; chaves ARB em pt/en/es.
- Docs donas (05/10/12/14) + spec + testes (widget).

**Fora:**
- Mudar o motor do tour, o `TourOverlay` ou o contrato de `TourStep` (a estrutura de 2 campos texto `titulo`/`corpo` permanece).
- Criar dados de exemplo, navegar entre rotas no meio do overlay, ou abrir menus automaticamente.
- Passo dedicado para o widget (é um recurso da **home do sistema**); entra como **menção textual** no passo de Configurações.
- Toque em Drift/schema/sync; nenhuma migration.

## 3. O que já existe (reaproveitar)

- **Motor**: `lib/features/tour/tour_controller.dart` (`TourEtapa { primeira, recursos }`, `_chave`, `TourEstado`, `TourController`), `tour_step.dart`, `tour_keys.dart`, `tour_roteiro.dart` (funções `passosEtapa1/2`), `ui/tour_loader.dart`, `ui/tour_overlay.dart`.
- **Disparo**: `TourLoader(etapa: primeira)` em `minhas_listas_screen.dart:49`; `TourLoader(etapa: recursos)` em `tela_lista_screen.dart:885`. `TourOverlay` na raiz (`app.dart:47`).
- **Persistência**: `TourVistoNotifier` (SharedPreferences `tour_etapa1_visto`/`tour_etapa2_visto`), espelho de `OnboardingNotifier`.
- **Reabrir**: Configurações → "Ver tutorial" (`tourAbrir`) navega para `/listas` e inicia a etapa 1.
- **Âncoras existentes** (`TourKeys`): `novaLista`, `lupa`, `abaConfiguracoes`, `nomeLista`, `campoAdicionar`, `seletorUnidade`, `botaoImportar`, `itemLista`, `botaoMercado`, `menuMais`.
- **Telas-alvo**: `HistoricoScreen` (`_Resumo`, `TabBar` [Idas, Estatísticas], `EstatisticasTab`), `AppShell` (abas), `configuracoes_screen.dart` (seções Aparência/Idioma/Sobre), `sheet_compartilhar.dart`, menu ⋮ da lista.

## 4. Arquitetura (mudanças)

- **`tour_controller.dart`**: `enum TourEtapa { primeira, recursos, historico }`; `_chave` mapeia `historico → 'tour_etapa3_visto'`; `_passosDe` devolve `passosEtapa3` para `historico`.
- **`tour_keys.dart`**: +`abaHistorico`, +`resumoHistorico`, +`abaEstatisticas`.
- **`tour_roteiro.dart`**: ajusta textos da etapa 2 e adiciona `passosEtapa3`; etapa 1 ganha o passo do Histórico.
- **`app_shell.dart`**: anexa `TourKeys.abaHistorico` ao destino de índice 1 (rail e barra).
- **`historico_screen.dart`**: `_Resumo` recebe `TourKeys.resumoHistorico`; a aba "Estatísticas" recebe `TourKeys.abaEstatisticas`; a tela monta `TourLoader(etapa: TourEtapa.historico)`.
- **Nenhuma** alteração em `TourStep`/`TourOverlay`/`TourLoader` (o motor já basta).
- **`app.dart`**: inalterado (o overlay já é de raiz).

**Alvo visível é pré-requisito (F46 §4):** passos cujo alvo não está montado/visível são pulados. Por isso **não** se ancora passo em `TotalCarrinho` nem no banner de alerta (ambos somem sem item marcado); total/alertas entram no **texto** do passo do menu ⋮.

## 5. Roteiro

**Etapa 1 — sem dados (home de listas) — 3 → 4 passos:**

| # | Passo | Título (pt) | Alvo |
| :-- | :-- | :-- | :-- |
| 1 | criar | Criar sua primeira lista | `novaLista` |
| 2 | busca | Busca e filtros | `lupa` |
| 3 | **histórico (novo)** | Histórico de compras | `abaHistorico` |
| 4 | config (texto+) | Configurações | `abaConfiguracoes` |

- Passo de Configurações passa a citar **idioma (pt/en/es)**, **backup** e o **widget da tela inicial**, além de "onde rever este tutorial".
- Passo do Histórico torna a aba descobrível ("suas compras finalizadas e as estatísticas ficam aqui").

**Etapa 2 — na primeira lista com itens pendentes — 7 passos (textos enriquecidos):**

| # | Passo | Título (pt) | Alvo | Mudança |
| :-- | :-- | :-- | :-- | :-- |
| 1 | nome | Dê um nome | `nomeLista` | — |
| 2 | adicionar | Adicionar item | `campoAdicionar` | — |
| 3 | unidade | Unidade | `seletorUnidade` | — |
| 4 | importar | Importar de texto ou foto | `botaoImportar` | +"ou fotografe a lista" (OCR, RF-37) |
| 5 | marcar | Marcar, editar e remover | `itemLista` | — |
| 6 | mercado | Modo mercado | `botaoMercado` | +"registre o preço pago; o app guarda o preço por mercado" (RF-35) |
| 7 | menu | Menu da lista | `menuMais` | título "Orçamento e total" → "Menu da lista"; corpo cobre orçamento, **compartilhar** (RF-33), **finalizar compra → Histórico** e os **alertas** de categoria (RF-36) |

**Etapa 3 — na aba Histórico (dispara ao abrir) — 2 passos:**

| # | Passo | Título (pt) | Alvo |
| :-- | :-- | :-- | :-- |
| 1 | resumo | Resumo das compras | `resumoHistorico` |
| 2 | estatísticas | Estatísticas | `abaEstatisticas` |

- **Não** exige compras finalizadas: `_Resumo` e o `TabBar` sempre montam (mostram "sem valor"/vazio). A etapa 3 inicia mesmo com histórico vazio.

## 6. Disparo e persistência

- **Etapa 3:** em `HistoricoScreen`, `TourLoader(etapa: TourEtapa.historico)` inicia **uma vez** se `!tour_etapa3_visto` e há alvos visíveis. Dispara quando o usuário **abre a aba** (sem navegação forçada).
- **Flags:** +`tour_etapa3_visto` (SharedPreferences) via `TourVistoNotifier`.
- **Reabrir (Configurações → "Ver tutorial"):** mantém o comportamento atual — navega para `/listas` e inicia a **etapa 1**; as etapas 2 e 3 seguem seus **gatilhos naturais** (não são forçadas dali). Não reescreve conclusões já registradas.

## 7. i18n, acessibilidade, design e testes

- **i18n (RF-39):** novas chaves ARB em `app_pt.arb` (**template/fallback**) + `app_en.arb` + `app_es.arb`; paridade de chaves obrigatória (suíte já cobra). Textos de `titulo`/`corpo` resolvidos na UI via `context.l10n` (o roteiro guarda só funções). en/es gerados por IA → **revisão humana** antes de publicar.
- **Acessibilidade (RNF-06):** sem mudança no motor; mantém anúncio do passo, alvos ≥48dp e suporte a `textScaler` 2x (os textos novos seguem o mesmo teste de não-estouro).
- **Design system:** nenhum componente/ token novo.
- **Testes (widget):**
  - roteiro: contagem por etapa; texto do passo do menu cita compartilhar/finalizar; etapa 3 tem 2 passos;
  - `_chave`/flag da etapa 3; `iniciar(historico)` só com alvos visíveis;
  - gatilho: `TourLoader` da etapa 3 dispara uma vez e não repete com a flag marcada;
  - âncoras resolvem (o passo não cai no fallback central);
  - paridade de chaves ARB pt/en/es (teste existente).

## 8. Decisões registradas (02/10/2026)

1. **Cobertura:** todos os recursos novos, incluindo menção ao widget.
2. **Estrutura:** **3ª etapa** dedicada ao Histórico (opção "completo").
3. **Compartilhar/finalizar/total/alertas:** no **texto** do passo do menu ⋮ (âncoras voláteis evitadas).
4. **Widget (RF-38):** menção textual no passo de Configurações (recurso da home do sistema).
5. **Sem navegação forçada;** etapa 3 dispara ao abrir a aba.
6. **Sem motor novo:** só conteúdo, âncoras e chaves.
7. **Fase 57**; requisito **RF-27** estendido.

## 9. Riscos

- **Texto do menu ⋮ denso:** mitigar com frases curtas (orçamento/compartilhar/finalizar; e uma frase para alertas).
- **Etapa 3 nunca vista** se o usuário não abrir a aba: mitigado pelo passo do Histórico na etapa 1 (descoberta).
- **en/es automáticas:** marcar para revisão humana antes de release.
- **Passos pulados:** se um alvo não montar (ex.: sheet de nome), o motor pula — comportamento já existente e coberto por teste.

## 10. Documentos relacionados

- [2026-09-28-tour-guiado-primeiro-uso-design.md](2026-09-28-tour-guiado-primeiro-uso-design.md) — spec original (F46, RF-27)
- [05 App Flutter](../05-app-flutter.md) §6.11 — tour (UX)
- [10 Wireframes](../10-wireframes-telas.md) — layout das telas (inclui Histórico)
- [12 PRD](../12-prd.md) — RF-27
- [14 Tarefas](../14-tarefas.md) — Fase 57
