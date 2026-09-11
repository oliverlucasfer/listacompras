# Revisão Visual e de UX — Etapa 1 (Fundação) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estabelecer a fundação do design system (tokens, tema Material 3 Expressive claro/escuro, fonte Plus Jakarta Sans, biblioteca de componentes e catálogo de revisão) sem ainda redesenhar as telas.

**Architecture:** Tokens puros em `lib/core/theme/tokens/`; `AppTheme` monta `ThemeData` claro/escuro com component themes e `ThemeExtension<AppSemanticColors>`; preferência de tema persistida em SharedPreferences via `AsyncNotifierProvider`; componentes reutilizáveis em `lib/core/widgets/`; catálogo de revisão em rota `/design` atrás de `kDebugMode`.

**Tech Stack:** Flutter 3.44.5 · Dart 3.12.2 · flutter_riverpod 3.4.2 · shared_preferences · go_router 18 · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-11-revisao-visual-ux-design.md`

## Global Constraints

- Material 3 com `useMaterial3: true`; claro **e** escuro sempre em paridade.
- Direção **M3 Expressive**: shapes arredondados, cores tonais, motion com propósito. Seed verde `#2E7D32` mantido.
- Fonte **Plus Jakarta Sans** bundlada em `assets/fonts/` (pesos 400/500/600/700/800) + `OFL.txt`. Sem `google_fonts`.
- **Nenhum** valor de cor/spacing/radius/duração hardcoded na UI: sempre via tokens/`AppTheme`.
- Nomes de arquivos `snake_case`; classes Dart em `PascalCase`; português (pt-BR) em textos e comentários.
- Testes no padrão `deve_<resultado>_quando_<condição>`.
- Nenhuma chave/segredo em código, commit ou log.
- Offline-first preservado (não introduzir dependência de rede).
- CI exige `dart format --set-exit-if-changed .`, `flutter analyze` e `flutter test` verdes.
- Doc dono atualizado no mesmo PR: criar `docs/15-design-system.md`; atualizar 05/10/00/12/13/14/index/AGENTS.
- Comentários de código apenas quando indispensáveis (doc comments curtos referenciando o doc 15, seguindo o padrão do repo).

---

## File Structure

**Criar**
- `docs/15-design-system.md` — dono do design system
- `assets/fonts/PlusJakartaSans-*.ttf`, `assets/fonts/OFL.txt`
- `lib/core/theme/tokens/app_colors.dart`
- `lib/core/theme/tokens/app_spacing.dart`
- `lib/core/theme/tokens/app_radius.dart`
- `lib/core/theme/tokens/app_elevation.dart`
- `lib/core/theme/tokens/app_motion.dart`
- `lib/core/theme/tokens/app_typography.dart`
- `lib/core/theme/app_semantic_colors.dart`
- `lib/core/theme/theme_mode_provider.dart`
- `lib/core/theme/seletor_tema.dart`
- `lib/core/widgets/app_botao.dart`
- `lib/core/widgets/app_dialog.dart`
- `lib/core/widgets/app_banner.dart`
- `lib/core/widgets/app_card.dart`
- `lib/core/widgets/app_chip.dart`
- `lib/core/widgets/app_cabecalho_secao.dart`
- `lib/core/widgets/app_estado_vazio.dart`
- `lib/core/widgets/app_estado_erro.dart`
- `lib/core/widgets/app_campo_texto.dart`
- `lib/core/widgets/app_sheet.dart`
- `lib/core/widgets/app_snack_bar.dart`
- `lib/features/design_system/ui/design_system_screen.dart`
- Testes correspondentes em `test/core/theme/`, `test/core/widgets/`, `test/features/design_system/`

**Modificar**
- `lib/core/theme/app_theme.dart` — passará a usar os tokens e montar os dois temas
- `lib/main.dart` — `themeMode` reativo
- `lib/router.dart` — rota `/design` (debug)
- `lib/features/configuracoes/ui/configuracoes_screen.dart` — seção "Aparência"
- `lib/core/l10n/app_strings.dart` — strings do seletor de tema
- `pubspec.yaml` — fontes
- `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/00-visao-geral.md`, `docs/12-prd.md`, `docs/13-premodelo-tecnico.md`, `docs/14-tarefas.md`, `planejamento_lista_compras.md`, `AGENTS.md`

---

## Task 0: Documentação e planejamento (F8-T00)

**Files:**
- Create: `docs/15-design-system.md`
- Modify: `docs/05-app-flutter.md` (§7 → referência), `docs/10-wireframes-telas.md`, `docs/00-visao-geral.md`, `docs/12-prd.md`, `docs/13-premodelo-tecnico.md`, `docs/14-tarefas.md`, `planejamento_lista_compras.md`, `AGENTS.md`

**Interfaces:**
- Produces: doc dono do design system que as Tasks 1–8 referenciam.

- [ ] **Step 1: Criar `docs/15-design-system.md`**

Conteúdo (pt-BR):

```markdown
# 15 — Design System

> Navegação: [← 14 Tarefas](14-tarefas.md) · [← Índice](../planejamento_lista_compras.md)
> Spec: [superpowers/specs/2026-09-11-revisao-visual-ux-design.md](superpowers/specs/2026-09-11-revisao-visual-ux-design.md)

**Este documento é o dono do design system** (tokens, tipografia, componentes, motion, acessibilidade). Fundação: Material 3 Expressive sobre seed verde `#2E7D32`. Comportamento/UX continua em [05 §6](05-app-flutter.md); layout de telas em [10](10-wireframes-telas.md); verificação de acessibilidade (RNF-06) em [12 §3](12-prd.md).

## 1. Tokens

Fonte única em `lib/core/theme/tokens/` — proibido valor hardcoded na UI.

| Arquivo | Tokens |
| :--- | :--- |
| `app_colors.dart` | seed + paleta semântica (success/warning/info) clara/escura |
| `app_spacing.dart` | `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48` |
| `app_radius.dart` | `sm=8, md=12, lg=16, xl=24, xxl=28, full=999` |
| `app_elevation.dart` | níveis M3 `0..3` |
| `app_motion.dart` | `rapida=150ms, media=250ms, longa=400ms`; curva padrão `easeInOutCubicEmphasized` |
| `app_typography.dart` | `TextTheme` com `PlusJakartaSans` |

## 2. Tema

- `AppTheme.claro` / `AppTheme.escuro` (`lib/core/theme/app_theme.dart`).
- `ColorScheme.fromSeed` + component themes (appBar, card, input, botões, chip, sheet, dialog, snackbar, navigationBar, etc.).
- Cores semânticas via `ThemeExtension<AppSemanticColors>` (`lib/core/theme/app_semantic_colors.dart`), lidas com `Theme.of(context).extension<AppSemanticColors>()!`.
- Modo: Claro / Escuro / Sistema (padrão Sistema), persistido em SharedPreferences (`theme_mode_provider.dart`), seletor em Configurações (`seletor_tema.dart`).

