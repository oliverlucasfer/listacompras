# Widget Android / Quick-add — Fase 55 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um **AppWidget** Android na tela inicial com a **última lista** + **nº de pendentes** + botão **"Adicionar item"**, que abre o app na rota `/adicionar` (campo focado) — 100% offline, Android-only.

**Architecture:** Ponte `home_widget` (Flutter↔widget) + `AppWidgetProvider` nativo (Kotlin/XML). O Dart guarda `ultima_lista_id` (SharedPreferences), empurra os dados ao widget e trata o toque. Testes no Dart com **fake** da ponte; widget real = smoke em device.

**Tech Stack:** Flutter, Riverpod, `home_widget`, Kotlin/Android (RemoteViews).

**Spec:** `docs/superpowers/specs/2026-09-30-widget-android-design.md` (RF-38 / Fase 55)

## Global Constraints

- App 100% local: **nenhuma** rede; dados do widget só locais. A única dependência nova é **`home_widget`**.
- **Android-only** (iOS/Web/Desktop sem widget; o build web/desktop continua compilando).
- A atualização do widget é **best-effort** (falha silenciosa, nunca quebra a UI).
- `App*` componentes/tokens + `AppStrings`; pt-BR; testes `deve_<resultado>_quando_<condição>`.
- Não alterar o comportamento existente das telas; só acrescentar foco/roteamento e a ponte.
- Namespace Kotlin/Android do app: **`br.com.oliverlucas.lista_compras`**; applicationId **`br.com.oliverlucas.listacompras.lite`**.

---

## File Structure

- `lib/features/widget/domain/widget_service.dart` — contrato `WidgetService` + `WidgetDados`.
- `lib/features/widget/data/widget_service_home_widget.dart` — impl. com `home_widget`.
- `lib/features/widget/data/ultima_lista_service.dart` — `ultima_lista_id` (SharedPreferences).
- `lib/features/widget/providers/widget_providers.dart` — providers + `nomeAppWidget`.
- `lib/features/widget/ui/adicionar_screen.dart` — rota `/adicionar`.
- `lib/features/widget/ui/widget_atualizador.dart` — atualizações (streams + resume) e toque do widget.
- Modificados: `lib/router.dart`, `lib/features/listas/ui/tela_lista_screen.dart` (foco + registrar última lista), `lib/app.dart` ou shell (montar o atualizador), `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/.../MinhasListasWidgetProvider.kt`, `android/app/src/main/res/{layout,xml}/*`, `pubspec.yaml`, `lib/core/l10n/app_strings.dart`.

---

## Task 1: Serviços Dart (`ultima_lista_id` + ponte do widget)

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add home_widget`)
- Create: `lib/features/widget/domain/widget_service.dart`, `lib/features/widget/data/widget_service_home_widget.dart`, `lib/features/widget/data/ultima_lista_service.dart`, `lib/features/widget/providers/widget_providers.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/widget/widget_services_test.dart`

**Interfaces you produce (Tasks 2/3 depend on these):**
- `class WidgetDados { final String? titulo; final int pendentes; }`
- `abstract interface class WidgetService { Future<void> atualizar(WidgetDados dados); Future<String?> toqueInicial(); Stream<String> toques(); }`
- `class WidgetServiceHomeWidget implements WidgetService` (usa `home_widget`).
- `class UltimaListaService { Future<void> registrar(String listaId); Future<String?> ler(); }`
- `const nomeAppWidget = 'MinhasListasWidgetProvider';`
- providers: `widgetServiceProvider`, `ultimaListaServiceProvider`.

- [ ] **Step 1: Add dependency**

Run: `flutter pub add home_widget`
Expected: `home_widget` no `pubspec.yaml`; `flutter pub get` OK. (Confira a versão resolvida e a API do pacote.)

- [ ] **Step 2: Add strings**

```dart
  // Widget Android (RF-38, F55)
  static const widgetPendentesSingular = '1 pendente';
  static String widgetPendentesPlural(int n) => '$n pendentes';
  static const widgetSemLista = 'Crie sua primeira lista';
  static const widgetAdicionar = 'Adicionar item';
  static const widgetLista = 'Lista';
