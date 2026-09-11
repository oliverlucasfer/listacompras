# Spec — Revisão Visual e de UX (Programa, F8+)

> Navegação: [← 05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)
> Requisitos: RNF-06 (acessibilidade) do [PRD §3](../../12-prd.md); UI/UX e design system ([05 §7](../../05-app-flutter.md))

Data: 2026-09-11 · Status: aprovada (programa em 3 etapas sequenciais)

## 1. Objetivo

Elevar a qualidade visual e de experiência do app a padrões atuais, substituindo o tema Material 3 "cru" (sem tokens de componente, spacing/cantos/ícones ad-hoc e estados inconsistentes) por um **design system próprio** sobre **Material 3 Expressive**, e então redesenhar telas e navegação.

O programa é decomposto em **3 etapas sequenciais**, cada uma entregável e revisável de forma independente:

| Etapa | Nome | Resultado | Dono do doc |
| :--- | :--- | :--- | :--- |
| **1** | **Fundação (Design System)** | Tokens, `AppTheme` completo, fonte própria, biblioteca de componentes e catálogo de revisão | 15 (novo) + 05 §7 |
| **2** | **Refresh visual das telas** | Todas as telas usando tokens/componentes; estados e acessibilidade corrigidos | 10 (layout) + 05 §6 |
| **3** | **Redesign de UX/navegação** | Hierarquia, modelo de navegação, onboarding/atalhos e ajustes de fluxo | 05 (comportamento) + 10 |

Esta spec detalha a **Etapa 1** (pronta para plano) e dá visão/escopo das Etapas 2 e 3 (que ganham spec própria ao serem iniciadas).

## 2. Decisões do programa (2026-09-11)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Direção estética | **Material 3 Expressive**, evoluindo a identidade verde | Linguagem visual atual do Google; já usa Material 3; menor atrito; ganho de UX sem perder reconhecimento de marca |
| Cor primária | **Verde "mercado" evoluído** (tonal palettes M3) | Mantém marca e semântica; melhora contraste/hierarquia |
| Tipografia | **Fonte própria bundlada** — Plus Jakarta Sans (OFL) | Personalidade e legibilidade; asset local preserva offline-first e a Web |
| Modo escuro | **Claro / Escuro / Sistema** (padrão Sist.); persistido em SharedPreferences | Expectativa comum; valida o tema escuro de verdade |
| Dono do design system | **Novo doc `15-design-system.md`**; `05 §7` vira referência | Doc 05 §7 é curto; o design system ganha volume próprio |
| Escopo das telas | **Etapa 2** (visual) e **Etapa 3** (UX) separadas da fundação | Evita retrabalho; cada etapa tem sua spec/plano |
| iOS/Desktop | Fora de escopo até publicação iOS/Desktop (Fase 6+) | Foco Android/Web atuais |

## 3. Princípios de design

1. **Tokens antes de estilos locais**: nenhum valor de cor/spacing/radius/duração hardcoded na UI; tudo vem de `AppTheme`/extensões.
2. **Hierarquia clara**: um CTA primário por tela; ações destrutivas visualmente distintas e com confirmação.
3. **Feedback e movimento**: toda ação dá retorno (toque, transição, snackbar); motion com propósito (reforço de hierarquia), nunca decorativo.
4. **Acessibilidade por padrão**: contraste ≥ AA, alvos ≥ 48dp, `Semantics`/`tooltip` nos ícones, respeito à escala de texto e ao reduce-motion.
5. **Offline-first continua invisível**: estados de sync/offline têm tratamento visual de primeira classe, sem bloquear a UI.
6. **Consistência entre plataformas**: mesmo vocabulário visual em Android e Web.

## 4. Etapa 1 — Fundação (detalhada)

### 4.1. Arquitetura de tokens

Substituir o `lib/core/theme/app_theme.dart` atual por `lib/core/theme/`:

- `tokens/app_colors.dart` — seed e paletas tonais; cores semânticas ausentes no M3: `success` (sincronizado), `warning` (pendente/atenção), `info`, `offline`, cada uma com par `container` / `on*`.
- `tokens/app_spacing.dart` — escala única: `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48`.
- `tokens/app_radius.dart` — cantos M3 Expressive: `sm=8, md=12, lg=16, xl=24, xxl=28, full=999`.
- `tokens/app_elevation.dart` — níveis M3 (`0..3`) e sombras correspondentes.
- `tokens/app_motion.dart` — durações (`rapida=150ms, media=250ms, longa=400ms`) e curvas (M3 emphasized / `easeOutCubic`).
- `tokens/app_typography.dart` — `TextTheme` mapeado para Plus Jakarta Sans.
- `app_theme.dart` — monta `AppTheme.claro` / `AppTheme.escuro`: `ColorScheme.fromSeed` + **todos** os `*Theme` de componente (appBar, card, inputDecoration, filled/outlined/textButton, floatingActionButton, chip, bottomSheet, dialog, snackBar, listTile, navigationBar, progressIndicator, segmentedButton, iconButton, checkbox, radio, dropdownMenu, divider).
- `app_semantic_colors.dart` — `ThemeExtension<AppSemanticColors>` com variantes clara/escura, lidas por `Theme.of(context).extension<AppSemanticColors>()!`.

**Alternativa considerada:** pacote `flex_color_scheme` (menos código, mais dependência e menos controle) — descartado.

### 4.2. Paleta e tipografia

- **Verde evoluído**: o seed `#2E7D32` permanece como âncora de marca; o `ColorScheme.fromSeed` deriva as paletas tonais de superfícies/fundos (mais separação de camadas) e o dark usa superfícies tonais, não preto puro. O ganho "Expressive" vem dos component themes, shapes e motion — não de trocar a matiz.
- **Semânticas** (valores finais definidos na implementação, com verificação de contraste AA):
  - `success`: sync ok; `warning`: pendente/atenção; `error` reaproveita `colorScheme.error`; `info`: dicas; `offline`: banner sem conexão.
- **Plus Jakarta Sans**: baixada via asset (`.ttf` variável), declarada em `pubspec.yaml` em `assets/fonts/`, com a licença OFL no mesmo diretório.
- Escala tipográfica M3 (`display/headline/title/body/label`) aplicada no `TextTheme`; `copyWith(fontWeight: bold)` avulso deixa de ser necessário.

### 4.3. Biblioteca de componentes (`lib/core/widgets/`)

Componentes reutilizáveis que eliminam as inconsistências mapeadas (referências da auditoria):

| Componente | Substitui / resolve |
| :--- | :--- |
| `AppBotao` (filled/tonal/outlined/text/destructive) | Botões destrutivos sem `foregroundColor` e com contraste frágil (`configuracoes_screen`, `tela_membros_screen`, `minhas_listas_screen`, `tela_lista_screen`) |
| `AppBanner` (info/warning/error/offline/readonly) | `_BannerSync`, `_BannerSomenteLeitura`, `_AvisoIa`; usa `on*Container` correto |
| `AppEstadoVazio` | Estado vazio de listas e de itens (que hoje é `Text('')` para leitor) |
| `AppEstadoErro` (com retry) | Erros de carga sem ação (`tela_lista_screen`) |
| `AppCabecalhoSecao` (título + contagem) | `_CabecalhoSecao` vs `_CabecalhoGrupo` com paddings diferentes |
| `AppSheet` (padrão de bottom sheet) | Três padrões de sheet divergentes (drag handle, header, `SafeArea`) |
| `AppCampoTexto` (com erro inline) | Formulários e `ErroInline` |
| `AppCard` | Superfícies que hoje são `Container`/`Card` mistos |
| `AppChip` | Chip de papel com alvo abaixo de 48dp (`tela_membros_screen`) |
| `AppSnackBar` (undo/destructive) | SnackBars ad-hoc |
| `AppBotaoAsync` (spinner) | Spinners de tamanhos variados dentro de botões |

Complementos: `AppDialog` de confirmação destrutiva, helpers de `tooltip`/`Semantics` e transições compartilhadas.

### 4.4. Catálogo de revisão

- Rota de debug `/design` (fora da navegação de produção, atrás de `kDebugMode`) que renderiza todos os tokens e componentes em **claro/escuro** e com **escala de texto** alterada.
- Serve de base para revisão visual e para **golden tests**.

### 4.5. Docs donos e governança

- Criar **`docs/15-design-system.md`** (dono de tokens, componentes, tipografia, motion, acessibilidade) e transformar **`05 §7`** em referência.
- Atualizar o mapa de donos em `planejamento_lista_compras.md` e `AGENTS.md` (incluir 15).
- Atualizar **`10`** com as convenções visuais/tokens (dono do layout).
- Sincronizar **`00`** (lista de docs/ADR se houver decisão nova), **`13`** (resumo) e **`14`** (Fase 8).

### 4.6. Testes e CI