## 3. Componentes (`lib/core/widgets/`)

| Componente | Uso |
| :--- | :--- |
| `AppBotao` | Ações (filled/tonal/outlined/texto/destrutivo), com `carregando` |
| `AppDialog.confirmarDestrutivo` | Confirmação de ação destrutiva |
| `AppBanner` | info/aviso/erro/offline/leitura com contraste correto |
| `AppCard` | Superfície padrão com padding/radius |
| `AppChip` | Chip com alvo ≥48dp |
| `AppCabecalhoSecao` | Cabeçalho de seção (`título (n)`) |
| `AppEstadoVazio` | Vazio com ícone + texto + CTA |
| `AppEstadoErro` | Erro de carga com retry |
| `AppCampoTexto` | Campo de formulário com erro inline |
| `AppSheet.mostrar` | Bottom sheet padrão |
| `AppSnackBar` | Snackbar (inclusive undo) |

## 4. Acessibilidade (RNF-06)

- Contraste ≥ AA nos pares `container`/`on*`.
- Alvos de toque ≥ 48dp.
- `tooltip`/`Semantics` em ícones.
- Respeito à escala de texto do sistema.

## 5. Catálogo

Rota de debug `/design` (`kDebugMode`) renderiza tokens e componentes em claro/escuro — base para revisão visual.
```

- [ ] **Step 2: Atualizar `docs/05-app-flutter.md` §7**

Substituir o conteúdo do bloco "## 7. Design System" existente por:

```markdown
## 7. Design System

O design system (tokens, tipografia, componentes, motion, acessibilidade) é
propriedade do **[doc 15](15-design-system.md)**. Resumo: Material 3 Expressive
com seed verde, claro/escuro com paridade, modo Claro/Escuro/Sistema e fonte
Plus Jakarta Sans bundlada. Aqui ficam apenas os estados transversais:

| Estado | Componente padrão (doc 15) |
| :--- | :--- |
| Carregando | `AppBotao(carregando: true)` / `CircularProgressIndicator` |
| Vazio | `AppEstadoVazio` |
| Erro | `AppEstadoErro` (com retry) |
| Offline | `AppBanner.offline` ([03 §6](03-sincronizacao-offline.md)) |
```

- [ ] **Step 3: Atualizar `docs/10-wireframes-telas.md`**

Adicionar logo após a linha de convenções (§1, antes de "## 1. Autenticação"):

```markdown
**Convenções visuais:** espaçamento, raios, cores e tipografia vêm dos tokens do [doc 15](15-design-system.md) — os wireframes são ASCII e não fixam valores visuais. Banners/estados usam `AppBanner`/`AppEstadoVazio`/`AppEstadoErro` do doc 15.
```

- [ ] **Step 4: Atualizar `planejamento_lista_compras.md`**

Na tabela de Documentos, após a linha do `[14]`, adicionar:

```markdown
| [15](docs/15-design-system.md) | **Design System** | Tokens, tema M3 Expressive, componentes, motion e acessibilidade | Design system (tokens, componentes, acessibilidade) |
```

E na seção "Cronograma (resumo)", acrescentar o item:

```markdown
7. **Revisão visual e UX** — design system, refresh das telas e navegação (Fase 8+, spec em `docs/superpowers/specs/2026-09-11-revisao-visual-ux-design.md`).
```

- [ ] **Step 5: Atualizar `AGENTS.md`**

Na linha de "Doc dono é autoridade:" das Regras não negociáveis, acrescentar `design system em 15` após `app/UX em 05`. Exemplo de trecho final:

```markdown
- **Doc dono é autoridade:** schema em `01`, RLS em `02`, sync em `03`, IA em `04`, app/UX em `05`, design system em `15`, entregas/LGPD em `06`, qualidade em `07`, compartilhamento em `08`, operação em `09`, layout em `10`, usabilidade em `11`, requisitos em `12`. Mudança de comportamento exige atualizar o doc dono **no mesmo PR**. `13` é resumo — nunca sobrepõe o dono.
```

- [ ] **Step 6: Atualizar `docs/12-prd.md` §5**

Na tabela do "Mapa do Design", adicionar a linha:

```markdown
| Design System (tokens, componentes) | [15](15-design-system.md) | Material 3 Expressive, componentes, acessibilidade |
```

E no RNF-06, trocar a verificação de `Revisão de UI ([05 §7](05-app-flutter.md))` para `Revisão de UI ([15 §4](15-design-system.md))`.

- [ ] **Step 7: Atualizar `docs/00-visao-geral.md`**

Na tabela do "## 6. Cronograma de Execução por Fases", adicionar após a Fase 6:

```markdown
| **Fase 8** | **Revisão Visual e de UX** | Design system (tokens, M3 Expressive, fonte, componentes), refresh das telas e redesign de navegação. | Etapa 1 (fundação) entregue, CI verde · Spec em `docs/superpowers/specs/2026-09-11-revisao-visual-ux-design.md` |
```

E na "## Documentos relacionados", adicionar `- [15 Design System](15-design-system.md) — tokens, componentes, acessibilidade`.

- [ ] **Step 8: Atualizar `docs/13-premodelo-tecnico.md`**

Adicionar uma seção curta (antes de "## Documentos relacionados", se existir):

```markdown
## Design System (doc 15)

Material 3 Expressive, seed verde `#2E7D32`, fonte Plus Jakarta Sans bundlada,
claro/escuro com paridade, modo Claro/Escuro/Sistema (SharedPreferences) e a
biblioteca `App*` em `lib/core/widgets/`. Tokens em `lib/core/theme/tokens/`.
Detalhes: [15](15-design-system.md).
```

- [ ] **Step 9: Atualizar `docs/14-tarefas.md`**

Adicionar, após o último bloco da Fase 7 (antes de "## Progresso por fase"):

```markdown
## Fase 8 — Revisão Visual e de UX (spec em [superpowers/specs](superpowers/specs/2026-09-11-revisao-visual-ux-design.md))

- [ ] **F8-T00** — Spec + ajustes de docs de planejamento
  Dep: — · Docs: spec da fase
  CP: docs 15/05/10/00/12/13/14/index/AGENTS consistentes entre si, sem tocar código.
- [ ] **F8-T01** — Tokens + `AppTheme` claro/escuro + fonte bundlada + cores semânticas + seletor de tema
  Dep: F8-T00 · Docs: [15](15-design-system.md) · RNF-06
  CP: tema claro/escuro com paridade, extensão semântica presente, fonte Plus Jakarta Sans aplicada, modo persistido; `analyze`/`test` verdes.
- [ ] **F8-T02** — Biblioteca de componentes (`App*`) + catálogo `/design`
  Dep: F8-T01 · Docs: [15 §3](15-design-system.md)
  CP: componentes do doc 15 renderizam em claro/escuro; catálogo em `kDebugMode`.
- [ ] **F8-T03** — Testes dos componentes + CI verde
  Dep: F8-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: widget tests dos componentes e do seletor; `format`/`analyze`/`test` verdes.
