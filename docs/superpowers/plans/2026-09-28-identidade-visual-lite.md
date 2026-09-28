# Identidade visual do Lite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao flavor `lite` uma identidade visual própria (índigo `#4F46E5` + símbolo de cesta + nome "Minhas Listas") no ícone, splash, cabeçalho e tema, sem alterar o app colaborativo (`prod`).

**Architecture:** Uma `IdentidadeVisual` (seed, nome, asset de logo) **derivada de `AppCapacidades`** escolhe a marca; `AppTheme` passa a receber o seed e o `AppLogo` lê o asset da identidade. Nenhum widget decide por `AppModo`. O casco nativo Android do Lite usa o source set `android/app/src/lite/res/`, que sobrescreve recursos de mesmo nome do `main`.

**Tech Stack:** Flutter 3.44.x / Dart 3.12, Riverpod, Material 3 (`ColorScheme.fromSeed`), Gradle (flavors), Playwright (rasterização dos PNGs), `flutter_launcher_icons`/`flutter_native_splash`.

**Spec:** `docs/superpowers/specs/2026-09-28-identidade-visual-lite-design.md`

## Global Constraints

- Seed do Lite: **`#4F46E5`** (índigo); splash escuro: **`#3730A3`**.
- Nome do Lite: **"Minhas Listas"** (launcher + `MaterialApp.title`).
- Símbolo: **cesta** (Material Symbols `shopping_basket`, Apache-2.0).
- `prod` **inalterado**: seed `#2E7D32`, carrinho, "Lista de Compras".
- Sem mudança de DB/RLS/migrations/sync.
- Todo doc dono tocado é atualizado **no mesmo PR** ([15], [05], [09], [12], [14]).
- Barra de qualidade: `dart format .` + `flutter analyze` limpos e `flutter test` verde a cada task.
- Versão final: `1.5.0+14` (e `web/version.json` com `build_number` `14`).
- Nomes de teste: `deve_<resultado>_quando_<condição>`; pt-BR em docs/UI; sem segredos.
- **Ajuste em relação à spec §4:** para não quebrar ~20 call sites de teste, `AppTheme.claro`/`AppTheme.escuro` **continuam getters** (default = identidade colaborativa) e são adicionados `AppTheme.claroDe(identidade)`/`AppTheme.escuroDe(identidade)`.

## File Structure

- `lib/core/theme/tokens/app_colors.dart` — +`seedLite`.
- `lib/core/theme/identidade_visual.dart` — **novo**: `IdentidadeVisual` + `identidadeVisualProvider`.
- `lib/core/theme/app_theme.dart` — seed parametrizado + `claroDe`/`escuroDe`.
- `lib/core/l10n/app_strings.dart` — +`appNomeLite`, +`boasVindasTituloLite`.
- `lib/app.dart` — tema e título pela identidade.
- `lib/features/onboarding/ui/boas_vindas_screen.dart` — título por capacidade.
- `lib/core/widgets/app_logo.dart` — asset pela identidade (`ConsumerWidget`).
- `assets/branding/logo_lite.svg|.png`, `logo_glyph_lite.svg|.png` — **novos**.
- `android/app/build.gradle.kts` — `app_name` do Lite.
- `android/app/src/lite/res/**` — ícone/splash do Lite.
- `pubspec.yaml`, `web/version.json`, docs 15/05/09/12/14.

---

### Task 1 (F44-T01): Núcleo da marca no app (token, identidade, tema, nome)

**Files:**
- Modify: `lib/core/theme/tokens/app_colors.dart`
- Create: `lib/core/theme/identidade_visual.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/app.dart`
- Modify: `lib/features/onboarding/ui/boas_vindas_screen.dart`
- Test: `test/core/theme/identidade_visual_test.dart` (create), `test/core/theme/app_theme_identidade_test.dart` (create), `test/features/onboarding/boas_vindas_screen_test.dart` (modify)
- Docs: `docs/15-design-system.md` (§1 §2)

