# Fase 44 — Identidade visual própria do Lite (design)

> **Status:** aprovado em 28/09/2026 (decisões na Seção 8)
> **Fase:** 44 · **Requisito:** RF-31 (identidade visual própria do Lite)
> **Docs donos:** [15](../15-design-system.md) (design system/identidade), [05](../05-app-flutter.md) (app/modos), [09](../09-runbook-operacoes.md) (build/distribuição), [12](../12-prd.md) (PRD), [14](../14-tarefas.md) (tarefas)
> **Origem:** pedido do dono (28/09/2026): "uma identidade visual própria para o lite".

---

## 1. Motivação

1. **O Lite não tem marca própria.** Por dentro, o flavor `lite` usa a marca **verde** do app colaborativo (seed `#2E7D32`, `AppLogo`, splash verdes). O único sinal de distinção é o fundo do ícone adaptativo Android sobrescrito para azul `#1565C0` (`android/app/src/lite/res/values/colors.xml`) — um ajuste isolado e inconsistente com o resto do app.
2. **Decisão do dono:** dar ao Lite uma identidade visual própria (índigo + símbolo de cesta + nome "Minhas Listas"), de ponta a ponta — ícone, splash, cabeçalho e tema — sem tocar no app colaborativo.
3. **A base já separa os modos.** `AppModo`/`AppCapacidades` (`lib/core/config/app_modo.dart`) e os dois entrypoints (`main.dart`/`main_lite.dart`) já existem desde a F41; a identidade é uma **costura** sobre essa separação.

## 2. Escopo

**Dentro:**
- Marca **índigo** (`#4F46E5`) + símbolo de **cesta** + nome **"Minhas Listas"** no flavor `lite`.
- Tema do app do Lite com o novo seed, via `IdentidadeVisual` derivada de `AppCapacidades` (§4).
- `AppLogo` e o nome do app (task switcher / boas-vindas) sensíveis ao modo.
- Assets de marca do Lite (SVG master + PNGs) e recursos nativos Android do flavor (ícone e splash).
- Docs donos (15/05/09/12/14) + testes + bump de versão.

**Fora:**
- Alterar a marca do app colaborativo (`prod` segue verde, carrinho, "Lista de Compras" — nada muda).
- iOS/Web/desktop do Lite (hoje o Lite só compila Android; o Lite no iOS segue adiado por decisão — [16](../16-roadmap-pos-mvp.md)).
- Tipografia própria, componente próprio ou um design system paralelo (descartado: escopo "casco nativo + marca no app").
- Schema/RLS/migrations/sync (nenhuma mudança de dados).

## 3. Marca e paleta

| Item | `prod` (colaborativo) | `lite` |
| :--- | :--- | :--- |
| Nome (launcher + task switcher) | Lista de Compras | **Minhas Listas** |
| Seed (Material 3) | `#2E7D32` (verde) | **`#4F46E5`** (índigo) |
| Símbolo | carrinho (`shopping_cart`) | **cesta** (`shopping_basket`) |
| Splash (claro / escuro) | `#2E7D32` / `#1B5E20` | **`#4F46E5` / `#3730A3`** |

- **Paleta:** derivada por `ColorScheme.fromSeed(seed)` (claro e escuro), como hoje. As cores semânticas (`success`/`warning`/`info` em `app_semantic_colors.dart`) **não** mudam — são de status, não de marca.
- **Contraste:** os pares `container`/`on*` gerados pelo M3 permanecem ≥ AA; validado por teste (RNF-06, [12 §3](../12-prd.md)).
- **Glifo:** Material Symbols `shopping_basket` (Apache-2.0), mesma licença e linguagem do `shopping_cart` atual ([15 §6](../15-design-system.md)).
- **Boas-vindas no Lite:** título **"Bem-vindo(a)"** (neutro, evita a concordância "ao Minhas Listas"); o subtítulo próprio do Lite já existe (`boasVindasSubtituloLite`).

## 4. Código (Flutter)

**Novo — `lib/core/theme/identidade_visual.dart`:**

```dart
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
```

- **Token novo:** `AppColors.seedLite = Color(0xFF4F46E5)` em `lib/core/theme/tokens/app_colors.dart` (doc 15 §1).
- **Provider:** `identidadeVisualProvider` **derivado de `AppCapacidades`** — `ref.watch(capacidadesProvider).nuvem ? IdentidadeVisual.colaborativo : IdentidadeVisual.lite`. Nenhum widget decide por `AppModo` (regra da F41 preservada).
- **`AppTheme`:** `claro`/`escuro` deixam de ser getters e passam a receber a identidade: `AppTheme.claro(identidade)` / `AppTheme.escuro(identidade)` (usam `identidade.seed` no `ColorScheme.fromSeed`).
- **`app.dart`:** lê `identidadeVisualProvider`; `theme`/`darkTheme` a partir dela e `title: identidade.nomeApp`.
- **`AppLogo`:** vira `ConsumerWidget` e usa `identidade.logoAsset` (prod `logo.png`, lite `logo_lite.png`); tamanho/recorte inalterados (28dp, `AppRadius.sm`).
- **Strings (`app_strings.dart`):** `appNomeLite = 'Minhas Listas'` e `boasVindasTituloLite = 'Bem-vindo(a)'`. A tela de boas-vindas passa a escolher o título pela capacidade (mesmo padrão das strings `...Lite` já existentes); `appNomeLite` também alimenta `MaterialApp.title` via identidade.

## 5. Nativo Android