```

- [ ] **Step 3: Write the failing test**

`test/features/widget/widget_services_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/widget/domain/widget_service.dart';
import 'package:lista_compras/features/widget/data/ultima_lista_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WidgetFake implements WidgetService {
  final chamadas = <WidgetDados>[];
  @override
  Future<void> atualizar(WidgetDados dados) async => chamadas.add(dados);
  @override
  Future<String?> toqueInicial() async => null;
  @override
  Stream<String> toques() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_gravar_e_ler_ultima_lista', () async {
    SharedPreferences.setMockInitialValues({});
    final s = UltimaListaService();
    await s.registrar('l1');
    expect(await s.ler(), 'l1');
  });

  test('deve_enviar_titulo_e_pendentes_quando_atualiza', () async {
    final f = _WidgetFake();
    await f.atualizar(const WidgetDados(titulo: 'Semana', pendentes: 3));
    expect(f.chamadas.single.titulo, 'Semana');
    expect(f.chamadas.single.pendentes, 3);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/widget/widget_services_test.dart`
Expected: FAIL — tipos inexistentes.

- [ ] **Step 5: Implement**

`lib/features/widget/domain/widget_service.dart`:

```dart
class WidgetDados {
  const WidgetDados({required this.titulo, required this.pendentes});
  final String? titulo;
  final int pendentes;
}

/// Ponte com o widget da tela inicial (Android, RF-38). Fake nos testes.
abstract interface class WidgetService {
  Future<void> atualizar(WidgetDados dados);
  Future<String?> toqueInicial();
  Stream<String> toques();
}
```

`lib/features/widget/data/ultima_lista_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

const _chaveUltimaLista = 'ultima_lista_id';

class UltimaListaService {
  Future<void> registrar(String listaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUltimaLista, listaId);
  }

  Future<String?> ler() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveUltimaLista);
  }
}
```

`lib/features/widget/data/widget_service_home_widget.dart`:

```dart
import 'package:home_widget/home_widget.dart';

import '../domain/widget_service.dart';

const nomeAppWidget = 'MinhasListasWidgetProvider';

class WidgetServiceHomeWidget implements WidgetService {
  @override
  Future<void> atualizar(WidgetDados dados) async {
    await HomeWidget.saveWidgetData<String>('titulo', dados.titulo ?? '');
    await HomeWidget.saveWidgetData<int>('pendentes', dados.pendentes);
    await HomeWidget.saveWidgetData<bool>('tem_lista', dados.titulo != null);
    await HomeWidget.updateWidget(name: nomeAppWidget);
  }

  @override
  Future<String?> toqueInicial() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return uri?.host;
  }

  @override
  Stream<String> toques() =>
      HomeWidget.widgetClicked.map((uri) => uri?.host ?? '').where((h) => h.isNotEmpty);
}
```

`lib/features/widget/providers/widget_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ultima_lista_service.dart';
import '../data/widget_service_home_widget.dart';
import '../domain/widget_service.dart';

final widgetServiceProvider = Provider<WidgetService>(
  (ref) => WidgetServiceHomeWidget(),
);
final ultimaListaServiceProvider = Provider<UltimaListaService>(
  (ref) => UltimaListaService(),
);
```

- [ ] **Step 6: Run test, format and analyze**

Run: `flutter test test/features/widget/widget_services_test.dart && dart format . && flutter analyze`
Expected: verde.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/widget lib/core/l10n/app_strings.dart test/features/widget
git commit -m "feat(widget): servicos dart do widget e ultima lista (RF-38, F55)"
```

---

## Task 2: Rota `/adicionar` + foco no campo + registro da última lista

**Files:**
- Create: `lib/features/widget/ui/adicionar_screen.dart`
- Modify: `lib/router.dart`, `lib/features/listas/ui/tela_lista_screen.dart`
- Test: `test/features/widget/adicionar_route_test.dart`

**Interfaces:**
- Consumes: `ultimaListaServiceProvider`, `listasProvider`/`watchListas` (resolver lista).
- Produces: rota `/adicionar`; `TelaListaScreen({required listaId, bool foco = false})` com `autofocus` no campo; gravação de `ultima_lista_id` ao abrir a lista.

- [ ] **Step 1: Write the failing widget test**