**Interfaces:**
- Produces: `AppColors.seedLite` (`Color`); `IdentidadeVisual` (`seed`/`nomeApp`/`logoAsset`) com consts `colaborativo`/`lite`; `identidadeVisualProvider` (`Provider<IdentidadeVisual>`); `AppTheme.claroDe(IdentidadeVisual)`/`AppTheme.escuroDe(IdentidadeVisual)`; `AppStrings.appNomeLite`; `AppStrings.boasVindasTituloLite`.
- Consumes: `AppCapacidades`/`capacidadesProvider` (`lib/core/config/app_modo.dart`).

- [ ] **Step 1: Escrever o teste que falha (identidade)**

Create `test/core/theme/identidade_visual_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';
import 'package:lista_compras/core/theme/tokens/app_colors.dart';

void main() {
  test('deve_usar_indigo_e_minhas_listas_quando_modo_lite', () {
    final container = ProviderContainer(
      overrides: [capacidadesProvider.overrideWithValue(AppCapacidades.lite)],
    );
    addTearDown(container.dispose);

    final identidade = container.read(identidadeVisualProvider);
    expect(identidade.seed, AppColors.seedLite);
    expect(identidade.nomeApp, 'Minhas Listas');
    expect(identidade.logoAsset, 'assets/branding/logo_lite.png');
  });

  test('deve_usar_verde_e_lista_de_compras_quando_colaborativo', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final identidade = container.read(identidadeVisualProvider);
    expect(identidade.seed, AppColors.seed);
    expect(identidade.nomeApp, 'Lista de Compras');
    expect(identidade.logoAsset, 'assets/branding/logo.png');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/theme/identidade_visual_test.dart`
Expected: FAIL — `identidade_visual.dart`/`seedLite` não existem.

- [ ] **Step 3: Token do seed do Lite**

Em `lib/core/theme/tokens/app_colors.dart`, logo após `static const seed = Color(0xFF2E7D32);`, adicione:

```dart
  /// Seed da identidade visual do flavo Lite (doc 15 §1/§6).
  static const seedLite = Color(0xFF4F46E5);
```

- [ ] **Step 4: Criar `IdentidadeVisual`**

Create `lib/core/theme/identidade_visual.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_modo.dart';
import '../l10n/app_strings.dart';
import 'tokens/app_colors.dart';

/// Identidade visual (marca) do app. Derivada de [AppCapacidades] — a UI nunca
/// decide por [AppModo] diretamente (doc 15 §6).
class IdentidadeVisual {
  const IdentidadeVisual({
    required this.seed,
    required this.nomeApp,
    required this.logoAsset,
  });

  final Color seed;
  final String nomeApp;
  final String logoAsset;

  static const colaborativo = IdentidadeVisual(
    seed: AppColors.seed,
    nomeApp: AppStrings.appNome,
    logoAsset: 'assets/branding/logo.png',
  );

  static const lite = IdentidadeVisual(
    seed: AppColors.seedLite,
    nomeApp: AppStrings.appNomeLite,
    logoAsset: 'assets/branding/logo_lite.png',
  );
}

final identidadeVisualProvider = Provider<IdentidadeVisual>(
  (ref) => ref.watch(capacidadesProvider).nuvem
      ? IdentidadeVisual.colaborativo
      : IdentidadeVisual.lite,
);
```

- [ ] **Step 5: Strings novas**

Em `lib/core/l10n/app_strings.dart`, depois de `static const appNome = 'Lista de Compras';`:

```dart
  static const appNomeLite = 'Minhas Listas';
```

E no bloco "Boas-vindas", depois de `boasVindasTitulo`:

```dart
  static const boasVindasTituloLite = 'Bem-vindo(a)';
```

- [ ] **Step 6: Rodar o teste de identidade e ver passar**

