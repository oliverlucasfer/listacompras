# Revisão UX heurística — feedback do add e "Desmarcar todos" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dar feedback ao adicionar item novo e proteger "Desmarcar todos" com confirmação + undo, corrigindo dois atritos apontados pela avaliação heurística.

**Architecture:** mudança bounded na tela da lista (Flutter + Riverpod + Drift), reusando componentes do design system (`AppDialog.confirmarDestrutivo`, `mostrarSnackBar`) e o contrato atual do repositório (`desmarcarTodos`, `editarItem`). Strings novas nos ARB pt/en/es.

**Tech Stack:** Flutter, Riverpod, Drift, gen_l10n (ARB), flutter_test.

**Spec:** [docs/superpowers/specs/2026-10-09-revisao-ux-heuristica-design.md](../specs/2026-10-09-revisao-ux-heuristica-design.md)

## Global Constraints

- **Offline-first local:** toda escrita vai ao Drift; nenhum dado de rede. Não alterar contratos de repositório.
- **Sem componente `App*` novo:** reusar `AppDialog.confirmarDestrutivo` e `mostrarSnackBar`.
- **i18n (RF-39):** toda string nova entra nos **3** ARB (`app_pt.arb` template, `app_en.arb`, `app_es.arb`) e é regenerada com `flutter gen-l10n` (arquivos `lib/l10n/app_localizations*.dart` são versionados).
- **Doc dono atualizado no mesmo PR:** `05 §6.3`, `10 §3.1`, `12` (RF-04), `13 §4`, `14` (Fase 64), `16`.
- **Bump de versão:** `pubspec.yaml` `version: 1.8.3+24` → `1.8.4+25` **com paridade** em `web/version.json` (`version` `1.8.4`, `build_number` `25`); o guard `test/core/config/version_json_test.dart` exige igualdade.
- **Copy pt-BR**; commits concisos em pt-BR citando `F64-Txx`.
- **Definition of Done de cada tarefa:** `dart format .` + `flutter analyze` + `flutter test` verdes.
- **Nomes de teste:** `deve_<resultado>_quando_<condição>`.

---

## File Structure

- `lib/l10n/app_pt.arb` · `app_en.arb` · `app_es.arb` — strings novas (fonte da verdade de copy).
- `lib/l10n/app_localizations*.dart` — **gerados** por `flutter gen-l10n` (não editar à mão).
- `lib/features/listas/ui/campo_adicionar_item.dart` — feedback do item novo (A1).
- `lib/features/listas/ui/tela_lista_screen.dart` — confirmação/undo do "Desmarcar todos" + item de menu desabilitado (A2).
- `test/features/listas/tela_lista_screen_test.dart` — testes de widget (A1 e A2).
- `pubspec.yaml` · `web/version.json` — bump.
- `docs/05-app-flutter.md` · `docs/10-wireframes-telas.md` · `docs/12-prd.md` · `docs/13-premodelo-tecnico.md` · `docs/14-tarefas.md` · `docs/16-roadmap-pos-mvp.md` — governança.

---

## Task 1: A1 — Feedback do item novo (F64-T01)

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Regenerate: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_es.dart`, `app_localizations_pt.dart`
- Modify: `lib/features/listas/ui/campo_adicionar_item.dart:135-142`
- Test: `test/features/listas/tela_lista_screen_test.dart`
- Docs: `docs/05-app-flutter.md` (§6.3), `docs/10-wireframes-telas.md` (§3.1)

**Interfaces:**
- Consumes: `context.l10n.itemAdicionado` (novo getter), `mostrarSnackBar(BuildContext, String)`.
- Produces: nada consumido por outras tarefas.

- [ ] **Step 1: Adicionar a string nos 3 ARB**

Em `lib/l10n/app_pt.arb`, logo após a linha 83 (`"itemAtualizado": "Item atualizado.",`):
```json
  "itemAdicionado": "Item adicionado.",