```

E na tabela "## Progresso por fase", adicionar a linha:

```markdown
| F8 Design System | 4 | 0 |
```

Atualizar também a linha `| **Total** | **53** | **51** |` para `| **Total** | **57** | **51** |`.

- [ ] **Step 10: Commit da documentação**

```bash
git add docs/15-design-system.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/00-visao-geral.md docs/12-prd.md docs/13-premodelo-tecnico.md docs/14-tarefas.md planejamento_lista_compras.md AGENTS.md
git commit -m "F8-T00: docs do design system e planejamento da fase 8 (RNF-06)"
```

---

## Task 1: Fonte bundlada e tokens (F8-T01)

**Files:**
- Create: `assets/fonts/PlusJakartaSans-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `-ExtraBold.ttf`, `assets/fonts/OFL.txt`
- Create: `lib/core/theme/tokens/app_colors.dart`, `app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`, `app_motion.dart`, `app_typography.dart`
- Modify: `pubspec.yaml`
- Test: `test/core/theme/tokens_test.dart`

**Interfaces:**
- Produces: `AppColors.seed`, `AppColors.*` (semânticas), `AppSpacing.{xs,sm,md,lg,xl,xxl,xxxl}`, `AppRadius.{sm,md,lg,xl,xxl,full}`, `AppElevation.{nivel0..nivel3}`, `AppMotion.{rapida,media,longa,padrao}`, `AppTypography.textTheme`.

- [ ] **Step 1: Baixar a fonte e a licença**

Run (PowerShell, na raiz do repo):

```powershell
New-Item -ItemType Directory -Force -Path assets/fonts | Out-Null
$base = 'https://github.com/tokotype/PlusJakartaSans/raw/master/fonts/ttf'
foreach ($w in 'Regular','Medium','SemiBold','Bold','ExtraBold') {
  Invoke-WebRequest "$base/PlusJakartaSans-$w.ttf" -OutFile "assets/fonts/PlusJakartaSans-$w.ttf"
}
Invoke-WebRequest 'https://raw.githubusercontent.com/tokotype/PlusJakartaSans/master/OFL.txt' -OutFile 'assets/fonts/OFL.txt'
Get-ChildItem assets/fonts | Select-Object Name, Length
```

Esperado: 5 `.ttf` (~100–180KB cada) e `OFL.txt`.

- [ ] **Step 2: Escrever o teste que falha**

`test/core/theme/tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/tokens/app_elevation.dart';
import 'package:lista_compras/core/theme/tokens/app_motion.dart';
import 'package:lista_compras/core/theme/tokens/app_radius.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/core/theme/tokens/app_typography.dart';

void main() {
  test('deve_ter_escala_de_espacamento_em_multiplos_de_4', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 12);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.xl, 24);
    expect(AppSpacing.xxl, 32);
    expect(AppSpacing.xxxl, 48);
  });

  test('deve_ter_escala_de_raios_crescente', () {
    expect(AppRadius.sm, lessThan(AppRadius.md));
    expect(AppRadius.md, lessThan(AppRadius.lg));
    expect(AppRadius.lg, lessThan(AppRadius.xl));
    expect(AppRadius.xl, lessThan(AppRadius.xxl));
    expect(AppRadius.full, greaterThan(AppRadius.xxl));
  });

  test('deve_ter_niveis_de_elevacao_em_ordem', () {
    expect(AppElevation.nivel0, 0);
    expect(
      AppElevation.nivel0,
      lessThanOrEqualTo(AppElevation.nivel3),
    );
  });

  test('deve_ter_duracoes_de_motion_com_a_curva_padrao', () {
    expect(AppMotion.rapida.inMilliseconds, lessThan(AppMotion.media.inMilliseconds));
    expect(AppMotion.media.inMilliseconds, lessThan(AppMotion.longa.inMilliseconds));
    expect(AppMotion.padrao, isA<Curve>());
  });

  test('deve_usar_fonte_plus_jakarta_sans_no_text_theme', () {
    final estilo = AppTypography.textTheme.bodyLarge;
    expect(estilo?.fontFamily, 'PlusJakartaSans');
  });
}
```

- [ ] **Step 3: Rodar o teste para ver falhar**

Run: `flutter test test/core/theme/tokens_test.dart`
Expected: FAIL (imports não existem).

- [ ] **Step 4: Implementar os tokens**

`lib/core/theme/tokens/app_spacing.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Escala de espaçamento (doc 15 §1). Único lugar com valores de espaçamento.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets tela = EdgeInsets.all(lg);
  static const EdgeInsets horizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalCompacto =
      EdgeInsets.symmetric(horizontal: md);
}
```

`lib/core/theme/tokens/app_radius.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Escala de raios (doc 15 §1) — mais arredondada (M3 Expressive).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;

  static const BorderRadius smTodos = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdTodos = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgTodos = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlTodos = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlTodos = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullTodos = BorderRadius.all(Radius.circular(full));
}
```

`lib/core/theme/tokens/app_elevation.dart`:

```dart
/// Níveis de elevação (doc 15 §1), alinhados aos níveis M3.
abstract final class AppElevation {
  static const double nivel0 = 0;
  static const double nivel1 = 1;
  static const double nivel2 = 3;
  static const double nivel3 = 6;
}
```

`lib/core/theme/tokens/app_motion.dart`:

```dart
import 'package:flutter/animation.dart';

/// Durações e curvas de movimento (doc 15 §1).
abstract final class AppMotion {
  static const Duration rapida = Duration(milliseconds: 150);
  static const Duration media = Duration(milliseconds: 250);
  static const Duration longa = Duration(milliseconds: 400);

  static const Curve padrao = Curves.easeInOutCubicEmphasized;
  static const Curve entrada = Curves.easeOutCubic;
  static const Curve saida = Curves.easeInCubic;
}
```

`lib/core/theme/tokens/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Paleta base e cores semânticas (doc 15 §1).
abstract final class AppColors {
  static const seed = Color(0xFF2E7D32);

  // Semânticas — claro
  static const successClaro = Color(0xFF3B6939);
  static const onSuccessClaro = Color(0xFFFFFFFF);
  static const successContainerClaro = Color(0xFFBDF0B4);
  static const onSuccessContainerClaro = Color(0xFF00210B);

  static const warningClaro = Color(0xFF7A5900);
  static const onWarningClaro = Color(0xFFFFFFFF);
  static const warningContainerClaro = Color(0xFFFFDEA6);
  static const onWarningContainerClaro = Color(0xFF261A00);

  static const infoClaro = Color(0xFF00639B);
  static const onInfoClaro = Color(0xFFFFFFFF);
  static const infoContainerClaro = Color(0xFFCFE5FF);
  static const onInfoContainerClaro = Color(0xFF001D34);

  // Semânticas — escuro
  static const successEscuro = Color(0xFFA1D39A);
  static const onSuccessEscuro = Color(0xFF0B390C);
  static const successContainerEscuro = Color(0xFF235024);
  static const onSuccessContainerEscuro = Color(0xFFBDF0B4);

  static const warningEscuro = Color(0xFFF2C14E);
  static const onWarningEscuro = Color(0xFF3F2E00);
  static const warningContainerEscuro = Color(0xFF5C4300);
  static const onWarningContainerEscuro = Color(0xFFFFDEA6);

  static const infoEscuro = Color(0xFF95CCFF);
  static const onInfoEscuro = Color(0xFF003354);
  static const infoContainerEscuro = Color(0xFF004A77);
  static const onInfoContainerEscuro = Color(0xFFCFE5FF);
}
```