Run: `flutter test test/core/theme/identidade_visual_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 7: Teste que falha do tema do Lite**

Create `test/core/theme/app_theme_identidade_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';

void main() {
  test('deve_gerar_paleta_distinta_quando_identidade_lite', () {
    final lite = AppTheme.claroDe(IdentidadeVisual.lite);
    final prod = AppTheme.claroDe(IdentidadeVisual.colaborativo);
    expect(lite.colorScheme.primary, isNot(equals(prod.colorScheme.primary)));
  });

  test('deve_manter_prod_verde_quando_getter_padrao', () {
    expect(
      AppTheme.claro.colorScheme.primary,
      AppTheme.claroDe(IdentidadeVisual.colaborativo).colorScheme.primary,
    );
  });

  testWidgets('deve_manter_contraste_quando_tema_lite', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claroDe(IdentidadeVisual.lite),
        home: const Scaffold(body: Center(child: Text('Minhas listas'))),
      ),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
```

- [ ] **Step 8: Rodar e ver falhar**

Run: `flutter test test/core/theme/app_theme_identidade_test.dart`
Expected: FAIL — `claroDe` não existe.

- [ ] **Step 9: Parametrizar o tema**

Em `lib/core/theme/app_theme.dart`: adicione o import `import 'identidade_visual.dart';` e substitua os getters/`_base` por:

```dart
  static ThemeData get claro => claroDe(IdentidadeVisual.colaborativo);

  static ThemeData get escuro => escuroDe(IdentidadeVisual.colaborativo);

  static ThemeData claroDe(IdentidadeVisual identidade) =>
      _base(Brightness.light, AppSemanticColors.claro, identidade.seed);

  static ThemeData escuroDe(IdentidadeVisual identidade) =>
      _base(Brightness.dark, AppSemanticColors.escuro, identidade.seed);

  static ThemeData _base(
    Brightness brightness,
    AppSemanticColors semanticas,
    Color seed,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
```

(…o restante de `_base` fica igual; a antiga linha `seedColor: AppColors.seed` sai e `AppColors` deixa de ser usado — remova o import se o linter apontar.)

- [ ] **Step 10: Rodar o teste de tema e ver passar**

Run: `flutter test test/core/theme/app_theme_identidade_test.dart test/core/theme/app_theme_test.dart`
Expected: PASS (todos).

- [ ] **Step 11: Ligar a identidade no app**

Em `lib/app.dart`: remova `import 'core/l10n/app_strings.dart';` (deixa de ser usado), adicione `import 'core/theme/identidade_visual.dart';` e, no `build`, leia a identidade:

```dart
    final router = ref.watch(routerProvider);
    final identidade = ref.watch(identidadeVisualProvider);
    final modoTema = ref.watch(temaModoProvider).value ?? ThemeMode.system;
```

E no `MaterialApp.router`:

```dart
      title: identidade.nomeApp,
      ...
      theme: AppTheme.claroDe(identidade),
      darkTheme: AppTheme.escuroDe(identidade),
```

- [ ] **Step 12: Título das boas-vindas por capacidade**

Em `lib/features/onboarding/ui/boas_vindas_screen.dart`, troque a linha do título:

```dart
                  Text(
                    colaborativo
                        ? AppStrings.boasVindasTitulo
                        : AppStrings.boasVindasTituloLite,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
```

- [ ] **Step 13: Teste que falha do título Lite**

Em `test/features/onboarding/boas_vindas_screen_test.dart`, no teste `deve_omitir_compartilhar_e_mostrar_backup_quando_modo_lite`, acrescente antes do fim:

```dart
    expect(find.text(AppStrings.boasVindasTituloLite), findsOneWidget);
    expect(find.text(AppStrings.boasVindasTitulo), findsNothing);
```

- [ ] **Step 14: Rodar a suíte dos tocados**

Run: `flutter test test/features/onboarding/boas_vindas_screen_test.dart test/core/theme`
Expected: PASS.

- [ ] **Step 15: Doc dono 15 (§1 e §2)**

Em `docs/15-design-system.md`: na tabela de tokens (§1) acrescente `seedLite=#4F46E5` a `app_colors.dart`; em §2 troque a menção a `AppTheme.claro / AppTheme.escuro` por `AppTheme.claroDe/escuroDe(IdentidadeVisual)` (getters `claro`/`escuro` mantêm a identidade colaborativa como default) e registre que o Lite usa seed índigo (doc dono da identidade). Relacione a [spec da F44](superpowers/specs/2026-09-28-identidade-visual-lite-design.md).

- [ ] **Step 16: Formatar, analisar e commitar**

Run: `dart format . ; flutter analyze`
Expected: sem alterações pendentes / "No issues found!".

```bash
git add lib/core/theme/tokens/app_colors.dart lib/core/theme/identidade_visual.dart lib/core/theme/app_theme.dart lib/core/l10n/app_strings.dart lib/app.dart lib/features/onboarding/ui/boas_vindas_screen.dart test/core/theme/identidade_visual_test.dart test/core/theme/app_theme_identidade_test.dart test/features/onboarding/boas_vindas_screen_test.dart docs/15-design-system.md
git commit -m "F44-T01: identidade por capacidades e tema do Lite (RF-31)"
```

---

### Task 2 (F44-T02): Assets da marca Lite + `AppLogo` por identidade

**Files:**
- Create: `assets/branding/logo_lite.svg`, `assets/branding/logo_glyph_lite.svg`, `assets/branding/logo_lite.png`, `assets/branding/logo_glyph_lite.png`
- Modify: `lib/core/widgets/app_logo.dart`
- Test: `test/core/widgets/app_logo_test.dart` (create), `test/features/design_system/design_system_screen_test.dart` (modify)
- Docs: `docs/15-design-system.md` (§6)

**Interfaces:**
- Consumes: `identidadeVisualProvider`, `IdentidadeVisual.lite.logoAsset` (= `assets/branding/logo_lite.png`) da Task 1.
- Produces: os PNGs `logo_lite.png`/`logo_glyph_lite.png` (usados pela Task 3).

- [ ] **Step 1: Master vetorial cheio do Lite**

Create `assets/branding/logo_lite.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Marca "Minhas Listas" (flavor Lite, doc 15 §6): cesta de compras.
       Master vetorial — gera assets/branding/logo_lite.png (1024, opaco).
       Glifo baseado no Material Symbols "shopping_basket" (Apache-2.0). -->
  <rect width="1024" height="1024" fill="#4F46E5"/>
  <path transform="translate(128 128) scale(32)"
        d="M17.21 9l-4.38-6.56c-.19-.28-.51-.42-.83-.42-.32 0-.64.14-.83.43L6.79 9H2c-.55 0-1 .45-1 1 0 .09.01.18.04.27l2.54 9.27c.23.84 1 1.46 1.92 1.46h13c.92 0 1.69-.62 1.93-1.46l2.54-9.27L23 10c0-.55-.45-1-1-1h-4.79zM9 9l3-4.4L15 9H9zm3 8c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"
        fill="#FFFFFF"/>
</svg>
```

- [ ] **Step 2: Glifo transparente do Lite (área segura)**

Create `assets/branding/logo_glyph_lite.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <!-- Glifo da marca do Lite (fundo transparente) para ícone adaptativo Android e splash.
       Escala reduzida (~0,84) para manter a cesta dentro da área segura (61% do canvas).
       Glifo baseado no Material Symbols "shopping_basket" (Apache-2.0). -->
  <path transform="translate(188 188) scale(27)"
        d="M17.21 9l-4.38-6.56c-.19-.28-.51-.42-.83-.42-.32 0-.64.14-.83.43L6.79 9H2c-.55 0-1 .45-1 1 0 .09.01.18.04.27l2.54 9.27c.23.84 1 1.46 1.92 1.46h13c.92 0 1.69-.62 1.93-1.46l2.54-9.27L23 10c0-.55-.45-1-1-1h-4.79zM9 9l3-4.4L15 9H9zm3 8c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"
        fill="#FFFFFF"/>
</svg>
```

- [ ] **Step 3: Rasterizar os PNGs (Playwright)**

Run `playwright_browser_run_code_unsafe` com o código abaixo (gera os dois PNGs de 1024):

```js
async (page) => {
  const fs = require('fs');
  const base = 'C:/Repositorios/ListaCompras/assets/branding/';
  const render = async (svg, png) => {
    const conteudo = fs.readFileSync(base + svg, 'utf8');
    await page.setViewportSize({ width: 1024, height: 1024 });
    await page.setContent('<html><body style="margin:0;padding:0">' + conteudo + '</body></html>');
    await page.screenshot({ path: base + png, omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  };
  await render('logo_lite.svg', 'logo_lite.png');
  await render('logo_glyph_lite.svg', 'logo_glyph_lite.png');
  return 'ok';
}
```

Fallback (se o Playwright não estiver disponível): Chromium headless —
`& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless --disable-gpu --screenshot="assets/branding/logo_lite.png" --window-size=1024,1024 "file:///C:/Repositorios/ListaCompras/assets/branding/logo_lite.svg"`.

- [ ] **Step 4: Verificar os PNGs**

Run: `Get-Item assets/branding/logo_lite.png, assets/branding/logo_glyph_lite.png | Select-Object Name, Length`
Expected: ambos existem e têm tamanho > 5.000 bytes (não em branco).

- [ ] **Step 5: Teste que falha do `AppLogo`**

Create `test/core/widgets/app_logo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';

Widget _app(AppCapacidades capacidades) => ProviderScope(
      overrides: [capacidadesProvider.overrideWithValue(capacidades)],
      child: MaterialApp(
        theme: AppTheme.claroDe(
          capacidades.nuvem
              ? IdentidadeVisual.colaborativo
              : IdentidadeVisual.lite,
        ),
        home: const Scaffold(body: Center(child: AppLogo())),
      ),
    );

void main() {
  testWidgets('deve_usar_asset_do_lite_quando_identidade_lite', (tester) async {
    await tester.pumpWidget(_app(AppCapacidades.lite));
    await tester.pumpAndSettle();

    final imagem = tester.widget<Image>(find.byType(Image));
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/branding/logo_lite.png',
    );
  });

  testWidgets('deve_usar_asset_atual_quando_colaborativo', (tester) async {
    await tester.pumpWidget(_app(AppCapacidades.colaborativo));
    await tester.pumpAndSettle();

    final imagem = tester.widget<Image>(find.byType(Image));
    expect((imagem.image as AssetImage).assetName, 'assets/branding/logo.png');
  });
}
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `flutter test test/core/widgets/app_logo_test.dart`
Expected: FAIL — `AppLogo` ainda usa o asset fixo (`logo.png`) em ambos.

- [ ] **Step 7: `AppLogo` pela identidade**

Substitua `lib/core/widgets/app_logo.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/identidade_visual.dart';
import '../theme/tokens/app_radius.dart';

/// Marca do app (doc 15 §6): a imagem vem da identidade visual vigente
/// (colaborativa = carrinho verde; Lite = cesta índigo). É **decorativa**
/// (doc 15 §4): o título ao lado já anuncia a tela (`ExcludeSemantics`).
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.tamanho = 28});

  final double tamanho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(identidadeVisualProvider).logoAsset;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.smTodos,
        child: Image.asset(
          asset,
          width: tamanho,
          height: tamanho,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Rodar o teste do logo e ver passar**

Run: `flutter test test/core/widgets/app_logo_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 9: Ajustar o teste do design system (`AppLogo` agora é `ConsumerWidget`)**

Em `test/features/design_system/design_system_screen_test.dart`, envolva o `MaterialApp` num `ProviderScope` (e adicione o import `package:flutter_riverpod/flutter_riverpod.dart`):

```dart
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.claro,
          home: const DesignSystemScreen(),
        ),
      ),
    );
