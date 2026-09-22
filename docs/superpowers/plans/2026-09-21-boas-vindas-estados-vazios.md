# Fase 31 — Boas-vindas e Estados Vazios (RF-27): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-27 — uma tela de boas-vindas mostrada **uma vez** (flag local) e melhorias de copy nos estados vazios que não apontam caminho. Sem schema/RLS/sync.

**Architecture:** Flag local em `SharedPreferences` (como o tema) + rota `/boas-vindas` + guard na home autenticada. Ajustes de copy em `AppStrings`.

**Tech Stack:** Flutter · Riverpod · shared_preferences · go_router · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-21-boas-vindas-estados-vazios-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F31-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `docs/01`, `docs/02`, `docs/03`** — sem schema/sync.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Sem rede/Drift; flag local (`SharedPreferences`).
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Flag local `onboardingVistoProvider`

**Files:**
- Create: `lib/features/onboarding/providers/onboarding_provider.dart`
- Create: `test/features/onboarding/onboarding_provider_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`; padrão do `temaModoProvider` (`lib/core/theme/theme_mode_provider.dart`).
- Produces: `onboardingVistoProvider` (AsyncNotifierProvider) com `marcarVisto()`.

- [ ] **Step 1: Escrever os testes que falham**

`test/features/onboarding/onboarding_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/onboarding/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_carregar_falso_quando_nunca_visto', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final visto = await container.read(onboardingVistoProvider.future);

    expect(visto, isFalse);
  });

  test('deve_carregar_verdadeiro_quando_ja_visto', () async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final visto = await container.read(onboardingVistoProvider.future);

    expect(visto, isTrue);
  });

  test('deve_marcar_visto_quando_chama', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(onboardingVistoProvider.future);

    await container.read(onboardingVistoProvider.notifier).marcarVisto();

    expect(container.read(onboardingVistoProvider).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_visto'), isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/onboarding/onboarding_provider_test.dart`
Expected: FAIL na compilação — `Target of URI doesn't exist: .../onboarding_provider.dart`.

- [ ] **Step 3: Implementar**

`lib/features/onboarding/providers/onboarding_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = 'onboarding_visto';

/// Se as boas-vindas já foram vistas (RF-27), local no dispositivo — espelha o
/// `temaModoProvider` (doc 15). Sem rede/Drift.
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave) ?? false;
  }

  Future<void> marcarVisto() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, true);
  }
}

final onboardingVistoProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/onboarding/onboarding_provider_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/features/onboarding/providers/onboarding_provider.dart test/features/onboarding/onboarding_provider_test.dart
git commit -m "F31-T01: flag local das boas-vindas (RF-27)"
```

---

### Task 2: Tela `/boas-vindas` e exibição uma vez

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/router.dart` (rota `/boas-vindas`)
- Create: `lib/features/onboarding/ui/boas_vindas_screen.dart`
- Modify: `lib/features/listas/ui/minhas_listas_screen.dart` (guard)
- Create: `test/features/onboarding/boas_vindas_screen_test.dart`
- Modify: `test/features/listas/minhas_listas_screen_test.dart`

**Interfaces:**
- Consumes: `onboardingVistoProvider`, `AppLogo`, `AppBotao`, `AppSpacing`.
- Produces: rota `/boas-vindas`; `BoasVindasScreen`; strings novas.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`:

```dart
  static const boasVindasTitulo = 'Bem-vindo ao Lista de Compras';
  static const boasVindasSubtitulo =
      'Organize suas compras e compartilhe com quem quiser.';
  static const boasVindasOffline = 'Funciona offline';
  static const boasVindasOfflineDica =
      'Suas listas ficam no aparelho e sincronizam quando a internet volta.';
  static const boasVindasCompartilhar = 'Compartilhe a lista';
  static const boasVindasCompartilharDica =
      'Convide alguém por link e comprem juntos.';
  static const boasVindasImportar = 'Importe por texto';
  static const boasVindasImportarDica =
      'Cole uma anotação e o app organiza os itens.';
  static const boasVindasDitar = 'Dite um item';
  static const boasVindasDitarDica =
      'Use o microfone para adicionar falando.';
  static const comecar = 'Começar';
```

