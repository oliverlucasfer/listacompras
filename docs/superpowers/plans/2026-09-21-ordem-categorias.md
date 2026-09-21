# Fase 28 — Ordem Pessoal das Categorias (RF-24): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-24 — o usuário reordena as 11 categorias (ordem global, local no dispositivo) e a tela da lista agrupa os pendentes nessa ordem. Sem schema/RLS/sync.

**Architecture:** Funções puras de ordem + um `AsyncNotifier` sobre `SharedPreferences` (como o tema). Em Configurações, uma tela com `ReorderableListView`. A tela da lista passa a iterar a ordem salva (fallback: ordem do enum).

**Tech Stack:** Flutter · Riverpod · shared_preferences · go_router · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-21-ordem-categorias-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F28-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `docs/02`, `docs/03`** (sem schema/sync). `docs/01` recebe só uma frase na Task 3.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- O enum de categorias **não muda**; a ordem do enum é o **padrão/fallback**.
- Preferência **local** (SharedPreferences), como o tema — sem rede/Drift.
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Domínio e provider — ordem das categorias

**Files:**
- Create: `lib/features/listas/domain/ordem_categorias.dart`
- Create: `lib/features/listas/providers/ordem_categorias_provider.dart`
- Create: `test/features/listas/ordem_categorias_test.dart`
- Create: `test/features/listas/ordem_categorias_provider_test.dart`

**Interfaces:**
- Consumes: `CategoriaItem` (`lib/features/listas/domain/categoria.dart`, com `.valor`/`.rotulo`); `SharedPreferences`; padrão do `temaModoProvider` (`lib/core/theme/theme_mode_provider.dart`).
- Produces: `List<CategoriaItem> normalizarOrdem(List<CategoriaItem>)`; `String serializarOrdem(List<CategoriaItem>)`; `List<CategoriaItem> desserializarOrdem(String?)`; `List<T> moverItem<T>(List<T>, int, int)`; `ordemCategoriasProvider` (AsyncNotifierProvider) com `definir`/`restaurarPadrao`.

- [ ] **Step 1: Escrever os testes que falham**

`test/features/listas/ordem_categorias_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/ordem_categorias.dart';

void main() {
  test('deve_normalizar_quando_faltam_categorias', () {
    final ordem = normalizarOrdem([CategoriaItem.bebidas, CategoriaItem.frios]);
    expect(ordem.length, CategoriaItem.values.length);
    expect(ordem.take(2).toList(), [CategoriaItem.bebidas, CategoriaItem.frios]);
    expect(ordem.toSet(), CategoriaItem.values.toSet());
  });

  test('deve_ignorar_desconhecidas_quando_desserializar', () {
    final ordem = desserializarOrdem('bebidas,inexistente,frios');
    expect(ordem.take(2).toList(), [CategoriaItem.bebidas, CategoriaItem.frios]);
    expect(ordem.length, CategoriaItem.values.length);
  });

  test('deve_serializar_e_desserializar_round_trip_quando_ordem_valida', () {
    final ordem = normalizarOrdem([
      CategoriaItem.higiene,
      ...CategoriaItem.values.where((c) => c != CategoriaItem.higiene),
    ]);
    expect(desserializarOrdem(serializarOrdem(ordem)), ordem);
  });

  test('deve_retornar_padrao_quando_csv_nulo_ou_vazio', () {
    expect(desserializarOrdem(null), CategoriaItem.values);
    expect(desserializarOrdem(''), CategoriaItem.values);
    expect(desserializarOrdem('   '), CategoriaItem.values);
  });

  test('deve_mover_quando_moverItem', () {
    expect(moverItem([1, 2, 3], 0, 1), [2, 1, 3]); // desce
    expect(moverItem([1, 2, 3], 2, 0), [3, 1, 2]); // sobe
  });
}
```