- Widget tests dos componentes (`AppBotao` variantes, `AppBanner` contraste, `AppEstadoVazio/Erro`, `AppSheet`, `AppCampoTexto`).
- **Golden tests** do catálogo (claro/escuro) — **recomendados** para travar regressão visual; entram se estáveis no CI (fontes/antialias variam por runner), senão ficam como execução local documentada.
- Preservar as strings via `AppStrings` para não quebrar a suíte existente; `dart format` + `flutter analyze` + `flutter test` verdes ([07 §3](../../07-qualidade-ci.md)).

### 4.7. Tarefas da Etapa 1 (`14-tarefas.md`, Fase 8)

| ID | Entrega |
| :--- | :--- |
| **F8-T00** | Spec + ajustes de docs de planejamento (00/05/10/15/13/14/index/AGENTS) — sem código |
| **F8-T01** | Tokens + `AppTheme` claro/escuro + fonte bundlada + `AppSemanticColors` |
| **F8-T02** | Biblioteca de componentes + catálogo `/design` |
| **F8-T03** | Widget tests dos componentes + CI verde; goldens do catálogo (recomendado) |

## 5. Etapa 2 — Refresh visual das telas (visão)

Aplicar tokens e componentes às 12 telas (auth, minhas listas, tela da lista, IA, configurações, convites/membros), corrigindo: superfícies, spacing, ícones, estados vazio/erro/loading, botões destrutivos, contraste de banners e acessibilidade (tooltips, `Semantics`, alvo ≥48dp). Atualiza wireframes do doc 10. Spec/plano próprios ao iniciar.

## 6. Etapa 3 — Redesign de UX/navegação (visão)

Revisar hierarquia e modelo de navegação (ex.: `NavigationBar`/destinos), atalhos e onboarding, além de ajustes de fluxo. Muda **comportamento** → dono é o doc 05, com wireframes no 10. Spec/plano próprios ao iniciar, e sujeito ao gate de publicação ([14](../../14-tarefas.md): F5-T05/T06 sob solicitação explícita).

## 7. Fora de escopo

- iOS e Desktop (até suas fases).
- Login social e i18n multidioma.
- Redesenho de features de backend/sync/IA (não muda contrato nem schema).

## 8. Impacto em docs donos

| Doc | Mudança |
| :--- | :--- |
| **15 (novo)** | Dono do design system: tokens, componentes, tipografia, motion, acessibilidade |
| **05** | §7 passa a referenciar o 15; §6 (telas) atualizado nas Etapas 2/3 |
| **10** | Convenções visuais/tokens; wireframes atualizados na Etapa 2 |
| **00** | Lista de docs; ADR nova se houver decisão arquitetural |
| **13** | Resumo do design system e da Fase 8 |
| **14** | Fase 8 com F8-T00..T03 |
| **12** | §5 (mapa do design) aponta o design system para o 15; RNF-06 verificado pelo 15 |
| **AGENTS.md / index** | Mapa de donos inclui o 15 |

## 9. Riscos e mitigação

| # | Risco | Mitigação |
| :--- | :--- | :--- |
| V-01 | Nem toda API do M3 Expressive existe no Flutter 3.44.5 | Usar o disponível e aproximar shapes/cores via tokens; sem bloquear |
| V-02 | Assets de fonte aumentam o bundle / config errada em Web | Fonte variável única (~200–400KB), declarada no pubspec e validada no build Web |
| V-03 | 223 testes existentes quebram com o novo tema | Manter strings/semântica; ajustar testes verdes, sem enfraquecer asserções |
| V-04 | Escopo grande | 3 etapas sequenciais, cada uma entregável e revisável |
| V-05 | Contraste AA nas cores semânticas | Validar pares `container`/`on*` em claro e escuro nos testes/goldens |

## 10. Critério de pronto do programa

Etapa 1: app compila com o novo tema e a fonte; biblioteca e catálogo `/design` funcionando; `format`/`analyze`/`test` verdes; docs 15/05/10/00/12/13/14 atualizados.
Etapas 2 e 3: telas redesenhadas conforme seus wireframes, acessibilidade AA verificada e suíte de testes verde.

## 11. Referências

- [05 App Flutter §6–7](../../05-app-flutter.md) — dono de comportamento/UX e design system atual
- [10 Wireframes](../../10-wireframes-telas.md) — dono do layout
- [07 Qualidade & CI](../../07-qualidade-ci.md) — como verificar
- [14 Tarefas](../../14-tarefas.md) — breakdown e progresso