O flavor `lite` **sobrescreve recursos de mesmo nome** no seu source set (`android/app/src/lite/res/`), que tem prioridade sobre `main` no merge do Gradle.

- **Nome:** `android/app/build.gradle.kts` — no flavor `lite`, `resValue("string", "app_name", "Minhas Listas")` (hoje "Lista de Compras Lite").
- **Ícone adaptativo:** `mipmap-anydpi-v26/ic_launcher.xml` fica no `main` (referencia `@color/ic_launcher_background` e `@drawable/ic_launcher_foreground`); o Lite sobrescreve:
  - `values/colors.xml` → `ic_launcher_background = #4F46E5`;
  - `drawable-*/ic_launcher_foreground.png` (cesta);
  - `mipmap-*/ic_launcher.png` (ícones legados, cheios em índigo).
- **Splash (pré-Android 12):** `LaunchTheme` usa `@drawable/launch_background` (layer-list `@drawable/background` + `@drawable/splash`). O Lite sobrescreve `drawable-*/background.png` (fundo índigo) e `drawable-*/splash.png` (cesta), incluindo as variantes `-night-*`.
- **Splash (Android 12+):** sobrescreve `values-v31/styles.xml` e `values-night-v31/styles.xml` (`windowSplashScreenBackground = #4F46E5` / `#3730A3`) e o bitmap `drawable-*/android12splash.png` (+ `-night-*`).
- **Fora:** iOS/Web/desktop do Lite (não compilam hoje) não mudam; o `prod` Android não é afetado (todas as sobrescritas são do source set `lite`).

## 6. Assets e geração

- **Masters vetoriais novos** (fonte de verdade): `assets/branding/logo_lite.svg` (ícone cheio, cesta branca sobre índigo) e `assets/branding/logo_glyph_lite.svg` (glifo transparente, dentro da área segura).
- **Bitmaps gerados** (1024px, commitados): `logo_lite.png` e `logo_glyph_lite.png` — alimentam o `AppLogo` (Lite) e a geração nativa.
- **Splash no app:** `AppLogo`/marca do Lite usam `logo_lite`; o splash nativo usa o `logo_glyph_lite`.
- **Regeneração:** `dart run flutter_launcher_icons` e `dart run flutter_native_splash:create` geram **sempre para `main`**. Processo do Lite: gerar com a config do Lite, **copiar** os arquivos relevantes para `android/app/src/lite/res/` e **regenerar** com a config do `prod` (garantindo que `main` volte ao verde). O passo exato vai no plano; a config do `prod` em `pubspec.yaml` não muda.

## 7. Docs, testes e versionamento

- **Docs donos (no mesmo PR):** [15](../15-design-system.md) §1 (token `seedLite`), §2 (tema por identidade) e §6 (duas marcas: verde/carrinho e índigo/cesta); [05](../05-app-flutter.md) §2.3 (nome/identidade do Lite); [09](../09-runbook-operacoes.md) §2.9 (build/distribuição e smoke com o nome novo); [12](../12-prd.md) (RF-31: identidade visual própria); [14](../14-tarefas.md) (Fase 44 + progresso).
- **Testes:**
  - `identidade_visual_test`: cada `AppCapacidades` seleciona seed/nome/asset corretos.
  - Widget: app **Lite** usa seed índigo e `logo_lite`; app **prod** usa verde e `logo` (garante que a marca do prod não regrediu).
  - Acessibilidade: contraste AA do `ColorScheme` do Lite (`textContrastGuideline`).
  - **Nativo não é testável por unidade** → smoke manual no 09: build `--flavor lite -t lib/main_lite.dart` e conferir ícone, nome ("Minhas Listas") e splash.
- **Suíte do `prod` continua verde** (nada de comportamento muda).
- **Versão:** `1.5.0+13` → `1.5.0+14` (UI/nativo; sem DB).

## 8. Decisões registradas (28/09/2026)

1. **Direção:** índigo (`#4F46E5`).
2. **Símbolo:** cesta (`shopping_basket`).
3. **Nome:** "Minhas Listas" (launcher + título do app).
4. **Boas-vindas (Lite):** "Bem-vindo(a)".
5. **Escopo:** casco nativo + marca no app (não é design system paralelo).
6. **Abordagem:** identidade por capacidades (`IdentidadeVisual` + provider) — `prod` intacto, sem `AppModo` na UI.
7. **Splash/ícone por flavor:** sobrescrita de recursos no source set `lite`.
8. **Repetição aceita:** o título do app ("Minhas Listas") e a primeira aba ("Minhas listas") coexistem — [15](../15-design-system.md) §6 registra.

## 9. Riscos

- **Splash por flavor é o passo mais delicado** (os arquivos do `flutter_native_splash` são globais por natureza). Mitigação: sobrescrita por nome de recurso + conferência no smoke; se algum recurso não puder ser sobrescrito, documentar o desvio em [09](../09-runbook-operacoes.md).
- **Geração de ícones escreve em `main`:** o processo de copiar para `src/lite/res` e regerar o `prod` precisa ser seguido à risca para não deixar o ícone do `prod` índigo (regressão). Coberto por conferência de `git status` no plano.

## 10. Documentos relacionados

- [15 Design System](../15-design-system.md) — dono da identidade visual e tokens
- [05 App Flutter](../05-app-flutter.md) — modos/flavor e telas
- [09 Runbook de Operações](../09-runbook-operacoes.md) — builds e distribuição
- [12 PRD](../12-prd.md) — RF-31
- [2026-09-24-flavor-lite-sem-conta-design.md](2026-09-24-flavor-lite-sem-conta-design.md) — F41, flavor Lite