`test/features/listas/ordem_categorias_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/providers/ordem_categorias_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_carregar_ordem_salva_quando_build', () async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias':
          '${CategoriaItem.bebidas.valor},${CategoriaItem.frios.valor}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ordem = await container.read(ordemCategoriasProvider.future);

    expect(ordem.first, CategoriaItem.bebidas);
    expect(ordem[1], CategoriaItem.frios);
    expect(ordem.length, CategoriaItem.values.length);
  });

  test('deve_gravar_ordem_quando_definir', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(ordemCategoriasProvider.future);

    await container.read(ordemCategoriasProvider.notifier).definir([
      CategoriaItem.limpeza,
      ...CategoriaItem.values.where((c) => c != CategoriaItem.limpeza),
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('ordem_categorias'),
      startsWith(CategoriaItem.limpeza.valor),
    );
  });

  test('deve_voltar_ao_enum_quando_restaurar_padrao', () async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias': CategoriaItem.bebidas.valor,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(ordemCategoriasProvider.future);

    await container.read(ordemCategoriasProvider.notifier).restaurarPadrao();

    expect(container.read(ordemCategoriasProvider).value, CategoriaItem.values);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ordem_categorias'), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/ordem_categorias_test.dart test/features/listas/ordem_categorias_provider_test.dart`
Expected: FAIL na compilação — `Target of URI doesn't exist: .../ordem_categorias.dart`.

- [ ] **Step 3: Implementar**

`lib/features/listas/domain/ordem_categorias.dart`:

```dart
import 'categoria.dart';

/// Ordem completa: começa pela ordem salva (ignorando duplicatas) e anexa as
/// categorias ausentes na ordem do enum — uma categoria nova nunca some da UI.
List<CategoriaItem> normalizarOrdem(List<CategoriaItem> salva) {
  final vistas = <CategoriaItem>{};
  final ordem = <CategoriaItem>[];
  for (final c in salva) {
    if (vistas.add(c)) ordem.add(c);
  }
  for (final c in CategoriaItem.values) {
    if (vistas.add(c)) ordem.add(c);
  }
  return ordem;
}

/// CSV de `CategoriaItem.valor`.
String serializarOrdem(List<CategoriaItem> ordem) =>
    normalizarOrdem(ordem).map((c) => c.valor).join(',');

/// Desserializa o CSV; desconhecidas são ignoradas e a ordem é normalizada.
/// `null`/vazio → ordem padrão do enum.
List<CategoriaItem> desserializarOrdem(String? csv) {
  if (csv == null || csv.trim().isEmpty) return List.of(CategoriaItem.values);
  final porValor = {for (final c in CategoriaItem.values) c.valor: c};
  final lida = <CategoriaItem>[];
  for (final parte in csv.split(',')) {
    final c = porValor[parte.trim()];
    if (c != null) lida.add(c);
  }
  return normalizarOrdem(lida);
}

/// Move `oldIndex` para `newIndex` (mesma semântica do `onReorder` do
/// `ReorderableListView`: ao descer, o índice final é decrementado).
List<T> moverItem<T>(List<T> lista, int oldIndex, int newIndex) {
  final copia = [...lista];
  var destino = newIndex;
  if (destino > oldIndex) destino -= 1;
  final item = copia.removeAt(oldIndex);
  copia.insert(destino, item);
  return copia;
}
```

`lib/features/listas/providers/ordem_categorias_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/categoria.dart';
import '../domain/ordem_categorias.dart';

const _chave = 'ordem_categorias';

/// Ordem pessoal das categorias (RF-24), local no dispositivo — espelha o
/// `temaModoProvider` (doc 15). Sem rede/Drift.
class OrdemCategoriasNotifier extends AsyncNotifier<List<CategoriaItem>> {
  @override
  Future<List<CategoriaItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return desserializarOrdem(prefs.getString(_chave));
  }

  Future<void> definir(List<CategoriaItem> ordem) async {
    final normalizada = normalizarOrdem(ordem);
    state = AsyncData(normalizada);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, serializarOrdem(normalizada));
  }

  Future<void> restaurarPadrao() async {
    state = AsyncData(List.of(CategoriaItem.values));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
  }
}

final ordemCategoriasProvider =
    AsyncNotifierProvider<OrdemCategoriasNotifier, List<CategoriaItem>>(
      OrdemCategoriasNotifier.new,
    );
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/ordem_categorias_test.dart test/features/listas/ordem_categorias_provider_test.dart`
Expected: PASS (8 testes).

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/features/listas/domain/ordem_categorias.dart lib/features/listas/providers/ordem_categorias_provider.dart test/features/listas/ordem_categorias_test.dart test/features/listas/ordem_categorias_provider_test.dart
git commit -m "F28-T01: ordem das categorias (dominio e provider local) (RF-24)"
```

---

### Task 2: UI — tela de ordenação, Configurações e agrupamento na lista

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/router.dart` (rota `/categorias`)
- Create: `lib/features/listas/ui/tela_ordenar_categorias.dart`
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (item)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (agrupamento)
- Modify: `test/features/configuracoes/configuracoes_screen_test.dart`
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `ordemCategoriasProvider`, `moverItem`, `CategoriaItem`; `AppDialog`; `context.push`.
- Produces: rota `/categorias`; `TelaOrdenarCategorias`; strings novas.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart` (perto de `configuracoes`/`aparencia`):

```dart
  static const ordenarCategorias = 'Ordenar categorias';
  static const ordenarCategoriasDica =
      'Arraste para a ordem dos corredores do seu mercado.';
  static const restaurarPadrao = 'Restaurar padrão';
  static const restaurarPadraoTitulo = 'Restaurar a ordem padrão?';
  static const restaurarPadraoMensagem =
      'As categorias voltam à ordem original.';
