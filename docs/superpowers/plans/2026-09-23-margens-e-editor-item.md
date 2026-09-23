# Editor de item em sheet e correções de margem (Fase 40) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir o editor de item (vira bottom sheet, com campos em blocos, sem o problema do teclado) e as lacunas reais de margem (`IndicadorSync` a 8dp, literais verticais, token sem uso) — **sem mudança de comportamento**.

**Architecture:** Duas mudanças independentes. (1) O `_DialogoEditarItem` (um `AlertDialog`) passa a ser aberto por `AppSheet.mostrar` (o padrão que os outros modais do app já usam: `isScrollControlled` + `viewInsets.bottom` + `showDragHandle`), com o conteúdo em blocos dentro de um `SingleChildScrollView`. (2) O `IndicadorSync` iguala o padding dos banners ao do `_LinhaStatus` (16dp) e o único wrapper externo perde o horizontal para não virar padding duplo. A auditoria mostrou que o app **já** está ≥16dp das bordas em quase tudo, então **não** há varredura de wrapper.

**Tech Stack:** Flutter, Riverpod, `AppSheet`/`AppBanner`/`AppCampoTexto`/`AppDropdown`/`AppBotao` (design system), tokens `AppSpacing`; testes `flutter test`.

**Spec:** [docs/superpowers/specs/2026-09-23-margens-e-editor-item-design.md](docs/superpowers/specs/2026-09-23-margens-e-editor-item-design.md)

## Global Constraints

- **Sem mudança de comportamento** além da apresentação do editor: mesmos campos, mesmas `AppStrings`, mesmas validações e a mesma chamada `editarItem(...)`.
- **Não** criar wrapper de página (`AppPagina`) nem migrar telas: o app já está a 16dp das bordas (decisão da spec §8.1).
- Os **três** usos do `IndicadorSync` devem terminar em **16dp** (sem padding duplo).
- Nada em `supabase/`; sem novas dependências; sem segredos.
- Comentários só onde explicam decisão não óbvia.
- `dart format .` + `flutter analyze` limpos e `flutter test` verde antes de cada commit.
- Testes `deve_<resultado>_quando_<condição>`; commits em pt-BR referenciando `F40-T0x` e `(RNF-06)`.

---

## File Structure

**Modificados:**
- `lib/features/sync/ui/indicador_sync.dart` — padding dos banners `Offline`/`ErroSync` 8dp → 16dp.
- `lib/features/listas/ui/painel_listas.dart` — wrapper do `IndicadorSync` só com topo; literais `4` e `88` tokenizados.
- `lib/core/theme/tokens/app_spacing.dart` — remove `horizontalCompacto`.
- `lib/features/listas/ui/tela_lista_screen.dart` — `_DialogoEditarItem` → `_SheetEditarItem` (via `AppSheet.mostrar`), layout em blocos.
- `test/features/listas/tela_lista_screen_test.dart` e `test/features/listas/editar_item_historico_test.dart` — seletores do editor.
- `docs/15-design-system.md`, `docs/10-wireframes-telas.md`, `docs/05-app-flutter.md`, `docs/14-tarefas.md`.

**Criados:**
- `test/features/sync/indicador_sync_margem_test.dart` — margem dos estados do indicador.

---

## Task 1: Planejamento — Fase 40 em `docs/14-tarefas.md`

**Files:**
- Modify: `docs/14-tarefas.md` (nova Fase 40 após o bloco da F39; tabela de progresso)
- Modify: `docs/12-prd.md` (evidência do RNF-06, se necessário)

**Interfaces:**
- Consumes: nada.
- Produces: IDs `F40-T01…T05` usados nos commits.

- [ ] **Step 1: Inserir a Fase 40 antes de `## Progresso por fase`**