```
Em `lib/l10n/app_en.arb` (após `"itemAtualizado": "Item updated.",`):
```json
  "itemAdicionado": "Item added.",
```
Em `lib/l10n/app_es.arb` (após `"itemAtualizado": "Artículo actualizado.",`):
```json
  "itemAdicionado": "Artículo añadido.",
```

- [ ] **Step 2: Regenerar as localizações**

Run: `flutter gen-l10n`
Expected: `app_localizations*.dart` regenerados; o getter `String get itemAdicionado;` aparece em `app_localizations.dart`.

- [ ] **Step 3: Escrever o teste que falha**

Em `test/features/listas/tela_lista_screen_test.dart`, logo após o teste `deve_adicionar_item_quando_enter_no_campo` (termina na linha ~295), adicionar:

```dart
  testWidgets('deve_confirmar_quando_adiciona_item_novo', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Item adicionado.'), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 4: Rodar o teste e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_confirmar_quando_adiciona_item_novo`
Expected: FAIL — `find.text('Item adicionado.')` não encontra nada.

- [ ] **Step 5: Implementar o feedback mínimo**

Em `lib/features/listas/ui/campo_adicionar_item.dart`, alterar o `switch (resultado)` (linhas 135-142) para tratar `adicionado`:

```dart
      switch (resultado) {
        case ResultadoDedup.somado:
          mostrarSnackBar(context, '$nome ${context.l10n.itemDuplicadoSomado}');
        case ResultadoDedup.substituido:
          mostrarSnackBar(context, '$nome: ${context.l10n.itemAtualizado}');
        case ResultadoDedup.adicionado:
          mostrarSnackBar(context, context.l10n.itemAdicionado);
      }
```

- [ ] **Step 6: Rodar os testes e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_confirmar_quando_adiciona_item_novo`
Expected: PASS.

- [ ] **Step 7: Atualizar os docs donos**

Em `docs/05-app-flutter.md` §6.3, na linha do campo **"Campo \"Adicionar item\""** (linha 230), acrescentar ao fim:
` Ao salvar, cada item **novo** confirma com um SnackBar curto (`itemAdicionado`); duplicado segue com os avisos de soma/atualização (RF-10).`

Em `docs/10-wireframes-telas.md` §3.1, no bloco ASCII da linha do campo "Adicionar item" (após a linha 143 `reconhece "1kg de banana"...`), acrescentar a anotação:
```
│                            → item novo confirma com                   │
│                              SnackBar curto ("Item adicionado.")      │
```

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_es.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_es.dart lib/l10n/app_localizations_pt.dart lib/features/listas/ui/campo_adicionar_item.dart test/features/listas/tela_lista_screen_test.dart docs/05-app-flutter.md docs/10-wireframes-telas.md
git commit -m "feat(F64-T01): feedback ao adicionar item novo (RF-03)"
```

---

## Task 2: A2 — "Desmarcar todos" com confirmação e undo (F64-T02)

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (menu `⋮` e `case 'desmarcar'`)
- Test: `test/features/listas/tela_lista_screen_test.dart`
- Docs: `docs/05-app-flutter.md` (§6.3), `docs/10-wireframes-telas.md` (§3.1), `docs/12-prd.md` (RF-04)

**Interfaces:**
- Consumes: `AppDialog.confirmarDestrutivo(context, {titulo, mensagem, confirmar})` → `Future<bool>`; `mostrarSnackBar(context, msg, {rotuloAcao, onAcao})`; `itensRepositoryProvider` (`desmarcarTodos(String)`, `editarItem(String, {concluido})`); `itensDaListaProvider(String)` → `AsyncValue<List<Item>>`; `context.l10n.desmarcarTodos`/`desmarcarTodosMensagem`/`desmarcarTodosConfirmar`/`itensDesmarcados`/`desfazer`.
- Produces: nada consumido por outras tarefas.

- [ ] **Step 1: Adicionar as strings nos 3 ARB**

Na seção de ações em massa de cada ARB (junto a `limparConcluidos`/`limparConcluidosMensagem`, ~linhas 213-216).

`lib/l10n/app_pt.arb`:
```json
  "desmarcarTodosMensagem": "Os itens marcados voltarão a pendente.",
  "desmarcarTodosConfirmar": "Desmarcar",
  "itensDesmarcados": "Itens desmarcados.",
```
`lib/l10n/app_en.arb`:
```json
  "desmarcarTodosMensagem": "Marked items will be unmarked.",
  "desmarcarTodosConfirmar": "Unmark",
  "itensDesmarcados": "Items unmarked.",
```
`lib/l10n/app_es.arb`:
```json
  "desmarcarTodosMensagem": "Los artículos marcados volverán a pendiente.",
  "desmarcarTodosConfirmar": "Desmarcar",
  "itensDesmarcados": "Artículos desmarcados.",
```

- [ ] **Step 2: Regenerar as localizações**

Run: `flutter gen-l10n`
Expected: os 4 getters novos aparecem em `app_localizations.dart`.

- [ ] **Step 3: Atualizar o teste existente e escrever os testes que falham**

Em `test/features/listas/tela_lista_screen_test.dart`, **substituir** o corpo de `deve_desmarcar_todos_quando_menu` (linhas 804-823) por:

```dart
  testWidgets('deve_desmarcar_todos_quando_confirmar_dialogo', (tester) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Os itens marcados voltarão a pendente.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Desmarcar'));
    await tester.pumpAndSettle();

    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.text('Limpeza (1)'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);

    await fechar(tester);
  });
```

Logo depois, adicionar:

```dart
  testWidgets('deve_restaurar_marcados_quando_desfazer_desmarcar_todos', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desmarcar'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Itens desmarcados.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(find.text('Itens concluídos (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('nao_deve_desmarcar_quando_cancela_desmarcar_todos', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Itens concluídos (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_desabilitar_desmarcar_todos_quando_sem_concluidos', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Desmarcar todos'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);

    await fechar(tester);
  });
```

E, junto às classes fake no fim do arquivo (após `_RepoRestaurarFalha`, linha ~2185), adicionar:

```dart
class _RepoDesmarcarFalha extends ItensRepository {
  _RepoDesmarcarFalha(super.db);

  @override
  Future<void> desmarcarTodos(String listaId) async =>
      throw Exception('falha simulada');
}
```

E o teste de falha (junto aos demais testes):

```dart
  testWidgets('deve_mostrar_erro_quando_desmarcar_todos_falha', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    final arroz = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.itens.editarItem(arroz.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensRepositoryProvider.overrideWithValue(_RepoDesmarcarFalha(db)),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desmarcar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível concluir. Tente novamente.'),
      findsOneWidget,
    );

    await fechar(tester);
  });
```

- [ ] **Step 4: Rodar os testes e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_desmarcar_todos_quando_confirmar_dialogo`
Expected: FAIL — sem diálogo, o toque desmarca direto e a asserção da mensagem falha.

- [ ] **Step 5: Implementar (menu + método)**

Em `lib/features/listas/ui/tela_lista_screen.dart`:

**5a.** No `case 'desmarcar'` de `_acaoMenu` (linhas 130-137), trocar o bloco por:
```dart
      case 'desmarcar':
        await _desmarcarTodos(context, ref, idLista);
```

**5b.** Adicionar o método após `_confirmarExcluirLista` (por volta da linha 277):
```dart
  /// Confirma e desmarca todos os itens concluídos, oferecendo Desfazer
  /// (re-marca os mesmos ids) — RF-04, F64-T02.
  Future<void> _desmarcarTodos(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final concluidos =
        (ref.read(itensDaListaProvider(idLista)).value ?? const <Item>[])
            .where((i) => i.concluido)
            .toList();
    if (concluidos.isEmpty) return;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: context.l10n.desmarcarTodos,
      mensagem: context.l10n.desmarcarTodosMensagem,
      confirmar: context.l10n.desmarcarTodosConfirmar,
    );
    if (!confirmou) return;
    final repo = ref.read(itensRepositoryProvider);
    try {
      await repo.desmarcarTodos(idLista);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
      return;
    }
    if (!context.mounted) return;
    mostrarSnackBar(
      context,
      context.l10n.itensDesmarcados,
      rotuloAcao: context.l10n.desfazer,
      onAcao: () {
        unawaited(() async {
          try {
            for (final item in concluidos) {
              await repo.editarItem(item.id, concluido: true);
            }
          } catch (_) {
            if (context.mounted) {
              mostrarSnackBar(context, context.l10n.erroGenerico);
            }
          }
        }());
      },
    );
  }