`lib/core/theme/tokens/app_typography.dart`:

```dart
import 'package:flutter/material.dart';

/// Tipografia do app (doc 15 §1) — Plus Jakarta Sans bundlada.
abstract final class AppTypography {
  static const family = 'PlusJakartaSans';

  static TextTheme get textTheme =>
      Typography.material2021().black.apply(fontFamily: family);
}
```

- [ ] **Step 5: Declarar as fontes no `pubspec.yaml`**

No bloco `flutter:`, após `uses-material-design: true`, adicionar:

```yaml
  fonts:
    - family: PlusJakartaSans
      fonts:
        - asset: assets/fonts/PlusJakartaSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/PlusJakartaSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/PlusJakartaSans-Bold.ttf
          weight: 700
        - asset: assets/fonts/PlusJakartaSans-ExtraBold.ttf
          weight: 800
```

- [ ] **Step 6: Rodar o teste para ver passar**

Run: `flutter test test/core/theme/tokens_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 7: Rodar format/analyze e commit**

```bash
dart format lib/core/theme/tokens test/core/theme/tokens_test.dart
flutter analyze
git add pubspec.yaml pubspec.lock assets/fonts lib/core/theme/tokens test/core/theme/tokens_test.dart
git commit -m "F8-T01: fonte Plus Jakarta Sans e tokens do design system (RNF-06)"
```

---

## Task 2: `AppTheme` claro/escuro e cores semânticas (F8-T01)

**Files:**
- Create: `lib/core/theme/app_semantic_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: tokens da Task 1.
- Produces: `AppTheme.claro`, `AppTheme.escuro`; `AppSemanticColors` com `success`, `onSuccess`, `successContainer`, `onSuccessContainer`, `warning`, `onWarning`, `warningContainer`, `onWarningContainer`, `info`, `onInfo`, `infoContainer`, `onInfoContainer`; `AppSemanticColors.claro` e `.escuro`.

- [ ] **Step 1: Escrever o teste que falha**

`test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_semantic_colors.dart';
import 'package:lista_compras/core/theme/app_theme.dart';

void main() {
  test('deve_ter_brilho_claro_quando_tema_claro', () {
    expect(AppTheme.claro.brightness, Brightness.light);
  });

  test('deve_ter_brilho_escuro_quando_tema_escuro', () {
    expect(AppTheme.escuro.brightness, Brightness.dark);
  });

  test('deve_expor_extensao_semantica_em_ambos_os_temas', () {
    expect(
      AppTheme.claro.extension<AppSemanticColors>(),
      isNotNull,
    );
    expect(
      AppTheme.escuro.extension<AppSemanticColors>(),
      isNotNull,
    );
  });

  test('deve_diferir_cor_de_sucesso_entre_claro_e_escuro', () {
    final claro = AppTheme.claro.extension<AppSemanticColors>()!;
    final escuro = AppTheme.escuro.extension<AppSemanticColors>()!;
    expect(claro.success, isNot(equals(escuro.success)));
  });

  test('deve_usar_material_3_e_a_fonte_bundlada', () {
    expect(AppTheme.claro.useMaterial3, isTrue);
    expect(AppTheme.claro.textTheme.bodyLarge?.fontFamily, 'PlusJakartaSans');
  });
}
```

- [ ] **Step 2: Rodar o teste para ver falhar**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL (AppTheme.claro/escuro e AppSemanticColors não existem).

- [ ] **Step 3: Implementar `AppSemanticColors`**

`lib/core/theme/app_semantic_colors.dart`:

```dart
import 'package:flutter/material.dart';

import 'tokens/app_colors.dart';

/// Cores semânticas ausentes no ColorScheme do M3 (doc 15 §2).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  static const claro = AppSemanticColors(
    success: AppColors.successClaro,
    onSuccess: AppColors.onSuccessClaro,
    successContainer: AppColors.successContainerClaro,
    onSuccessContainer: AppColors.onSuccessContainerClaro,
    warning: AppColors.warningClaro,
    onWarning: AppColors.onWarningClaro,
    warningContainer: AppColors.warningContainerClaro,
    onWarningContainer: AppColors.onWarningContainerClaro,
    info: AppColors.infoClaro,
    onInfo: AppColors.onInfoClaro,
    infoContainer: AppColors.infoContainerClaro,
    onInfoContainer: AppColors.onInfoContainerClaro,
  );

  static const escuro = AppSemanticColors(
    success: AppColors.successEscuro,
    onSuccess: AppColors.onSuccessEscuro,
    successContainer: AppColors.successContainerEscuro,
    onSuccessContainer: AppColors.onSuccessContainerEscuro,
    warning: AppColors.warningEscuro,
    onWarning: AppColors.onWarningEscuro,
    warningContainer: AppColors.warningContainerEscuro,
    onWarningContainer: AppColors.onWarningContainerEscuro,
    info: AppColors.infoEscuro,
    onInfo: AppColors.onInfoEscuro,
    infoContainer: AppColors.infoContainerEscuro,
    onInfoContainer: AppColors.onInfoContainerEscuro,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}
```

- [ ] **Step 4: Reescrever `lib/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// Tema do app (doc 15 §2): Material 3 Expressive, claro/escuro com paridade.
abstract final class AppTheme {
  static ThemeData get claro =>
      _base(Brightness.light, AppSemanticColors.claro);

  static ThemeData get escuro =>
      _base(Brightness.dark, AppSemanticColors.escuro);

  static ThemeData _base(Brightness brightness, AppSemanticColors semanticas) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final texto = AppTypography.textTheme;
    final botaoShape = const RoundedRectangleBorder(
      borderRadius: AppRadius.fullTodos,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: texto,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: <ThemeExtension<dynamic>>[semanticas],
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: AppElevation.nivel0,
        scrolledUnderElevation: AppElevation.nivel2,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.nivel1,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgTodos),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: const OutlineInputBorder(borderRadius: AppRadius.mdTodos),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdTodos,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdTodos,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: botaoShape,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: botaoShape,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgTodos),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xxlTodos),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdTodos),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: AppElevation.nivel2,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.xl,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smTodos),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
```

- [ ] **Step 5: Rodar o teste para ver passar**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 6: Garantir que a suíte existente segue verde**