```

Run: `flutter test test/features/design_system/design_system_screen_test.dart`
Expected: PASS.

- [ ] **Step 10: Doc dono 15 (§6 — duas marcas)**

Em `docs/15-design-system.md` §6: registre que a marca do flavor **Lite** é a **cesta** (`shopping_basket`) branca sobre **índigo `#4F46E5`**, com masters `assets/branding/logo_lite.svg`/`logo_glyph_lite.svg` e bitmaps gerados `logo_lite.png`/`logo_glyph_lite.png`; que o `prod` continua carrinho/verde; e que a escolha é feita por `IdentidadeVisual` (não por `AppModo`).

- [ ] **Step 11: Formatar, analisar e commitar**

Run: `dart format . ; flutter analyze`
Expected: "No issues found!".

```bash
git add assets/branding/logo_lite.svg assets/branding/logo_lite.png assets/branding/logo_glyph_lite.svg assets/branding/logo_glyph_lite.png lib/core/widgets/app_logo.dart test/core/widgets/app_logo_test.dart test/features/design_system/design_system_screen_test.dart docs/15-design-system.md
git commit -m "F44-T02: assets da marca do Lite (cesta indigo) e AppLogo por identidade (RF-31)"
```

---

### Task 3 (F44-T03): Casco nativo Android do Lite (nome, ícone, splash)

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/lite/res/values/colors.xml`
- Create: `android/app/src/lite/res/mipmap-*/ic_launcher.png`, `android/app/src/lite/res/drawable-*/ic_launcher_foreground.png`, `android/app/src/lite/res/drawable-*/{background,splash,android12splash}.png` (+ `-night-*`), `android/app/src/lite/res/values-v31/styles.xml`, `android/app/src/lite/res/values-night-v31/styles.xml`
- Docs: `docs/09-runbook-operacoes.md` (§2.9)

**Interfaces:**
- Consumes: `assets/branding/logo_lite.png` e `logo_glyph_lite.png` (Task 2).
- Produces: recursos do flavor `lite` no source set `android/app/src/lite/res/`.

- [ ] **Step 1: Nome do app Lite**

Em `android/app/build.gradle.kts`, no flavor `lite` (linha ~49), troque o valor:

```kotlin
            resValue("string", "app_name", "Minhas Listas")