```

**5c.** No `PopupMenuButton<String>` do menu `⋮`, no `PopupMenuItem` de `'desmarcar'` (linhas 369-372), adicionar `enabled`:
```dart
                    PopupMenuItem(
                      value: 'desmarcar',
                      enabled: itens.any((i) => i.concluido),
                      child: Text(context.l10n.desmarcarTodos),
                    ),
```

- [ ] **Step 6: Rodar os testes e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS em todos (inclui `deve_limpar_concluidos_*` e `deve_restaurar_concluidos_quando_desfazer_limpar`, que continuam verdes).

- [ ] **Step 7: Atualizar os docs donos**

Em `docs/05-app-flutter.md` §6.3:
- Linha do **"Menu (⋮)"** (238): manter a ordem; anotar que **"Desmarcar todos" fica desabilitado sem itens concluídos**.
- Linha **"Ações em massa"** (239): substituir por:
`| Ações em massa | "desmarcar todos" pede **confirmação** (com concluídos) e tem **undo** (SnackBar restaura o estado marcado dos mesmos ids); "desmarcar" devolve o item ao seu grupo; **limpar concluídos tem undo** (SnackBar 3s, restaura `id`/`ordem` originais — F14-T05) |`

Em `docs/10-wireframes-telas.md` §3.1, na anotação do menu (linhas 132-139):
```
│  ← Compras da Semana      [⋮]   │ ← [⋮]: desmarcar todos (confirma +
│                                 │    undo; desabilitado sem concluídos),
```
(substituir a primeira linha `← [⋮]: desmarcar todos, limpar` por estas duas.)

Em `docs/12-prd.md` linha do **RF-04** (linha 26), ajustar a coluna de descrição para:
`Item concluído move para seção dobrável; ações em massa (desmarcar todos com confirmação/undo; limpar concluídos)`

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_es.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_es.dart lib/l10n/app_localizations_pt.dart lib/features/listas/ui/tela_lista_screen.dart test/features/listas/tela_lista_screen_test.dart docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md
git commit -m "feat(F64-T02): desmarcar todos com confirmação e undo (RF-04)"
```

