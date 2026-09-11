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
| `mostrarSnackBar` | Snackbar (inclusive undo) |

## 4. Acessibilidade (RNF-06)

- Contraste ≥ AA nos pares `container`/`on*`.
- Alvos de toque ≥ 48dp.
- `tooltip`/`Semantics` em ícones.
- Respeito à escala de texto do sistema.

## 5. Catálogo

Rota de debug `/design` (`kDebugMode`) renderiza tokens e componentes em claro/escuro — base para revisão visual. Golden tests podem ser gerados localmente com `flutter test --update-goldens`, mas não rodam no CI (variação de antialias/fonte por runner).

## Documentos relacionados

- [05 App Flutter](05-app-flutter.md) — comportamento e UX das telas
- [10 Wireframes](10-wireframes-telas.md) — layout das telas
- [12 PRD](12-prd.md) — RNF-06 (acessibilidade)
- [14 Tarefas](14-tarefas.md) — execução e progresso