```markdown
## Fase 40 — Editor de item em sheet e margens (RNF-06)

Spec: [superpowers/specs/2026-09-23-margens-e-editor-item-design.md](superpowers/specs/2026-09-23-margens-e-editor-item-design.md) · Plano: [superpowers/plans/2026-09-23-margens-e-editor-item.md](superpowers/plans/2026-09-23-margens-e-editor-item.md) · Requisito: RNF-06 (área de respiro / usabilidade). · Docs donos: 15, 10, 05.

- [ ] **F40-T01** — Planejamento: Fase 40 e RNF-06
  Dep: — · Docs: [14](14-tarefas.md), [12](12-prd.md)
  CP: Fase 40 no 14 com as 5 tarefas e a linha de progresso (208/203); RNF-06 do 12 aponta a área de respiro do indicador de sync.
- [ ] **F40-T02** — Margens: `IndicadorSync` a 16dp, literais verticais e token sem uso
  Dep: F40-T01 · Docs: [15 §1](15-design-system.md)
  CP: banners `Offline`/`ErroSync` em `fromLTRB(lg, sm, lg, 0)`; wrapper do painel em `only(top: sm)`; `painel_listas.dart:264`/`:185` nos tokens; `horizontalCompacto` removido do `app_spacing.dart` e do 15 §1; teste de margem verde (3 usos em 16dp).
- [ ] **F40-T03** — Editor de item vira bottom sheet com campos em blocos
  Dep: F40-T02 · Docs: [05 §6.3](05-app-flutter.md), [10 §3](10-wireframes-telas.md)
  CP: `_abrirDialogoEditar` → `AppSheet.mostrar`; `_SheetEditarItem` em `SingleChildScrollView > Column(min, stretch)` com Nome (full), `[Quantidade −/+ | Unidade]`, `[Categoria | Preço]`, histórico e rodapé `Remover/Cancelar/Salvar`; validações e `editarItem(...)` inalterados; testes de tela do editor ajustados e verdes.
- [ ] **F40-T04** — Teste de teclado e docs donos
  Dep: F40-T03 · Docs: [15 §1](15-design-system.md), [10](10-wireframes-telas.md), [05 §6.3](05-app-flutter.md)
  CP: teste com `viewInsets` simulado (sheet sem overflow e com os campos alcançáveis); 10 §3 e 05 §6.3 descrevem o editor como bottom sheet; 15 §1 com a regra de margem do `IndicadorSync`.
- [ ] **F40-T05** — Fechamento: verificação e progresso
  Dep: F40-T04 · Docs: [14](14-tarefas.md)
  CP: F40-T01…T05 marcadas e tabela (208/208); `dart format`/`flutter analyze`/`flutter test` verdes; nada em `supabase/`.
```

- [ ] **Step 2: Tabela de progresso**

Inserir após a linha da F39 e ajustar o total:

```markdown
| F40 Sheet do item e margens | 5 | 0 |
```
```markdown
| **Total** | **208** | **203** |
```

- [ ] **Step 3: Commit**

```bash
git add docs/14-tarefas.md docs/12-prd.md
git commit -m "F40-T01: Fase 40 e rastreabilidade no RNF-06 (RNF-06)"
```

---

## Task 2: Margens — `IndicadorSync`, literais e token sem uso

**Files:**
- Modify: `lib/features/sync/ui/indicador_sync.dart:43-62`
- Modify: `lib/features/listas/ui/painel_listas.dart:137-145`, `:185`, `:264`
- Modify: `lib/core/theme/tokens/app_spacing.dart:15-17`
- Test: `test/features/sync/indicador_sync_margem_test.dart` (novo)

**Interfaces:**
- Consumes: `IndicadorSync` (ConsumerWidget), `AppSpacing`.
- Produces: nenhuma API nova; `AppSpacing.horizontalCompacto` deixa de existir (**nenhum consumidor** — confirmado).

- [ ] **Step 1: Escrever o teste que falha (margem dos três estados)**

`test/features/sync/indicador_sync_margem_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/features/sync/ui/indicador_sync.dart';

Widget _app(SyncStatus status) => ProviderScope(
  overrides: [syncStatusProvider.overrideWith((ref) => Stream.value(status))],
  child: const MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: IndicadorSync())),
  ),
);

EdgeInsets _paddingDe(WidgetTester tester) {
  final padding = tester
      .widgetList<Padding>(find.byType(Padding))
      .map((p) => p.padding)
      .whereType<EdgeInsets>()
      .firstWhere((e) => e.top == AppSpacing.sm || e.top == AppSpacing.xs);
  return padding;
}

void main() {
  testWidgets('deve_usar_16dp_laterais_quando_offline', (tester) async {
    await tester.pumpWidget(_app(const Offline()));
    await tester.pump();
    final p = _paddingDe(tester);
    expect(p.left, AppSpacing.lg);
    expect(p.right, AppSpacing.lg);
  });

  testWidgets('deve_usar_16dp_laterais_quando_erro', (tester) async {
    await tester.pumpWidget(_app(const ErroSync()));
    await tester.pump();
    final p = _paddingDe(tester);
    expect(p.left, AppSpacing.lg);
    expect(p.right, AppSpacing.lg);
  });
}
```