- [ ] **Step 2: Escrever os testes que falham**

`test/features/onboarding/boas_vindas_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/onboarding/providers/onboarding_provider.dart';
import 'package:lista_compras/features/onboarding/ui/boas_vindas_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_mostrar_destaques_quando_boas_vindas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: const BoasVindasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.boasVindasOffline), findsOneWidget);
    expect(find.text(AppStrings.boasVindasCompartilhar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasImportar), findsOneWidget);
    expect(find.text(AppStrings.boasVindasDitar), findsOneWidget);
    expect(find.text(AppStrings.comecar), findsOneWidget);
  });

  testWidgets('deve_marcar_visto_e_navegar_quando_comecar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/boas-vindas',
      routes: [
        GoRoute(
          path: '/boas-vindas',
          builder: (_, _) => const BoasVindasScreen(),
        ),
        GoRoute(path: '/listas', builder: (_, _) => const Text('listas')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.comecar));
    await tester.pumpAndSettle();

    expect(find.text('listas'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_visto'), isTrue);
  });
}
```

Em `test/features/listas/minhas_listas_screen_test.dart`:
- No `setUp`, adicionar `SharedPreferences.setMockInitialValues({'onboarding_visto': true});` (para os testes existentes **não** abrirem as boas-vindas) e importar `shared_preferences`.
- No `abrirTela`, acrescentar a rota `/boas-vindas` ao `GoRouter` de teste:
  ```dart
        GoRoute(
          path: '/boas-vindas',
          builder: (_, _) => const Scaffold(body: Text('boas-vindas')),
        ),
  ```
- Dois testes novos:

```dart
  testWidgets('deve_abrir_boas_vindas_quando_nao_visto', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': false});
    await abrirTela(tester);
    expect(find.text('boas-vindas'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_abrir_boas_vindas_quando_ja_visto', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    await abrirTela(tester);
    expect(find.text('boas-vindas'), findsNothing);
    await fechar(tester);
  });
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/onboarding/boas_vindas_screen_test.dart test/features/listas/minhas_listas_screen_test.dart`
Expected: FAIL — a tela/rota/guard ainda não existem.

- [ ] **Step 4: Implementar**

`lib/features/onboarding/ui/boas_vindas_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_logo.dart';
import '../providers/onboarding_provider.dart';

/// Tela de boas-vindas (RF-27), mostrada uma vez na primeira vez no app.
class BoasVindasScreen extends ConsumerWidget {
  const BoasVindasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.tela,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo()),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.boasVindasTitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.boasVindasSubtitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _Destaque(
                    icone: Icons.cloud_off_outlined,
                    titulo: AppStrings.boasVindasOffline,
                    dica: AppStrings.boasVindasOfflineDica,
                  ),
                  const _Destaque(
                    icone: Icons.group_outlined,
                    titulo: AppStrings.boasVindasCompartilhar,
                    dica: AppStrings.boasVindasCompartilharDica,
                  ),
                  const _Destaque(
                    icone: Icons.playlist_add,
                    titulo: AppStrings.boasVindasImportar,
                    dica: AppStrings.boasVindasImportarDica,
                  ),
                  const _Destaque(
                    icone: Icons.mic_none,
                    titulo: AppStrings.boasVindasDitar,
                    dica: AppStrings.boasVindasDitarDica,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppBotao(
                    rotulo: AppStrings.comecar,
                    onPressed: () async {
                      await ref
                          .read(onboardingVistoProvider.notifier)
                          .marcarVisto();
                      if (context.mounted) context.go('/listas');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque({required this.icone, required this.titulo, required this.dica});

  final IconData icone;
  final String titulo;
  final String dica;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleSmall),
                Text(dica, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Em `lib/router.dart`, adicionar (após `/mercado/:listaId`):

```dart
      GoRoute(
        path: '/boas-vindas',
        builder: (context, state) => const BoasVindasScreen(),
      ),