`test/features/widget/adicionar_route_test.dart` — com Drift in-memory e `ultima_lista_id` apontando para `l1` (via `SharedPreferences.setMockInitialValues`), abrir `/adicionar` (harness com o `routerProvider`) e assertar que navega para `/lista/l1` e que o campo "Adicionar item" está focado (ex.: `FocusScope`/`tester.testTextInput` ou o `autofocus` aplicado). Sem lista → cai em `/listas`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/widget/adicionar_route_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`lib/features/widget/ui/adicionar_screen.dart` (resolve a última lista e redireciona):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_esqueleto.dart';
import '../../listas/providers/listas_providers.dart';
import '../providers/widget_providers.dart';

class AdicionarScreen extends ConsumerStatefulWidget {
  const AdicionarScreen({super.key});
  @override
  ConsumerState<AdicionarScreen> createState() => _AdicionarScreenState();
}

class _AdicionarScreenState extends ConsumerState<AdicionarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolver());
  }

  Future<void> _resolver() async {
    final ultima = await ref.read(ultimaListaServiceProvider).ler();
    final listas = await ref.read(listasRepositoryProvider).watchListas().first;
    final alvo = listas.where((l) => l.id == ultima).firstOrNull ??
        (listas.isNotEmpty ? listas.first : null);
    if (!mounted) return;
    if (alvo == null) {
      context.go('/listas');
    } else {
      context.pushReplacement('/lista/${alvo.id}?foco=1');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppEsqueleto(linhas: 4));
}
```

`lib/router.dart`: adicionar

```dart
      GoRoute(
        path: '/adicionar',
        builder: (context, state) => const AdicionarScreen(),
      ),
```

e passar o foco na rota da lista:

```dart
      GoRoute(
        path: '/lista/:listaId',
        builder: (context, state) => TelaListaScreen(
          listaId: state.pathParameters['listaId']!,
          foco: state.uri.queryParameters['foco'] == '1',
        ),
      ),
```

`tela_lista_screen.dart`: `TelaListaScreen({required this.listaId, this.foco = false})`; ao abrir, registrar a última lista (`ref.read(ultimaListaServiceProvider).registrar(listaId)` num `initState`/`addPostFrameCallback`); passar `autofocus: widget.foco` ao `_CampoAdicionar` (que deve repassar ao `AppCampoTexto`/`TextField`).

- [ ] **Step 4: Run test, format and analyze**

Run: `flutter test test/features/widget/adicionar_route_test.dart && dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/widget lib/router.dart lib/features/listas/ui/tela_lista_screen.dart test/features/widget
git commit -m "feat(widget): rota adicionar e foco no campo (RF-38, F55)"
```

---

## Task 3: Atualização do widget e toque → navegação

**Files:**
- Create: `lib/features/widget/ui/widget_atualizador.dart`
- Modify: `lib/app.dart` (montar o `WidgetAtualizador` no topo)
- Test: `test/features/widget/widget_atualizador_test.dart`

**Interfaces:**
- Consumes: `widgetServiceProvider`, `ultimaListaServiceProvider`, `listasProvider`/`itensDaListaProvider`.
- Produces: `WidgetAtualizador` (Widget que atualiza o widget ao mudar a última lista/itens e no resume; trata o toque → `/adicionar`).

- [ ] **Step 1: Write the failing test**

`test/features/widget/widget_atualizador_test.dart` — com `WidgetService` fake injetado + Drift in-memory: (a) quando há lista, o payload enviado tem o título e a contagem de pendentes; (b) emitir um toque (`toques()`) navega para `/adicionar` (verifique via `routerProvider`/observando a rota); (c) `toqueInicial()` não-nulo navega no start.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/widget/widget_atualizador_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`WidgetAtualizador` (shell `ConsumerStatefulWidget` com `WidgetsBindingObserver`):
- `initState`: `WidgetsBinding.instance.addObserver(this)`; escuta `widgetServiceProvider.toques()` → `context.go('/adicionar')`; chama `toqueInicial()` uma vez; dispara a primeira atualização.
- `didChangeAppLifecycleState(resumed)`: atualiza o widget.
- Atualização: lê `ultimaListaService.ler()`; resolve a lista (título) e conta pendentes via `itensDaLista`; chama `widgetService.atualizar(WidgetDados(titulo:, pendentes:))` com **debounce** (ex.: 300 ms) e em `try/catch` (best-effort). Usa `ref.listen`/`ref.watch` de `listasProvider` e do stream de itens da última lista.
- Sem lista → `WidgetDados(titulo: null, pendentes: 0)`.

Montar no topo do app (`lib/app.dart`) para ficar ativo em todo o app.

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/widget/widget_atualizador_test.dart && dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/widget lib/app.dart test/features/widget
git commit -m "feat(widget): atualizacao e toque do widget (RF-38, F55)"
```