Run: `flutter analyze; flutter test`
Expected: analyze limpo; todos os testes verdes.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/theme test/core/theme
git add lib/core/theme/app_theme.dart lib/core/theme/app_semantic_colors.dart test/core/theme/app_theme_test.dart
git commit -m "F8-T01: AppTheme Material 3 Expressive e cores semanticas (RNF-06)"
```

---

## Task 3: Preferência de tema e seletor em Configurações (F8-T01)

**Files:**
- Create: `lib/core/theme/theme_mode_provider.dart`, `lib/core/theme/seletor_tema.dart`
- Modify: `lib/main.dart`, `lib/core/l10n/app_strings.dart`, `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Test: `test/core/theme/theme_mode_provider_test.dart`, `test/core/theme/seletor_tema_test.dart`

**Interfaces:**
- Consumes: `AppTheme` (Task 2).
- Produces: `temaModoProvider` (`AsyncNotifierProvider<TemaModoNotifier, ThemeMode>`), `TemaModoNotifier.definir(ThemeMode)`, `temaModoDeString(String?)`, `temaModoParaString(ThemeMode)`, widget `SeletorTema`.

- [ ] **Step 1: Adicionar strings**

Em `lib/core/l10n/app_strings.dart`, na seção `// Configurações`, adicionar:

```dart
  static const aparencia = 'Aparência';
  static const temaClaro = 'Claro';
  static const temaEscuro = 'Escuro';
  static const temaSistema = 'Sistema';
```

- [ ] **Step 2: Escrever os testes que falham**

`test/core/theme/theme_mode_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deve_retornar_sistema_quando_sem_preferencia', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(temaModoProvider.future), ThemeMode.system);
  });

  test('deve_ler_modo_escuro_quando_salvo', () async {
    SharedPreferences.setMockInitialValues({'tema_modo': 'escuro'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(temaModoProvider.future), ThemeMode.dark);
  });

  test('deve_persistir_modo_escolhido_quando_definir', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(temaModoProvider.future);
    await container.read(temaModoProvider.notifier).definir(ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tema_modo'), 'claro');
  });

  test('deve_mapear_strings_desconhecidas_para_sistema', () {
    expect(temaModoDeString(null), ThemeMode.system);
    expect(temaModoDeString('qualquer'), ThemeMode.system);
    expect(temaModoParaString(ThemeMode.dark), 'escuro');
  });
}
```

`test/core/theme/seletor_tema_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/seletor_tema.dart';
import 'package:lista_compras/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_definir_modo_escuro_quando_tocar_em_escuro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorTema())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.temaEscuro));
    await tester.pumpAndSettle();

    expect(container.read(temaModoProvider).value, ThemeMode.dark);
  });
}
```

- [ ] **Step 3: Rodar os testes para ver falhar**

Run: `flutter test test/core/theme/theme_mode_provider_test.dart test/core/theme/seletor_tema_test.dart`
Expected: FAIL (arquivos não existem).

- [ ] **Step 4: Implementar o provider**

`lib/core/theme/theme_mode_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = 'tema_modo';

ThemeMode temaModoDeString(String? valor) => switch (valor) {
  'claro' => ThemeMode.light,
  'escuro' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String temaModoParaString(ThemeMode modo) => switch (modo) {
  ThemeMode.light => 'claro',
  ThemeMode.dark => 'escuro',
  ThemeMode.system => 'sistema',
};

class TemaModoNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return temaModoDeString(prefs.getString(_chave));
  }

  Future<void> definir(ThemeMode modo) async {
    state = AsyncData(modo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, temaModoParaString(modo));
  }
}

final temaModoProvider =
    AsyncNotifierProvider<TemaModoNotifier, ThemeMode>(TemaModoNotifier.new);
```

- [ ] **Step 5: Implementar o seletor**

`lib/core/theme/seletor_tema.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import 'theme_mode_provider.dart';

/// Seletor de aparência (doc 15 §2): Claro / Escuro / Sistema.
class SeletorTema extends ConsumerWidget {
  const SeletorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(temaModoProvider).valueOrNull ?? ThemeMode.system;
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text(AppStrings.temaClaro),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(AppStrings.temaSistema),
          icon: Icon(Icons.brightness_auto_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(AppStrings.temaEscuro),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {atual},
      onSelectionChanged: (selecao) =>
          ref.read(temaModoProvider.notifier).definir(selecao.first),
    );
  }
}
```

- [ ] **Step 6: Ligar o modo ao `MaterialApp`**

Em `lib/main.dart`, adicionar o import e trocar o `MaterialApp.router`:

```dart
import 'core/theme/theme_mode_provider.dart';
```

```dart
    final router = ref.watch(routerProvider);
    final modoTema = ref.watch(temaModoProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp.router(
      title: AppStrings.appNome,
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: modoTema,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
```

- [ ] **Step 7: Adicionar a seção "Aparência" em Configurações**

Em `lib/features/configuracoes/ui/configuracoes_screen.dart`, adicionar imports:

```dart
import '../../../core/theme/seletor_tema.dart';
import '../../../core/theme/tokens/app_spacing.dart';
```

No `ListView` do `build`, antes de `const _CabecalhoSecao(AppStrings.conta),`, inserir:

```dart
          const _CabecalhoSecao(AppStrings.aparencia),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SeletorTema(),
          ),
```

- [ ] **Step 8: Rodar os testes para ver passar**

Run: `flutter test test/core/theme`
Expected: PASS (todos os testes de tema).

- [ ] **Step 9: Rodar a suíte completa e commit**

```bash
dart format lib test
flutter analyze
flutter test
git add lib/main.dart lib/core/theme lib/core/l10n/app_strings.dart lib/features/configuracoes/ui/configuracoes_screen.dart test/core/theme
git commit -m "F8-T01: seletor de tema Claro/Escuro/Sistema persistido (RNF-06)"
```

---

## Task 4: Componentes de ação — `AppBotao` e `AppDialog` (F8-T02)

**Files:**
- Create: `lib/core/widgets/app_botao.dart`, `lib/core/widgets/app_dialog.dart`
- Test: `test/core/widgets/app_botao_test.dart`

**Interfaces:**
- Consumes: tokens e tema (Tasks 1–2).
- Produces: `AppBotao({required String rotulo, VoidCallback? onPressed, IconData? icone, AppBotaoVariante variante = AppBotaoVariante.filled, bool carregando = false, bool expandido = true})`; enum `AppBotaoVariante { filled, tonal, outlined, texto, destrutivo }`; `Future<bool> AppDialog.confirmarDestrutivo(BuildContext context, {required String titulo, required String mensagem, String confirmar = AppStrings.excluir, String cancelar = AppStrings.cancelar})`.

- [ ] **Step 1: Escrever o teste que falha**