```

- [ ] **Step 2: Cor do fundo do ícone adaptativo**

Substitua `android/app/src/lite/res/values/colors.xml` por:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#4F46E5</color>
</resources>
```

- [ ] **Step 3: Gerar ícones do Lite (config separada, sem tocar o `pubspec`)**

Create `flutter_launcher_icons.yaml` na raiz:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: assets/branding/logo_lite.png
  adaptive_icon_background: "#4F46E5"
  adaptive_icon_foreground: assets/branding/logo_glyph_lite.png
```

Run: `dart run flutter_launcher_icons`
Expected: mensagem de sucesso; `android/app/src/main/res/values/colors.xml` passa a ter `ic_launcher_background` `#4F46E5` (confirma que a config do Lite foi aplicada).

- [ ] **Step 4: Copiar os PNGs do ícone para o source set `lite`**

Run (PowerShell, a partir da raiz do repo):

```powershell
$src = "android/app/src/main/res"
$dst = "android/app/src/lite/res"
foreach ($d in "mdpi","hdpi","xhdpi","xxhdpi","xxxhdpi") {
  New-Item -ItemType Directory -Force -Path "$dst/mipmap-$d","$dst/drawable-$d" | Out-Null
  Copy-Item "$src/mipmap-$d/ic_launcher*.png" "$dst/mipmap-$d/" -Force
  Copy-Item "$src/drawable-$d/ic_launcher_foreground.png" "$dst/drawable-$d/" -Force
}
```