> Ajuste o helper `_paddingDe` se o finder casar com mais de um `Padding` do tema: use
> `find.descendant(of: find.byType(IndicadorSync), matching: find.byType(Padding))`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/sync/indicador_sync_margem_test.dart`
Expected: FAIL — hoje `left == 8` (`AppSpacing.sm`).

- [ ] **Step 3: Corrigir os banners em `indicador_sync.dart`**

```dart
      Offline() => const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        child: AppBanner(
          tipo: AppBannerTipo.offline,
          mensagem: AppStrings.syncSemConexao,
        ),
      ),
      ErroSync() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        child: AppBanner(
          tipo: AppBannerTipo.erro,
          mensagem: AppStrings.syncErro,
          acao: AppBotao(
            rotulo: AppStrings.tentarNovamente,
            variante: AppBotaoVariante.texto,
            expandido: false,
            onPressed: () => ref.read(syncEngineProvider).reiniciarTentativas(),
          ),
        ),
      ),
```

- [ ] **Step 4: Rodar o teste de margem**

Run: `flutter test test/features/sync/indicador_sync_margem_test.dart`
Expected: PASS.

- [ ] **Step 5: Remover o horizontal do wrapper no painel (evitar 32dp)**

Em `painel_listas.dart:137-145`, trocar o wrapper por:

```dart
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: IndicadorSync(),
          ),
```

- [ ] **Step 6: Tokenizar os literais verticais**

`painel_listas.dart:264`:

```dart
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
```

`painel_listas.dart:181-186` — trocar o `88` por tokens (mantém 88 = 48 + 32 + 8):

```dart
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxxl + AppSpacing.xxl + AppSpacing.sm,
                  ),
```

- [ ] **Step 7: Remover o token sem uso**

Apagar de `lib/core/theme/tokens/app_spacing.dart`:

```dart
  static const EdgeInsets horizontalCompacto = EdgeInsets.symmetric(
    horizontal: md,
  );
```

- [ ] **Step 8: Verificar uso e suíte**

Run: `grep -rn "horizontalCompacto" lib test` → deve ser vazio.
Run: `dart format . && flutter analyze && flutter test`
Expected: `No issues found` e PASS.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "F40-T02: IndicadorSync a 16dp, literais tokenizados e token sem uso removido (RNF-06)"
```

---

## Task 3: Editor de item vira bottom sheet

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` — `:915`, `:971` (chamadas), `:994-1003` (abertura), `:1146-1401` (widget)
- Modify: `test/features/listas/tela_lista_screen_test.dart`, `test/features/listas/editar_item_historico_test.dart`

**Interfaces:**
- Consumes: `AppSheet.mostrar<T>(context, {required Widget child, bool isScrollControlled = true})` (`lib/core/widgets/app_sheet.dart:7-29`); `AppCampoTexto`, `AppDropdown<T>`, `AppBotao`, `parseQuantidade`, `formatarQuantidade`, `parsePrecoParaCentavos`, `historicoPrecoProvider`.
- Produces: `_SheetEditarItem` (StatefulWidget `ConsumerStatefulWidget`), aberto por `_abrirSheetEditar(BuildContext, WidgetRef)`. **Mesmos campos e mesmas validações** de `_DialogoEditarItem`.

- [ ] **Step 1: Trocar a abertura (`:994-1003`)**

```dart
  Future<void> _abrirSheetEditar(BuildContext context, WidgetRef ref) {
    return AppSheet.mostrar<void>(
      context,
      child: _SheetEditarItem(
        item: item,
        listaId: listaId,
        onRemover: () => _removerComUndo(context, ref),
      ),
    );
  }