```

(import de `BoasVindasScreen`.)

Em `lib/features/listas/ui/minhas_listas_screen.dart`, tornar a tela `ConsumerStatefulWidget` com o guard:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/providers/onboarding_provider.dart';
import 'painel_listas.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, wireframe 10 §2, RF-02): as listas em
/// que o usuário é dono. Abre as boas-vindas uma vez (RF-27).
class MinhasListasScreen extends ConsumerStatefulWidget {
  const MinhasListasScreen({super.key});

  @override
  ConsumerState<MinhasListasScreen> createState() => _MinhasListasScreenState();
}

class _MinhasListasScreenState extends ConsumerState<MinhasListasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final visto = await ref.read(onboardingVistoProvider.future);
      if (!visto && mounted) context.push('/boas-vindas');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const PainelListas(filtro: FiltroListas.minhas);
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/onboarding/boas_vindas_screen_test.dart test/features/listas/minhas_listas_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/router.dart lib/features/onboarding/ui/boas_vindas_screen.dart lib/features/listas/ui/minhas_listas_screen.dart test/features/onboarding/boas_vindas_screen_test.dart test/features/listas/minhas_listas_screen_test.dart
git commit -m "F31-T02: tela de boas-vindas e exibicao uma vez (RF-27)"
```

---

### Task 3: Estado vazio da lista, docs donos e fechamento

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (`nenhumItemDica`)
- Modify: `test/features/listas/tela_lista_screen_test.dart`
- Modify: `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/12-prd.md`, `docs/14-tarefas.md`, `docs/16-roadmap-pos-mvp.md`

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: Melhorar a dica da lista vazia**

Em `lib/core/l10n/app_strings.dart`, trocar:

```dart
  static const nenhumItemDica = 'Adicione o primeiro item no campo acima.';
```

por:

```dart
  static const nenhumItemDica =
      'Adicione no campo acima, importe uma lista ou dite um item.';
```

- [ ] **Step 2: Ajustar/adicionar o teste do vazio**

Em `test/features/listas/tela_lista_screen_test.dart`, localizar o teste que afirma `AppStrings.nenhumItemDica` (ou o vazio da lista) e garantir a asserção com a nova copy; se não houver, adicionar:

```dart
  testWidgets('deve_mostrar_dica_com_caminhos_quando_lista_vazia', (
    tester,
  ) async {
    // abrir uma lista sem itens (harness real)
    expect(find.text(AppStrings.nenhumItemDica), findsOneWidget);
    await fechar(tester);
  });
```

- [ ] **Step 3: Docs donos**

- `05`: nova subseção da tela de boas-vindas (rota `/boas-vindas`, uma vez, flag local, destaques) + ajustar o vazio da lista em §6.3.
- `10`: wireframe das boas-vindas + nota dos destaques; nota do vazio da lista atualizado.
- `12 §2`: `RF-27 | Boas-vindas (uma vez) + estados vazios explicativos | 05 + 10 | F31 | ...`; §6: rastreabilidade `RF-27 | US-01 | F31 | F31-T01, F31-T02 | Unit provider + widgets`.
- `14`: Fase 31 com F31-T01…T03 `[x]` + CPs; tabela `| F31 Boas-vindas e vazios | 3 | 3 |` e total `| **Total** | **167** | **165** |`.
- `16`: Onda A A7 → `concluído (F31-T01…T03)`.

- [ ] **Step 4: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart test/features/listas/tela_lista_screen_test.dart docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F31-T03: dica do vazio, docs donos e fechamento (RF-27)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 flag → Task 1; §4/§5 tela + exibição → Task 2; §6 vazios → Task 3; §7 testes → Tasks 1–3; §8 docs → Task 3.
- **Placeholders:** nenhum "TBD"; todo o código novo está completo. O teste da lista vazia reusa o harness real.
- **Consistência de tipos:** `onboardingVistoProvider` (AsyncNotifierProvider<OnboardingNotifier, bool>), `BoasVindasScreen`, rota `/boas-vindas`, strings `boasVindas*`/`comecar`, progresso 167/165 — idênticos entre tarefas.
- **Risco conhecido:** `MinhasListasScreen` passa a ler `SharedPreferences`; os testes de `minhas_listas_screen_test.dart` precisam de `setMockInitialValues` no `setUp` (Task 2) para os testes existentes não abrirem as boas-vindas.
- **YAGNI:** uma página só, sem tour, sem mostrar a cada login.