- [ ] **Step 5: Restaurar o `main` (ícones do Lite não vazam para o `prod`)**

Run: `git checkout -- android/app/src/main/res`
Expected: `git status --short android` mostra apenas `M build.gradle.kts` e arquivos novos em `src/lite/res` (nada modificado em `src/main/res`).

- [ ] **Step 6: Gerar o splash do Lite**

Edite temporariamente o bloco `flutter_native_splash` do `pubspec.yaml` para os valores do Lite:

```yaml
flutter_native_splash:
  color: "#4F46E5"
  image: assets/branding/logo_glyph_lite.png
  color_dark: "#3730A3"
  image_dark: assets/branding/logo_glyph_lite.png
  android: true
  ios: false
  web: false
  android_12:
    color: "#4F46E5"
    image: assets/branding/logo_glyph_lite.png
    color_dark: "#3730A3"
    image_dark: assets/branding/logo_glyph_lite.png
```

Run: `dart run flutter_native_splash:create`
Expected: sucesso; `android/app/src/main/res/values-v31/styles.xml` passa a ter `windowSplashScreenBackground` `#4F46E5`.

- [ ] **Step 7: Copiar os recursos de splash para o `lite`**

Run (PowerShell):

```powershell
$src = "android/app/src/main/res"
$dst = "android/app/src/lite/res"
foreach ($d in "mdpi","hdpi","xhdpi","xxhdpi","xxxhdpi") {
  foreach ($n in "background.png","splash.png","android12splash.png") {
    Copy-Item "$src/drawable-$d/$n" "$dst/drawable-$d/$n" -Force
    New-Item -ItemType Directory -Force -Path "$dst/drawable-night-$d" | Out-Null
    Copy-Item "$src/drawable-night-$d/$n" "$dst/drawable-night-$d/$n" -Force
  }
}
New-Item -ItemType Directory -Force -Path "$dst/values-v31","$dst/values-night-v31" | Out-Null
Copy-Item "$src/values-v31/styles.xml" "$dst/values-v31/styles.xml" -Force
Copy-Item "$src/values-night-v31/styles.xml" "$dst/values-night-v31/styles.xml" -Force
```