```

Atualizar as duas chamadas (`:915` no toque da linha, `:971` no swipe) para `_abrirSheetEditar(...)`. Garantir o import de `../../../core/widgets/app_sheet.dart` (o analisador aponta se faltar).

- [ ] **Step 2: Renomear o widget e reescrever o `build`**

Renomear `_DialogoEditarItem` → `_SheetEditarItem` e `_DialogoEditarItemState` → `_SheetEditarItemState` (mantendo controllers, `_linhaHistoricoPreco`, `_salvar` e os getters como estão). Substituir o `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final hist = ref.watch(historicoPrecoProvider(widget.item.nome)).value;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.editarItem,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCampoTexto(
            controller: _nome,
            label: AppStrings.nomeDoItem,
            erro: _erroNome,
            onChanged: (_) {
              if (_erroNome != null) setState(() => _erroNome = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      tooltip: AppStrings.diminuir,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final atual = _quantidadeLida() ?? 1;
                        if (atual > 1) {
                          _quantidade.text = formatarQuantidade(atual - 1);
                          if (_erroQuantidade != null) {
                            setState(() => _erroQuantidade = null);
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: AppCampoTexto(
                        controller: _quantidade,
                        label: AppStrings.quantidade,
                        erro: _erroQuantidade,
                        teclado: TextInputType.text,
                        onChanged: (_) {
                          if (_erroQuantidade != null) {
                            setState(() => _erroQuantidade = null);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.aumentar,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final atual = _quantidadeLida() ?? 1;
                        _quantidade.text = formatarQuantidade(atual + 1);
                        if (_erroQuantidade != null) {
                          setState(() => _erroQuantidade = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppDropdown<Unidade>(
                  label: AppStrings.unidade,
                  valor: _unidade,
                  itens: [
                    for (final u in Unidade.values)
                      DropdownMenuItem(value: u, child: Text(u.valor)),
                  ],
                  onChanged: (u) {
                    if (u != null) setState(() => _unidade = u);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdown<CategoriaItem>(
                  label: AppStrings.categoria,
                  valor: _categoria,
                  itens: [
                    for (final c in CategoriaItem.values)
                      DropdownMenuItem(value: c, child: Text(c.rotulo)),
                  ],
                  onChanged: (c) {
                    if (c != null) setState(() => _categoria = c);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCampoTexto(
                  controller: _preco,
                  label: AppStrings.preco,
                  erro: _erroPreco,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _erroPreco = null),
                ),
              ),
            ],
          ),
          if (hist != null) _linhaHistoricoPreco(hist),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (widget.onRemover != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(widget.onRemover!());
                  },
                  child: Text(
                    AppStrings.removerItem,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.cancelar),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBotao(
                rotulo: AppStrings.salvar,
                expandido: false,
                onPressed: _salvar,
              ),
            ],
          ),
        ],
      ),
    );
  }
```

Remover o comentário órfão da categoria se ele ficar deslocado (mantenha só os que explicam decisão).

- [ ] **Step 3: Rodar a suíte das listas e corrigir os seletores dos testes**

Run: `flutter test test/features/listas`
Expected: as falhas devem ser só de seletor. Nos testes que hoje buscam `AlertDialog` **para o editor**
(`tela_lista_screen_test.dart:2080`, `:2219`), trocar por um seletor do sheet — ex.:
`find.byType(BottomSheet)` — e manter as asserções de conteúdo/`AppStrings.editarItem`. **Não** alterar
`AlertDialog` de outros diálogos (exclusão de conta, orçamento, membros).

Run: `flutter test test/features/listas`
Expected: PASS.

- [ ] **Step 4: Format, analyze e suíte completa**

Run: `dart format . && flutter analyze && flutter test`
Expected: `No issues found` e PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "F40-T03: editor de item vira bottom sheet com campos em blocos (RNF-06)"
```

---

## Task 4: Teste de teclado e docs donos

**Files:**
- Test: `test/features/listas/tela_lista_screen_test.dart` (novo caso)
- Modify: `docs/15-design-system.md` (§1 e onde citar componentes), `docs/10-wireframes-telas.md` (§3, wireframe do editor), `docs/05-app-flutter.md:206`

**Interfaces:**
- Consumes: o `_SheetEditarItem` da Task 3.
- Produces: cobertura do comportamento com o teclado e docs coerentes.

- [ ] **Step 1: Escrever o teste do teclado (falharia se o sheet não tratasse o inset)**

Adicionar em `test/features/listas/tela_lista_screen_test.dart` (junto aos testes do editor):

```dart
  testWidgets('deve_manter_campos_e_salvar_quando_teclado_abre', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 700);
    addTearDown(tester.view.resetViewInsets);

    // ... setup padrão da tela (mesmo harness dos outros testes do editor) ...
    // abre o editor tocando no item
    // rola o sheet até o botão Salvar e toca
    await tester.ensureVisible(find.text(AppStrings.salvar));
    await tester.tap(find.text(AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // sem overflow/erro de layout
  });
```

- [ ] **Step 2: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (sem exceção de overflow). Se falhar por overflow, o sheet precisa de
`mainAxisSize.min` + scroll (já previsto) — não afrouxe o teste.

- [ ] **Step 3: Atualizar `docs/05-app-flutter.md:206`**

Trocar "Abre o editor (mesmo diálogo do swipe)" por "Abre o editor em **bottom sheet** (mesmo do swipe)".

- [ ] **Step 4: Atualizar `docs/10-wireframes-telas.md` §3**

No wireframe "Editar item" (linha ~251), trocar o desenho/descrição de diálogo centralizado por
**bottom sheet** com os blocos: Nome (full), `[Quantidade −/+ | Unidade]`, `[Categoria | Preço]`,
histórico e rodapé `Remover / Cancelar / Salvar`.

- [ ] **Step 5: Atualizar `docs/15-design-system.md` §1**

- Confirmar que a linha de `horizontalCompacto` **não** aparece mais (removida na Task 2).
- Acrescentar a regra: "Todo conteúdo fica a **16dp** (`AppSpacing.lg`) das bordas; `ListTile` já traz
  esse valor por padrão. O `IndicadorSync` traz a própria margem horizontal (16dp) — não envolvê-lo em
  outro `Padding` horizontal."

- [ ] **Step 6: Verificar e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add test docs
git commit -m "F40-T04: teste de teclado e docs donos do sheet do item (RNF-06)"
```

---

## Task 5: Fechamento — verificação e progresso

**Files:**
- Modify: `docs/14-tarefas.md`

**Interfaces:**
- Consumes: tudo das Tasks 1-4.
- Produces: fase concluída e verificada.

- [ ] **Step 1: Verificação completa**

Run: `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`
Expected: formatação estável; `No issues found`; suíte verde.

- [ ] **Step 2: Confirmar que `supabase/` não mudou**

Run: `git diff --stat 9f040c3..HEAD -- supabase`
Expected: vazio.

- [ ] **Step 3: Marcar as tarefas e o progresso**

Trocar `- [ ] **F40-T0x**` por `- [x]`; na tabela, `| F40 Sheet do item e margens | 5 | 5 |` e
`| **Total** | **208** | **208** |`.

- [ ] **Step 4: Commit e push**

```bash
git add docs/14-tarefas.md
git commit -m "F40-T05: fase 40 concluida e verificada (RNF-06)"
git push
```

- [ ] **Step 5: Confirmar o CI do push**

Run: `gh run list --limit 2`
Expected: jobs `flutter`/`desktop` verdes. O job `supabase` pode continuar falhando por rate-limit do
`ghcr.io` (externo, alheio a esta fase) — registrar e não tratar como bloqueio.

---

## Self-Review

**Cobertura da spec:**
- §1.1 e §4 (editor → sheet, campos em blocos) → Task 3. ✔
- §1.2 e §3 (margens: `IndicadorSync` 16dp, wrapper do painel, literais, token removido) → Task 2. ✔
- §5 (testes: sheet, teclado, margem) → Tasks 2 e 4. ✔
- §6 (docs 15/10/05) → Task 4. ✔
- §2 "fora" (sem `AppPagina`, sem novos campos, sem mexer em AppBar/FAB/nav) → Global Constraints. ✔
- §8 decisões → registradas na spec e refletidas nas tasks. ✔

**Placeholders:** nenhum "TBD"; todo passo de código traz o código. Nos dois testes que dependem do
harness existente (teclado e margem) o passo diz onde/como e proíbe afrouxar a asserção.

**Consistência de tipos:** `_abrirSheetEditar(BuildContext, WidgetRef) → Future<void>` (Task 3) chamado
nos dois pontos de abertura; `_SheetEditarItem({required Item item, required String listaId, Future<void> Function()? onRemover})`; `AppSheet.mostrar<void>` devolve `Future<void?>` compatível; `AppSpacing.xxxl/xxl/sm` usados na Task 2 existem (`app_spacing.dart:5-11`); `horizontalCompacto` removido sem consumidores (confirmado na Task 2 Step 8).