`test/core/widgets/app_botao_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_botao.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('deve_disparar_callback_quando_tocado', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      _app(AppBotao(rotulo: 'Salvar', onPressed: () => tocado = true)),
    );
    await tester.tap(find.text('Salvar'));
    expect(tocado, isTrue);
  });

  testWidgets('deve_exibir_spinner_e_bloquear_quando_carregando', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      _app(
        AppBotao(
          rotulo: 'Salvar',
          carregando: true,
          onPressed: () => tocado = true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    expect(tocado, isFalse);
  });

  testWidgets('deve_usar_cores_de_erro_quando_variante_destrutiva', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppBotao(
          rotulo: AppStrings.excluir,
          variante: AppBotaoVariante.destrutivo,
          onPressed: () {},
        ),
      ),
    );
    final botao = tester.widget<FilledButton>(find.byType(FilledButton));
    final contexto = tester.element(find.byType(FilledButton));
    final cores = Theme.of(contexto).colorScheme;
    expect(botao.style?.foregroundColor?.resolve({}), cores.onError);
  });
}
```

- [ ] **Step 2: Rodar o teste para ver falhar**

Run: `flutter test test/core/widgets/app_botao_test.dart`
Expected: FAIL (imports ausentes).

- [ ] **Step 3: Implementar `AppBotao`**

`lib/core/widgets/app_botao.dart`:

```dart
import 'package:flutter/material.dart';

/// Ações padronizadas (doc 15 §3). Cobre os botões preenchidos, tonais,
/// contornados, de texto e destrutivos — o destrutivo sempre com foreground
/// explícito para garantir contraste sobre `colorScheme.error`.
enum AppBotaoVariante { filled, tonal, outlined, texto, destrutivo }

class AppBotao extends StatelessWidget {
  const AppBotao({
    super.key,
    required this.rotulo,
    this.onPressed,
    this.icone,
    this.variante = AppBotaoVariante.filled,
    this.carregando = false,
    this.expandido = true,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final AppBotaoVariante variante;
  final bool carregando;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final acao = carregando ? null : onPressed;
    final conteudo = _conteudo(context);

    final botao = switch (variante) {
      AppBotaoVariante.filled => FilledButton(
        onPressed: acao,
        child: conteudo,
      ),
      AppBotaoVariante.tonal => FilledButton.tonal(
        onPressed: acao,
        child: conteudo,
      ),
      AppBotaoVariante.outlined => OutlinedButton(
        onPressed: acao,
        child: conteudo,
      ),
      AppBotaoVariante.texto => TextButton(onPressed: acao, child: conteudo),
      AppBotaoVariante.destrutivo => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: cores.error,
          foregroundColor: cores.onError,
        ),
        onPressed: acao,
        child: conteudo,
      ),
    };

    return expandido
        ? SizedBox(width: double.infinity, child: botao)
        : botao;
  }

  Widget _conteudo(BuildContext context) {
    if (carregando) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(rotulo),
        ],
      );
    }
    if (icone == null) return Text(rotulo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone),
        const SizedBox(width: 8),
        Text(rotulo),
      ],
    );
  }
}
```

- [ ] **Step 4: Implementar `AppDialog`**

`lib/core/widgets/app_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'app_botao.dart';

/// Diálogos padronizados (doc 15 §3).
abstract final class AppDialog {
  /// Confirmação de ação destrutiva; retorna `true` apenas se confirmado.
  static Future<bool> confirmarDestrutivo(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String confirmar = AppStrings.excluir,
    String cancelar = AppStrings.cancelar,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelar),
          ),
          AppBotao(
            rotulo: confirmar,
            variante: AppBotaoVariante.destrutivo,
            expandido: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }
}
```

- [ ] **Step 5: Rodar o teste para ver passar**

Run: `flutter test test/core/widgets/app_botao_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: Commit**

```bash
dart format lib/core/widgets test/core/widgets
flutter analyze
git add lib/core/widgets/app_botao.dart lib/core/widgets/app_dialog.dart test/core/widgets/app_botao_test.dart
git commit -m "F8-T02: AppBotao e AppDialog padronizados (RNF-06)"
```

---

## Task 5: Componentes de superfície — `AppBanner`, `AppCard`, `AppChip`, `AppCabecalhoSecao` (F8-T02)

**Files:**
- Create: `lib/core/widgets/app_banner.dart`, `app_card.dart`, `app_chip.dart`, `app_cabecalho_secao.dart`
- Test: `test/core/widgets/app_banner_test.dart`, `test/core/widgets/app_card_test.dart`, `test/core/widgets/app_cabecalho_secao_test.dart`

**Interfaces:**
- Consumes: `AppSemanticColors` (Task 2), tokens.
- Produces: enum `AppBannerTipo { info, aviso, erro, offline, leitura }`; `AppBanner({required AppBannerTipo tipo, required String mensagem, Widget? acao})`; `AppCard({required Widget child, EdgeInsetsGeometry? padding, VoidCallback? onTap})`; `AppChip({required String rotulo, IconData? icone})`; `AppCabecalhoSecao(String titulo, {int? contagem})`.

- [ ] **Step 1: Escrever os testes que falham**

`test/core/widgets/app_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_banner.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.claro, home: Scaffold(body: child));

void main() {
  testWidgets('deve_exibir_mensagem_e_icone_quando_offline', (tester) async {
    await tester.pumpWidget(
      _app(const AppBanner(tipo: AppBannerTipo.offline, mensagem: 'Sem rede')),
    );
    expect(find.text('Sem rede'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('deve_usar_onContainer_quando_erro', (tester) async {
    await tester.pumpWidget(
      _app(const AppBanner(tipo: AppBannerTipo.erro, mensagem: 'Falhou')),
    );
    final texto = tester.widget<Text>(find.text('Falhou'));
    final contexto = tester.element(find.text('Falhou'));
    final cores = Theme.of(contexto).colorScheme;
    expect(texto.style?.color, cores.onErrorContainer);
  });
}
```

`test/core/widgets/app_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_card.dart';

void main() {
  testWidgets('deve_disparar_onTap_quando_tocado', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCard(child: const Text('Conteúdo'), onTap: () => tocado = true),
        ),
      ),
    );
    await tester.tap(find.text('Conteúdo'));
    expect(tocado, isTrue);
  });
}
```

`test/core/widgets/app_cabecalho_secao_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_cabecalho_secao.dart';