- [ ] **Step 8: Restaurar `main` e o `pubspec` do `prod`**

Run: `git checkout -- pubspec.yaml android/app/src/main/res`
Expected: `pubspec.yaml` volta a `#2E7D32`/`logo_glyph.png`; `git status --short` lista apenas mudanças em `build.gradle.kts`, `flutter_launcher_icons.yaml` (remover) e `android/app/src/lite/res/**`.

- [ ] **Step 9: Remover a config temporária e conferir o merge do `prod`**

```powershell
Remove-Item flutter_launcher_icons.yaml
git status --short android pubspec.yaml
```

Expected: `src/lite/res` com os PNGs/XML do Lite; nada modificado em `src/main/res`; `pubspec.yaml` limpo.

- [ ] **Step 10: Buildar os dois flavors**

Run:
```powershell
flutter build apk --debug --flavor lite -t lib/main_lite.dart
flutter build apk --debug --flavor prod
```
Expected: ambos geram `build/app/outputs/flutter-apk/app-lite-debug.apk` e `app-prod-debug.apk`.

- [ ] **Step 11: Conferir nome/label no APK**

Run (se o `aapt`/`aapt2` do SDK estiver disponível — ajuste o caminho da versão):

```powershell
$aapt = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Recurse -Filter aapt.exe | Select-Object -First 1 -ExpandProperty FullName
& $aapt dump badging build/app/outputs/flutter-apk/app-lite-debug.apk | Select-String "application-label"
& $aapt dump badging build/app/outputs/flutter-apk/app-prod-debug.apk | Select-String "application-label"
```
Expected: lite → `application-label:'Minhas Listas'`; prod → `application-label:'Lista de Compras'`. (Se o `aapt` não existir, valide no smoke do Step 13.)