```

- [ ] **Step 2: Escrever os testes que falham**

Em `test/features/configuracoes/configuracoes_screen_test.dart`, acrescentar (reuse `abrirComRouter`, adicionando uma rota `/categorias` stub ao `GoRouter` do helper ou um teste novo):

```dart
  testWidgets('deve_abrir_ordenar_categorias_quando_toca', (tester) async {
    await abrirComRouterComCategorias(tester);
    await tester.tap(find.text(AppStrings.ordenarCategorias));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.restaurarPadrao), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
```

> Adicione um helper `abrirComRouterComCategorias` no arquivo que inclua a rota `/categorias` → `TelaOrdenarCategorias`, seguindo o `abrirComRouter` existente. `SharedPreferences.setMockInitialValues({})` no `setUp`.

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar um teste de agrupamento custom (reuse o harness real; `SharedPreferences.setMockInitialValues` com a ordem custom antes de montar):

```dart
  testWidgets('deve_agrupar_na_ordem_custom_quando_lista', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias': '${CategoriaItem.bebidas.valor},'
          '${CategoriaItem.mercearia.valor},'
          '${CategoriaItem.hortifruti.valor}',
    });
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Banana',
      categoria: CategoriaItem.hortifruti,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Suco',
      categoria: CategoriaItem.bebidas,
    );
    // abrir a tela na lista `lista.id` (harness com o id)

    final dyBebidas = tester.getTopLeft(
      find.text(CategoriaItem.bebidas.rotulo),
    ).dy;
    final dyMercearia = tester.getTopLeft(
      find.text(CategoriaItem.mercearia.rotulo),
    ).dy;
    final dyHortifruti = tester.getTopLeft(
      find.text(CategoriaItem.hortifruti.rotulo),
    ).dy;
    expect(dyBebidas, lessThan(dyMercearia));
    expect(dyMercearia, lessThan(dyHortifruti));
    await fechar(tester);
  });
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL — a tela/item/agrupamento ainda não existem.

- [ ] **Step 4: Implementar**

`lib/features/listas/ui/tela_ordenar_categorias.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/categoria.dart';
import '../domain/ordem_categorias.dart';
import '../providers/ordem_categorias_provider.dart';

/// Tela "Ordenar categorias" (RF-24): arrastar-e-soltar a ordem dos grupos.
class TelaOrdenarCategorias extends ConsumerWidget {
  const TelaOrdenarCategorias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordem =
        ref.watch(ordemCategoriasProvider).value ?? CategoriaItem.values;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ordenarCategorias),
        actions: [
          TextButton(
            onPressed: () => _confirmarRestaurar(context, ref),
            child: const Text(AppStrings.restaurarPadrao),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(AppStrings.ordenarCategoriasDica),
          ),
          Expanded(
            child: ReorderableListView(
              children: [
                for (final c in ordem)
                  ListTile(
                    key: ValueKey(c.valor),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(c.rotulo),
                  ),
              ],
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(ordemCategoriasProvider.notifier)
                    .definir(moverItem(ordem, oldIndex, newIndex));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarRestaurar(BuildContext context, WidgetRef ref) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.restaurarPadraoTitulo,
      mensagem: AppStrings.restaurarPadraoMensagem,
      confirmar: AppStrings.restaurarPadrao,
    );
    if (confirmou) {
      await ref.read(ordemCategoriasProvider.notifier).restaurarPadrao();
    }
  }
}
```