---

## Task 3: Governança, bump e fechamento (F64-T03)

**Files:**
- Modify: `pubspec.yaml`, `web/version.json`
- Modify: `docs/13-premodelo-tecnico.md`, `docs/14-tarefas.md`, `docs/16-roadmap-pos-mvp.md`

**Interfaces:**
- Consumes: nada.
- Produces: Fase 64 registrada; versão coerente.

- [ ] **Step 1: Bump de versão**

Em `pubspec.yaml` linha 19: `version: 1.8.3+24` → `version: 1.8.4+25`.
Em `web/version.json`: substituir a linha por:
```json
{"app_name":"Minhas Listas","version":"1.8.4","build_number":"25","package_name":"lista_compras"}
```

- [ ] **Step 2: Registrar a Fase 64 em `docs/14-tarefas.md`**

Após o bloco da Fase 63 (antes de `## Progresso por fase`, ~linha 1360), inserir:

```markdown
## Fase 64 — Revisão UX heurística: feedback e "Desmarcar todos" (RF-03, RF-04)

Spec: [superpowers/specs/2026-10-09-revisao-ux-heuristica-design.md](superpowers/specs/2026-10-09-revisao-ux-heuristica-design.md) · Plano: [superpowers/plans/2026-10-09-revisao-ux-heuristica.md](superpowers/plans/2026-10-09-revisao-ux-heuristica.md) · Requisito: RF-03 (feedback do add) e RF-04 (ações em massa) — dois atritos da avaliação heurística. · Docs donos: 05, 10, 12, 13, 14, 16.

- [ ] **F64-T01** — Feedback ao adicionar item novo
  Docs: [05 §6.3](05-app-flutter.md), [10 §3.1](10-wireframes-telas.md). Requisito: RF-03.
  CP: item novo pela entrada rápida/chips confirma com SnackBar curto (`itemAdicionado`); duplicado mantém os avisos de soma/atualização; ARB pt/en/es; testes de widget verdes.
- [ ] **F64-T02** — "Desmarcar todos" com confirmação e undo
  Dep: F64-T01 · Docs: [05 §6.3](05-app-flutter.md), [10 §3.1](10-wireframes-telas.md), [12](12-prd.md) (RF-04). Requisito: RF-04.
  CP: item de menu desabilitado sem concluídos; com concluídos, `AppDialog.confirmarDestrutivo` + SnackBar com `Desfazer` (re-marca os ids); cancelar não altera; erro exibido em falha; testes de widget verdes.
- [ ] **F64-T03** — Governança, bump e fechamento
  Dep: F64-T02 · Docs: 13, 14, 16.
  CP: docs donas sincronizadas; bump `1.8.4+25` com paridade em `web/version.json`; `dart format .`, `flutter analyze` e `flutter test` verdes.
```