- [ ] **Step 12: Doc dono 09 (§2.9 e smoke)**

Em `docs/09-runbook-operacoes.md`: no §2.9, atualize o nome do app Lite para **"Minhas Listas"** (identidade índigo/cesta) e acrescente ao smoke: conferir ícone (cesta sobre índigo), nome "Minhas Listas" e splash índigo. Registre que os recursos nativos do Lite vivem no source set `android/app/src/lite/res/` (sobrescrita de recursos do flavor).

- [ ] **Step 13: Smoke manual (device/emulador)**

Instale o APK lite e confirme: ícone cesta/índigo, nome "Minhas Listas", splash índigo e que abre direto em "Minhas listas" (sem login). Registre o resultado no doc 09 se houver desvio.
Expected: todos os itens corretos.

- [ ] **Step 14: Commitar**

```bash
git add android/app/build.gradle.kts android/app/src/lite/res docs/09-runbook-operacoes.md
git commit -m "F44-T03: casco nativo do Lite - nome, icone e splash (RF-31)"
```

---

### Task 4 (F44-T04): Docs donos finais, versão e fechamento da Fase 44

**Files:**
- Modify: `pubspec.yaml`, `web/version.json`, `docs/05-app-flutter.md`, `docs/12-prd.md`, `docs/14-tarefas.md`
- Test: `test/core/config/version_json_test.dart` (existente — deve continuar verde)

**Interfaces:**
- Consumes: tudo das Tasks 1–3.
- Produces: versão `1.5.0+14` e Fase 44 registrada/fechada no doc 14.

- [ ] **Step 1: Bump de versão**

Em `pubspec.yaml`: `version: 1.5.0+13` → `version: 1.5.0+14`.
Em `web/version.json`: `"build_number":"13"` → `"build_number":"14"` (o `app_name` continua `"Lista de Compras"` — a web é o app colaborativo).

- [ ] **Step 2: Rodar o teste de paridade de versão**

Run: `flutter test test/core/config/version_json_test.dart`
Expected: PASS.

- [ ] **Step 3: Doc dono 05 (§2.3 modos)**

Em `docs/05-app-flutter.md` §2.3: registre que o modo Lite tem **identidade visual própria** (índigo `#4F46E5`, cesta, nome **"Minhas Listas"**), escolhida por `IdentidadeVisual` a partir de `AppCapacidades`, e aponte a [spec da F44](superpowers/specs/2026-09-28-identidade-visual-lite-design.md).

- [ ] **Step 4: Doc dono 12 (RF-31)**

Em `docs/12-prd.md`: na linha do RF-31, acrescente "identidade visual própria (índigo/cesta, nome Minhas Listas)".

- [ ] **Step 5: Doc 14 (Fase 44)**

Em `docs/14-tarefas.md`: crie a seção **"## Fase 44 — Identidade visual do Lite (RF-31)"** com a spec e o plano (`superpowers/specs/2026-09-28-identidade-visual-lite-design.md`, `superpowers/plans/2026-09-28-identidade-visual-lite.md`), as tarefas **F44-T01…T04** marcadas `- [x]`, o dono dos docs (15/05/09/12/14) e a linha na tabela de progresso (`F44 Identidade visual do Lite | 4 | 4`).

- [ ] **Step 6: Suíte completa e análise**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: "No issues found!" e toda a suíte verde.

- [ ] **Step 7: Commit final**

```bash
git add pubspec.yaml web/version.json docs/05-app-flutter.md docs/12-prd.md docs/14-tarefas.md
git commit -m "F44-T04: docs donos, versao 1.5.0+14 e fechamento da Fase 44 (RF-31)"
```