---

## Task 4: Nativo Android (provider, layout, info, manifest)

**Files:**
- Create: `android/app/src/main/kotlin/br/com/oliverlucas/lista_compras/MinhasListasWidgetProvider.kt`
- Create: `android/app/src/main/res/layout/widget_minhas_listas.xml`
- Create: `android/app/src/main/res/xml/widget_minhas_listas_info.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `HomeWidgetPlugin` (do `home_widget`), chaves `titulo`/`pendentes`/`tem_lista`, `nomeAppWidget = 'MinhasListasWidgetProvider'`.

- [ ] **Step 1: Implement the native widget**

`MinhasListasWidgetProvider.kt` (RemoteViews: título + contagem + botão; `onUpdate` lê os dados via `HomeWidgetPlugin.getData`, e o botão usa `HomeWidgetLaunchIntent.getActivity(...)` apontando para `MainActivity` com a URI `minhas-listas://adicionar`). Consulte a documentação da versão resolvida do `home_widget` para os nomes exatos (`HomeWidgetPlugin`, `HomeWidgetLaunchIntent`).

`widget_minhas_listas.xml` (layout simples: `TextView` do app + `TextView` do título + `TextView` da contagem + `Button` "Adicionar"). `widget_minhas_listas_info.xml` (`minWidth`/`minHeight`, `updatePeriodMillis=0`, `initialLayout`).

`AndroidManifest.xml` — dentro de `<application>`:

```xml
        <receiver
            android:name=".MinhasListasWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/widget_minhas_listas_info" />
        </receiver>
```

- [ ] **Step 2: Verify the build**

Run: `flutter build apk --debug` (deve compilar o nativo) e, se possível, `flutter build apk --release` (o guard de manifest de release da F47/F48 deve seguir verde: sem `INTERNET`/SDK Firebase; o widget não adiciona esses nós).
Expected: builds OK.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main
git commit -m "feat(widget): AppWidgetProvider nativo e manifest (RF-38, F55)"
```

---

## Task 5: Docs donos e fechamento da Fase 55

**Files:** `docs/12-prd.md` (RF-38 + matriz), `docs/05-app-flutter.md` (§6.17 widget/serviços/rota), `docs/10-wireframes-telas.md` (widget card + estado sem lista), `docs/09-runbook-operacoes.md` (pacote `home_widget` + setup nativo + smoke em device), `docs/15-design-system.md` (cores do widget), `docs/14-tarefas.md` (Fase 55 + progresso), `docs/16-roadmap-pos-mvp.md` (D3 concluído).

- [ ] **Step 1–3:** add RF-38; doc 05 (fluxo/serviços/rota/atualização); doc 10 (widget); doc 09 (dep + setup + smoke); doc 15 (cores); doc 14 (Fase 55 F55-T01…T05 + progresso; Total atual 293/291 → 298/296); doc 16 (D3).

- [ ] **Step 4: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs(widget): RF-38, 05, 09, 10, 14, 15 e 16 (F55)"
```

---

## Self-Review (cobertura da spec — Fase 55)

- §3 arquitetura (ponte, última lista, rota) → Tasks 1/2.
- §4 widget/atualização/deep link → Tasks 3/4.
- §5 regras (sem lista, fallback, best-effort, Android-only) → Tasks 2/3/4.
- §6 deps/riscos → Tasks 1/4/5.
- §7 testes (fake, resolução, gatilhos) → Tasks 1/2/3.

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-widget-android-design.md`
- [05 App Flutter](../05-app-flutter.md) · [09 Runbook](../09-runbook-operacoes.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