Em `lib/router.dart`, adicionar após o `/mercado/:listaId`:

```dart
      GoRoute(
        path: '/categorias',
        builder: (context, state) => const TelaOrdenarCategorias(),
      ),
```

(import de `TelaOrdenarCategorias`.)

Em `lib/features/configuracoes/ui/configuracoes_screen.dart`, após o `Padding` do `SeletorTema` (seção Aparência):

```dart
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text(AppStrings.ordenarCategorias),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categorias'),
          ),
```

Em `lib/features/listas/ui/tela_lista_screen.dart`, em `_ListaItens.build`, trocar a iteração:

```dart
        final ordemCategorias =
            ref.watch(ordemCategoriasProvider).value ?? CategoriaItem.values;
        for (final categoria in ordemCategorias) {
```

(import de `ordem_categorias_provider.dart`; `_ListaItens` já é `ConsumerWidget` com `ref`.)

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/router.dart lib/features/listas/ui/tela_ordenar_categorias.dart lib/features/configuracoes/ui/configuracoes_screen.dart lib/features/listas/ui/tela_lista_screen.dart test/features/configuracoes/configuracoes_screen_test.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F28-T02: tela de ordenar categorias e agrupamento na ordem custom (RF-24)"
```

---

### Task 3: Docs donos e fechamento da Fase 28

**Files:**
- Modify: `docs/01-banco-de-dados.md` (§3.2 — enum ordem é padrão)
- Modify: `docs/05-app-flutter.md` (§6 — Configurações e agrupamento)
- Modify: `docs/10-wireframes-telas.md` (§5 — item + wireframe da tela)
- Modify: `docs/12-prd.md` (RF-24 + rastreabilidade)
- Modify: `docs/14-tarefas.md` (Fase 28 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A4 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: Docs 01, 05 e 10**
  - `01 §3.2`: ajustar a frase "a ordem do enum define a ordem dos grupos na UI" → a ordem do enum é o **padrão**; o usuário pode reordenar (RF-24).
  - `05 §6`: Configurações ganha "Ordenar categorias" (arrastar-e-soltar + restaurar padrão, local); no §6.3, o agrupamento segue a **ordem salva** (fallback: enum); o dropdown do editor mantém a ordem do enum.
  - `10 §5`: item "Ordenar categorias" em Configurações + wireframe da tela (lista arrastável + "Restaurar padrão").

- [ ] **Step 2: Doc 12 e 16**
  - `12 §2`: `RF-24 | Ordem pessoal das categorias (global, local por dispositivo) | 05 §6 + 10 §5 | F28 | ...`; §6: rastreabilidade `RF-24 | US-07 | F28 | F28-T01, F28-T02 | Unit ordem + provider + widgets`.
  - `16`: Onda A linha A4 → `concluído (F28-T01…T03)`.

- [ ] **Step 3: Doc 14 (Fase 28 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 28 com F28-T01…T03 `[x]` e CPs.
  - Na tabela, após `| F27 Itens de outra lista | 3 | 3 |`, adicionar `| F28 Ordem das categorias | 3 | 3 |` e atualizar o total para `| **Total** | **158** | **156** |`.

- [ ] **Step 4: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/01-banco-de-dados.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F28-T03: docs donos e fechamento da Fase 28 (RF-24)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 domínio → Task 1; §4 provider → Task 1; §5 UI → Task 2; §6 testes → Tasks 1–2; §7 docs → Task 3.
- **Placeholders:** nenhum "TBD"; todo o código de produção está completo. O teste de agrupamento da Task 2 reusa o harness real do arquivo (o implementador parametriza o `listaId`).
- **Nota sobre o teste de drag:** a spec §6 cita `deve_persistir_quando_reordena`; a matemática do reorder é coberta por `moverItem` (unit) e a persistência por `definir` (provider) — o arrasto do `ReorderableListView` em teste é frágil e não é exigido para cobrir o comportamento.
- **Consistência de tipos:** `normalizarOrdem`/`serializarOrdem`/`desserializarOrdem`/`moverItem`; `ordemCategoriasProvider` (`AsyncNotifierProvider<OrdemCategoriasNotifier, List<CategoriaItem>>`); rota `/categorias`; progresso 158/156 — idênticos entre tarefas.
- **YAGNI:** sem schema, sem sync, sem mudar o enum nem o dropdown do editor.