void main() {
  testWidgets('deve_exibir_contagem_quando_informada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: const Scaffold(body: AppCabecalhoSecao('Frios', contagem: 3)),
      ),
    );
    expect(find.text('Frios (3)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar os testes para ver falhar**

Run: `flutter test test/core/widgets`
Expected: FAIL (imports ausentes).

- [ ] **Step 3: Implementar os componentes**

`lib/core/widgets/app_banner.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';
import '../theme/tokens/app_radius.dart';
import '../theme/tokens/app_spacing.dart';

/// Banners transversais (doc 15 §3) com contraste correto (`on*Container`).
enum AppBannerTipo { info, aviso, erro, offline, leitura }

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.tipo,
    required this.mensagem,
    this.acao,
  });

  final AppBannerTipo tipo;
  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semanticas = Theme.of(context).extension<AppSemanticColors>()!;

    final (fundo, frente, icone) = switch (tipo) {
      AppBannerTipo.info => (
        semanticas.infoContainer,
        semanticas.onInfoContainer,
        Icons.info_outline,
      ),
      AppBannerTipo.aviso => (
        semanticas.warningContainer,
        semanticas.onWarningContainer,
        Icons.warning_amber_outlined,
      ),
      AppBannerTipo.erro => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      AppBannerTipo.offline => (
        semanticas.warningContainer,
        semanticas.onWarningContainer,
        Icons.cloud_off_outlined,
      ),
      AppBannerTipo.leitura => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.visibility_outlined,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: AppRadius.mdTodos,
      ),
      child: Row(
        children: [
          Icon(icone, color: frente, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(mensagem, style: TextStyle(color: frente)),
          ),
          if (acao != null) acao!,
        ],
      ),
    );
  }
}
```

`lib/core/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Superfície padrão (doc 15 §3).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
```

`lib/core/widgets/app_chip.dart`:

```dart
import 'package:flutter/material.dart';

/// Chip com alvo de toque ≥48dp (doc 15 §3).
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.rotulo, this.icone});

  final String rotulo;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: icone == null ? null : Icon(icone, size: 18),
          label: Text(rotulo),
        ),
      ),
    );
  }
}
```

`lib/core/widgets/app_cabecalho_secao.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Cabeçalho de seção com contagem opcional (doc 15 §3).
class AppCabecalhoSecao extends StatelessWidget {
  const AppCabecalhoSecao(this.titulo, {super.key, this.contagem});

  final String titulo;
  final int? contagem;

  @override
  Widget build(BuildContext context) {
    final texto = contagem == null ? titulo : '$titulo ($contagem)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes para ver passar**

Run: `flutter test test/core/widgets`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/widgets test/core/widgets
flutter analyze
git add lib/core/widgets/app_banner.dart lib/core/widgets/app_card.dart lib/core/widgets/app_chip.dart lib/core/widgets/app_cabecalho_secao.dart test/core/widgets
git commit -m "F8-T02: AppBanner, AppCard, AppChip e AppCabecalhoSecao (RNF-06)"
```

---

## Task 6: Componentes de estado e formulário — `AppEstadoVazio`, `AppEstadoErro`, `AppCampoTexto`, `AppSheet`, `AppSnackBar` (F8-T02)

**Files:**
- Create: `lib/core/widgets/app_estado_vazio.dart`, `app_estado_erro.dart`, `app_campo_texto.dart`, `app_sheet.dart`, `app_snack_bar.dart`
- Test: `test/core/widgets/app_estado_test.dart`, `test/core/widgets/app_campo_texto_test.dart`

**Interfaces:**
- Consumes: `AppBotao` (Task 4), tokens.
- Produces: `AppEstadoVazio({required String titulo, String? descricao, IconData icone = Icons.inbox_outlined, Widget? acao})`; `AppEstadoErro({required String mensagem, VoidCallback? onRetentar})`; `AppCampoTexto({TextEditingController? controller, String? label, String? erro, TextInputType? teclado, bool senha = false, ValueChanged<String>? onChanged, VoidCallback? onSubmitted})`; `AppSheet.mostrar<T>(BuildContext context, {required Widget child})`; `mostrarSnackBar(BuildContext context, String mensagem, {String? rotuloAcao, VoidCallback? onAcao})`.

- [ ] **Step 1: Escrever os testes que falham**

`test/core/widgets/app_estado_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/core/widgets/app_estado_vazio.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.claro, home: Scaffold(body: child));

void main() {
  testWidgets('deve_exibir_titulo_e_acao_quando_vazio', (tester) async {
    await tester.pumpWidget(
      _app(
        AppEstadoVazio(
          titulo: 'Nada aqui',
          acao: FilledButton(onPressed: () {}, child: const Text('Criar')),
        ),
      ),
    );
    expect(find.text('Nada aqui'), findsOneWidget);
    expect(find.text('Criar'), findsOneWidget);
  });

  testWidgets('deve_disparar_retry_quando_erro', (tester) async {
    var retentou = false;
    await tester.pumpWidget(
      _app(
        AppEstadoErro(
          mensagem: 'Falhou',
          onRetentar: () => retentou = true,
        ),
      ),
    );
    await tester.tap(find.text(AppStrings.tentarNovamente));
    expect(retentou, isTrue);
  });
}
```

`test/core/widgets/app_campo_texto_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_campo_texto.dart';

void main() {
  testWidgets('deve_exibir_erro_e_disparar_onChanged', (tester) async {
    String? digitado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(
            label: 'E-mail',
            erro: 'Inválido',
            onChanged: (v) => digitado = v,
          ),
        ),
      ),
    );
    expect(find.text('Inválido'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a@b.com');
    expect(digitado, 'a@b.com');
  });
}
```

- [ ] **Step 2: Rodar os testes para ver falhar**

Run: `flutter test test/core/widgets/app_estado_test.dart test/core/widgets/app_campo_texto_test.dart`
Expected: FAIL (imports ausentes).

- [ ] **Step 3: Implementar os componentes**

`lib/core/widgets/app_estado_vazio.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Estado vazio padronizado (doc 15 §3).
class AppEstadoVazio extends StatelessWidget {
  const AppEstadoVazio({
    super.key,
    required this.titulo,
    this.descricao,
    this.icone = Icons.inbox_outlined,
    this.acao,
  });

  final String titulo;
  final String? descricao;
  final IconData icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 72, color: scheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (descricao != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                descricao!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: AppSpacing.xl),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
```

`lib/core/widgets/app_estado_erro.dart`:

```dart
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens/app_spacing.dart';

/// Erro de carga com retry (doc 15 §3).
class AppEstadoErro extends StatelessWidget {
  const AppEstadoErro({super.key, required this.mensagem, this.onRetentar});

  final String mensagem;
  final VoidCallback? onRetentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(mensagem, textAlign: TextAlign.center),
            if (onRetentar != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onRetentar,
                child: const Text(AppStrings.tentarNovamente),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`lib/core/widgets/app_campo_texto.dart`:

```dart
import 'package:flutter/material.dart';

/// Campo de formulário padronizado com erro inline (doc 15 §3).
class AppCampoTexto extends StatelessWidget {
  const AppCampoTexto({
    super.key,
    this.controller,
    this.label,
    this.erro,
    this.teclado,
    this.senha = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? erro;
  final TextInputType? teclado;
  final bool senha;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: senha,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        labelText: label,
        errorText: erro,
      ),
    );
  }
}
```

`lib/core/widgets/app_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Bottom sheet padronizado (doc 15 §3).
abstract final class AppSheet {
  static Future<T?> mostrar<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.sm,
            bottom: AppSpacing.lg +
                MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

`lib/core/widgets/app_snack_bar.dart`:

```dart
import 'package:flutter/material.dart';

/// Snackbar padronizado, com ação opcional (ex.: desfazer) — doc 15 §3.
void mostrarSnackBar(
  BuildContext context,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        action: rotuloAcao == null
            ? null
            : SnackBarAction(label: rotuloAcao, onPressed: onAcao ?? () {}),
      ),
    );
}
```

- [ ] **Step 4: Rodar os testes para ver passar**

Run: `flutter test test/core/widgets`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/widgets test/core/widgets
flutter analyze
git add lib/core/widgets/app_estado_vazio.dart lib/core/widgets/app_estado_erro.dart lib/core/widgets/app_campo_texto.dart lib/core/widgets/app_sheet.dart lib/core/widgets/app_snack_bar.dart test/core/widgets
git commit -m "F8-T02: estados, campo, sheet e snackbar padronizados (RNF-06)"
```

---

## Task 7: Catálogo de revisão `/design` (F8-T02)

**Files:**
- Create: `lib/features/design_system/ui/design_system_screen.dart`
- Modify: `lib/router.dart`
- Test: `test/features/design_system/design_system_screen_test.dart`

**Interfaces:**
- Consumes: todos os componentes e `AppTheme`.
- Produces: `DesignSystemScreen` e a rota `/design` disponível apenas em `kDebugMode`.

- [ ] **Step 1: Escrever o teste que falha**

`test/features/design_system/design_system_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/features/design_system/ui/design_system_screen.dart';

void main() {
  testWidgets('deve_renderizar_secoes_de_tokens_e_componentes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const DesignSystemScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tokens'), findsOneWidget);
    expect(find.text('Botões'), findsOneWidget);
    expect(find.text('Banners'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar o teste para ver falhar**

Run: `flutter test test/features/design_system/design_system_screen_test.dart`
Expected: FAIL (arquivo não existe).

- [ ] **Step 3: Implementar a tela**

`lib/features/design_system/ui/design_system_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_estado_erro.dart';

/// Catálogo de revisão do design system (doc 15 §5, rota /design em debug).
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _Titulo('Tokens'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espaçamento', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final v in const [4.0, 8, 12, 16, 24, 32, 48])
                      Container(
                        width: v,
                        height: v,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Raios', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final r in const [
                      AppRadius.sm,
                      AppRadius.md,
                      AppRadius.lg,
                      AppRadius.xl,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(r),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const _Titulo('Botões'),
          AppCard(
            child: Column(
              children: [
                for (final v in AppBotaoVariante.values) ...[
                  AppBotao(rotulo: v.name, variante: v, onPressed: () {}),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const AppBotao(rotulo: 'Carregando', carregando: true),
              ],
            ),
          ),
          const _Titulo('Banners'),
          const AppCard(
            child: Column(
              children: [
                AppBanner(tipo: AppBannerTipo.info, mensagem: 'Informação'),
                SizedBox(height: AppSpacing.sm),
                AppBanner(tipo: AppBannerTipo.aviso, mensagem: 'Aviso'),
                SizedBox(height: AppSpacing.sm),
                AppBanner(tipo: AppBannerTipo.erro, mensagem: 'Erro'),
                SizedBox(height: AppSpacing.sm),
                AppBanner(tipo: AppBannerTipo.offline, mensagem: 'Offline'),
                SizedBox(height: AppSpacing.sm),
                AppBanner(tipo: AppBannerTipo.leitura, mensagem: 'Somente leitura'),
              ],
            ),
          ),
          const _Titulo('Chips e estados'),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppChip(rotulo: 'Dono', icone: Icons.person_outline),
                SizedBox(height: AppSpacing.lg),
                AppEstadoVazio(
                  titulo: 'Nenhuma lista',
                  descricao: 'Crie sua primeira lista.',
                  acao: AppBotao(rotulo: 'Criar', expandido: false),
                ),
                SizedBox(height: AppSpacing.lg),
                AppEstadoErro(mensagem: 'Falha ao carregar', onRetentar: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
```

- [ ] **Step 4: Registrar a rota em debug**

Em `lib/router.dart`, adicionar o import:

```dart
import 'features/design_system/ui/design_system_screen.dart';
```

E, dentro de `routes: [...]`, adicionar ao final:

```dart
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignSystemScreen(),
        ),
```

Adicionar `import 'package:flutter/foundation.dart';` no topo (para `kDebugMode`) e, no `redirect`, tratar `/design` como pública em debug:

```dart
      final publica =
          rota == '/login' ||
          rota == '/registro' ||
          rota == '/recuperar-senha' ||
          rota == '/entrar' ||
          (kDebugMode && rota == '/design');
```

- [ ] **Step 5: Rodar o teste para ver passar**

Run: `flutter test test/features/design_system/design_system_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/design_system lib/router.dart test/features/design_system
flutter analyze
git add lib/features/design_system lib/router.dart test/features/design_system
git commit -m "F8-T02: catalogo de revisao do design system em /design (RNF-06)"
```

---

## Task 8: Verificação final, docs e CI (F8-T03)

**Files:**
- Modify: `docs/15-design-system.md` (se algo divergir), `docs/14-tarefas.md` (marcar F8-T00..T03)
- Test: suíte completa

**Interfaces:**
- Consumes: tudo das Tasks 0–7.
- Produces: CI verde e fase 8 fechada.

- [ ] **Step 1: Rodar a suíte completa e o formato**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Expected: tudo verde. Se `dart format` alterar algo, rode `dart format .` e commit.

- [ ] **Step 2: Marcar as tarefas concluídas em `docs/14-tarefas.md`**

Trocar `- [ ]` por `- [x]` em F8-T00, F8-T01, F8-T02 e F8-T03, e atualizar a tabela "Progresso por fase" para `| F8 Design System | 4 | 4 |` e o total para `| **Total** | **57** | **55** |`.

- [ ] **Step 3: Sincronizar o doc 15 com o implementado**

Conferir que `docs/15-design-system.md` lista exatamente os componentes criados (`AppBotao`, `AppDialog.confirmarDestrutivo`, `AppBanner`, `AppCard`, `AppChip`, `AppCabecalhoSecao`, `AppEstadoVazio`, `AppEstadoErro`, `AppCampoTexto`, `AppSheet.mostrar`, `mostrarSnackBar`). Ajustar se houver divergência.

- [ ] **Step 4: Commit final**

```bash
git add docs/14-tarefas.md docs/15-design-system.md
git commit -m "F8-T03: fecha a fundacao do design system (CI verde, RNF-06)"
```

---

## Notas de execução

- **Goldens:** `flutter test --update-goldens` pode ser usado localmente para o catálogo, mas **não** entra no CI nesta fase (variação de antialias/fonte por runner). Documentado no doc 15.
- **Rota `/design`:** só existe em `kDebugMode`; não altera o comportamento de produção.
- **Fontes:** os `.ttf` são binários versionados em `assets/fonts/`; `OFL.txt` acompanha a licença.
- **Rollback:** cada task é um commit independente; reverter a fundação não afeta as telas (nada migra para os componentes novos ainda — isso é a Etapa 2).
```
