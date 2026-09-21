# 15 — Design System

> Navegação: [← 14 Tarefas](14-tarefas.md) · [← Índice](../planejamento_lista_compras.md) · [16 Roadmap →](16-roadmap-pos-mvp.md)
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
| `app_typography.dart` | `TextTheme` com `PlusJakartaSans`; título de tela (`tituloTelaTamanho=24`, `tituloTelaPeso=bold`) |

Título de tela (AppBar): **24sp bold** aplicado via `appBarTheme.titleTextStyle` (F13-T03). Precisa ser explícito — o `appBarTheme` não passa pela localização de tipografia do `Theme`, então um estilo só de cor deixaria o título sem tamanho (cairia no default).

## 2. Tema

- `AppTheme.claro` / `AppTheme.escuro` (`lib/core/theme/app_theme.dart`).
- `ColorScheme.fromSeed` + component themes (appBar, card, input, botões, chip, sheet, dialog, snackbar, navigationBar, etc.).
- Cores semânticas via `ThemeExtension<AppSemanticColors>` (`lib/core/theme/app_semantic_colors.dart`), lidas com `Theme.of(context).extension<AppSemanticColors>()!`.
- `TextTheme` derivado do `ColorScheme`/brilho (`app_typography.dart`, F12-T01): o claro usa cores escuras (`onSurface`) e o escuro, claras — um `TextTheme` fixo em `.black` sobrepõe o default do `ThemeData` e deixa texto preto no fundo escuro (viola §4).
- Modo: Claro / Escuro / Sistema (padrão Sistema), persistido em SharedPreferences (`theme_mode_provider.dart`), seletor em Configurações (`seletor_tema.dart`). **Adaptativo (F21-T01):** em telas com ≥ 360dp e fonte normal usa `SegmentedButton` (ícone + rótulo); abaixo disso ou com `textScaler ≥ 1.3` vira dropdown, que nunca estoura (R-20).

## 3. Componentes (`lib/core/widgets/`)

| Componente | Uso |
| :--- | :--- |
| `AppBotao` | Ações (filled/tonal/outlined/texto/destrutivo), com `carregando` (progresso anunciado na semântica) |
| `AppDialog.confirmarDestrutivo` | Confirmação de ação destrutiva |
| `AppBanner` | info/aviso/erro/offline/leitura com contraste correto; `liveRegion` (Fase 14) |
| `AppCard` | Superfície padrão com padding/radius (sem margem; o espaçamento entre cards empilhados é do layout — ex.: `AppSpacing.sm`) |
| `AppLogo` | Marca do app (carrinho de compras) no cabeçalho das telas de topo; 28dp, recortada com `AppRadius.sm` |
| `AppChip` | Chip com alvo ≥48dp |
| `AppEsqueleto` | Placeholder estático de carregamento (blocos da cor de superfície, sem animação, sem pacote novo) — painel, itens da lista e membros (F14-T09) |
| `AppCabecalhoSecao` | Cabeçalho de seção (`título (n)`) |
| `AppEstadoVazio` | Vazio com ícone + texto + CTA; rótulo único (título + descrição) para o leitor de tela, com a ação em nó próprio (Fase 14) |
| `AppEstadoErro` | Erro de carga com retry rotulado |
| `AppCampoTexto` | Campo de formulário com erro inline; aceita `hint`, `maxLength`, `minLines`/`maxLines`, `textInputAction` e `readOnly` (Fase 14) |
| `AppDropdown<T>` | Dropdown de formulário padronizado (`label`/`valor`/`itens`/`onChanged`/`compacto`), mesma decoração dos campos (Fase 14) |
| `AppSheet.mostrar` | Bottom sheet padrão |
| `mostrarSnackBar` | Snackbar (inclusive undo) com **duração curta**: 2s sem ação e 3s com ação (`duracao` sobrescreve — F12-T07); já anunciado por ser uma live region do próprio `SnackBar` |

**Uso de componentes existentes na F22:** os chips de itens frequentes usam o **`ActionChip`** do Material (faixa horizontal rolável, alvo ≥48dp, `Semantics` de ação "Adicionar <nome>" — RF-19); a faixa "Marcados" do modo mercado usa `Material` + `ListTile` com `Semantics(button/expanded)`, sem componente novo (RF-18). Nenhum `App*` novo foi necessário.

## 4. Acessibilidade (RNF-06)

Regras vinculantes (detalhe e evidência na [spec da Fase 14](superpowers/specs/2026-09-14-ux-acessibilidade-design.md)):

- **Contraste ≥ AA** nos pares `container`/`on*`.
- **Alvos de toque ≥ 48dp**.
- **Semântica:** `tooltip` em todo `IconButton`/`PopupMenuButton`; ícones decorativos (logo, ícones de estado de 48–72dp) fora da árvore com `excludeSemantics`; controles com rótulo do contexto (ex.: `Checkbox` do item usa o nome do item).
- **Live regions:** `AppBanner` (erro/offline/aviso), `mostrarSnackBar` e `IndicadorSync` são anunciados (`Semantics(liveRegion: true)`).
- **Escala de texto:** as telas-chave não estouram com `textScaler` 1.3 e 2.0 (verificado com `textScaleFactor` 2.0 nos testes de tela).
- **Verificação automatizada:** testes com `meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline` e `textContrastGuideline` (`test/core/widgets/acessibilidade_test.dart`) + os testes de semântica/estado nas telas — a acessibilidade é verificada por teste, não por inspeção.

## 5. Catálogo

Rota de debug `/design` (`kDebugMode`) renderiza tokens e componentes em claro/escuro — base para revisão visual. Golden tests podem ser gerados localmente com `flutter test --update-goldens`, mas não rodam no CI (variação de antialias/fonte por runner).

## 6. Identidade visual

- **Marca:** carrinho de compras, branco sobre o verde da marca `#2E7D32`. O glifo vem do Material Symbols `shopping_cart` (Apache-2.0), na mesma linguagem dos ícones do app.
- **Masters vetoriais** (fonte de verdade, editáveis): `assets/branding/logo.svg` (ícone cheio, fundo verde) e `assets/branding/logo_glyph.svg` (glifo com fundo transparente, já dentro da área segura do ícone adaptativo).
- **Bitmaps gerados** (commitados, 1024px): `assets/branding/logo.png` (ícones/splash/cabeçalho) e `logo_glyph.png` (ícone adaptativo e splash).
- **Usos:** ícone do app (Android/iOS/web), splash e cabeçalho das telas de topo (`AppLogo`, 28dp). O ícone cheio vai full-bleed — as plataformas aplicam a máscara (squircle/círculo).
- **Área de respiro / tamanho mínimo:** não encostar o glifo nas bordas (o `logo_glyph` já traz ~19% de margem); não exibir o glifo abaixo de **24dp**.
- **Splash:** fundo verde `#2E7D32` (escuro `#1B5E20`) com o glifo centrado.
- **Regenerar** (após editar o SVG, re-renderizar o PNG de 1024 a partir dele — qualquer rasterizador serve; no dev usamos Chromium headless — e então):
  ```bash
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```
  Configuração de ambos em `pubspec.yaml` (`flutter_launcher_icons`, `flutter_native_splash`).

## Documentos relacionados

- [05 App Flutter](05-app-flutter.md) — comportamento e UX das telas
- [10 Wireframes](10-wireframes-telas.md) — layout das telas
- [12 PRD](12-prd.md) — RNF-06 (acessibilidade)
- [14 Tarefas](14-tarefas.md) — execução e progresso