Na tabela **Progresso por fase** (~linha 1425), após a linha da F63 e antes de `| **Total** |`:
```markdown
| F64 Revisão UX heurística | 3 | 0 |
```
E atualizar o `| **Total** |` de `**351**`/`**348**` para `**354**`/`**348**`.

- [ ] **Step 3: Registrar em `docs/16-roadmap-pos-mvp.md`**

Na seção **"Em execução agora"**, adicionar a linha (após A14, ~linha 25):
```markdown
| A15 | **Revisão UX heurística (feedback + desmarcar todos)** | **RF-03/RF-04** | F64 | [spec](superpowers/specs/2026-10-09-revisao-ux-heuristica-design.md) | concluído (F64-T01…T03) |
```

- [ ] **Step 4: Nota no resumo `docs/13-premodelo-tecnico.md`**

Em §4 "Fluxos essenciais", após o bloco `### F7 - Preço por etiqueta` (linha 60-62), adicionar:
```markdown
### F8 - Lista: feedback e ações em massa
Ao adicionar item **novo** pela entrada rápida, um SnackBar curto confirma (`itemAdicionado`);
"Desmarcar todos" (menu ⋮) pede **confirmação** quando há concluídos e oferece **Desfazer**
(re-marca os mesmos ids). Detalhe em [05 §6.3](05-app-flutter.md).
```

- [ ] **Step 5: Rodar a suíte completa e o estilo**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: `format` sem mudanças pendentes; `analyze` sem issues; `test` **todos verdes** (inclui `version_json_test` com `1.8.4`/`25`).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml web/version.json docs/13-premodelo-tecnico.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "docs(F64-T03): Fase 64, roadmap, resumo e bump 1.8.4+25"
```

---

## Notas de execução

- Ordem obrigatória: Task 1 → Task 2 → Task 3 (a Task 2 depende do padrão de ARB da Task 1; a Task 3 depende das duas).
- Autofix de formatação: se `dart format .` alterar arquivos tocados, incluí-los no commit da tarefa.
- Não tocar em A3–A6 nem em F5-T05 (fora de escopo da spec).
