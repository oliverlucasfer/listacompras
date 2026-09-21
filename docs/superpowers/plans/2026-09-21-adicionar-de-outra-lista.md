# Fase 27 — Adicionar Itens de Outra Lista (RF-23): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-23 — trazer itens (pendentes) de outra lista existente para a lista atual, com multi-seleção, reusando a dedup do app. 100% offline, sem schema/RLS/sync.

**Architecture:** Extrair a regra de dedup hoje privada na tela para `ListasRepository.adicionarItemDedup`/`adicionarItensDedup` (mesmo nome normalizado → soma/replace). Um modal escolhe a lista de origem (Drift) e os pendentes; a tela escreve pelos caminhos locais (fila + LWW).

**Tech Stack:** Flutter · Riverpod · Drift · Material 3 (sem banco remoto).

**Spec:** `docs/superpowers/specs/2026-09-21-adicionar-de-outra-lista-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F27-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `docs/01`, `docs/02`, `docs/03`** — sem schema/RLS/sync.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Ação visível só a **dono/editor**; preço **não** é copiado.
- Dedup: nome **normalizado** (`normalizarTexto`); mesma unidade soma; unidade diferente substitui.
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Repositório — extrair a dedup e adicionar em lote

**Files:**
- Create: `lib/features/listas/domain/resultado_dedup.dart`
- Modify: `lib/features/listas/data/listas_repository.dart` (métodos novos, após `adicionarItem`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_adicionarItemDedup` vira wrapper)
- Modify: `test/features/listas/listas_repository_test.dart`

**Interfaces:**
- Consumes: `normalizarTexto` (`lib/core/texto/normalizar.dart`, já importado no repo), `adicionarItem`/`editarItem`, Drift `itemLocal`, `Item`/`Unidade`/`CategoriaItem`.
- Produces: `enum ResultadoDedup { adicionado, somado, substituido }`; `ListasRepository.adicionarItemDedup({listaId, nome, quantidade, unidade, categoria}) -> Future<ResultadoDedup>`; `ListasRepository.adicionarItensDedup(String listaId, Iterable<Item> itens) -> Future<void>`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/listas/listas_repository_test.dart`, acrescentar ao final de `void main()` (o arquivo já tem `db`, `repo`, `fila()`):

```dart
  test('deve_adicionar_quando_nome_nao_existe', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
    );
    expect(r, ResultadoDedup.adicionado);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 2);
  });

  test('deve_somar_quando_mesmo_nome_e_unidade', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
    );
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'ARROZ',
      quantidade: 1,
      unidade: Unidade.kg,
      categoria: CategoriaItem.outros,
    );
    expect(r, ResultadoDedup.somado);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens, hasLength(1));
    expect(itens.single.quantidade, 3);
  });

  test('deve_substituir_quando_mesmo_nome_e_unidade_diferente', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
    );
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 5,
      unidade: Unidade.un,
      categoria: CategoriaItem.outros,
    );
    expect(r, ResultadoDedup.substituido);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens.single.quantidade, 5);
    expect(itens.single.unidade, 'un');
  });

  test('deve_ignorar_preco_e_concluido_quando_adicionar_lote', () async {
    final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
    final destino = await repo.criarLista(titulo: 'Destino', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Queijo',
      quantidade: 0.5,
      unidade: Unidade.kg,
      categoria: CategoriaItem.frios,
      precoCentavos: 4990,
    );
    await repo.editarItem(item.id, concluido: true);

    final fonte = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    await repo.adicionarItensDedup(destino.id, [Item.fromLocal(fonte)]);

    final novo = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(destino.id))).getSingle();
    expect(novo.nome, 'Queijo');
    expect(novo.quantidade, 0.5);
    expect(novo.unidade, 'kg');
    expect(novo.categoria, 'frios');
    expect(novo.concluido, isFalse);
    expect(novo.precoCentavos, isNull);
  });

  test('deve_aplicar_dedup_por_nome_normalizado_quando_adicionar_lote', () async {
    final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
    final destino = await repo.criarLista(titulo: 'Destino', donoId: 'user-a');
    await repo.adicionarItem(listaId: destino.id, nome: 'Café');
    final itemOrigem = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'CAFE',
      quantidade: 2,
    );

    final fonte = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(itemOrigem.id))).getSingle();
    await repo.adicionarItensDedup(destino.id, [Item.fromLocal(fonte)]);

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(destino.id))).get();
    expect(itens, hasLength(1));
    expect(itens.single.quantidade, 3);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: FAIL na compilação — `The method 'adicionarItemDedup' isn't defined` e `Member not found: 'ResultadoDedup'`.

- [ ] **Step 3: Implementar**

`lib/features/listas/domain/resultado_dedup.dart`:

```dart
/// O que aconteceu ao adicionar um item com dedup (RF-10/RF-23): insere um
/// novo, soma a quantidade de um existente (mesma unidade) ou substitui
/// quantidade/unidade (unidade diferente).
enum ResultadoDedup { adicionado, somado, substituido }
```

Em `lib/features/listas/data/listas_repository.dart`, após `adicionarItem`:

```dart
  /// Adiciona um item aplicando a dedup do app (RF-10): compara o nome
  /// **normalizado** com os itens ativos da lista; mesmo nome e mesma unidade
  /// → soma a quantidade; unidade diferente → substitui quantidade/unidade.
  /// Sem existente → insere com a `categoria` recebida.
  Future<ResultadoDedup> adicionarItemDedup({
    required String listaId,
    required String nome,
    required double quantidade,
    required Unidade unidade,
    required CategoriaItem categoria,
  }) async {
    final itens =
        await (_db.select(_db.itemLocal)..where(
              (i) => i.listaId.equals(listaId) & i.deletadoEm.isNull(),
            ))
            .get();
    final alvo = normalizarTexto(nome);
    ItemLocalData? existente;
    for (final i in itens) {
      if (normalizarTexto(i.nome) == alvo) {
        existente = i;
        break;
      }
    }
    if (existente != null) {
      if (existente.unidade == unidade.valor) {
        await editarItem(
          existente.id,
          quantidade: existente.quantidade + quantidade,
        );
        return ResultadoDedup.somado;
      }
      await editarItem(existente.id, quantidade: quantidade, unidade: unidade);
      return ResultadoDedup.substituido;
    }
    await adicionarItem(
      listaId: listaId,
      nome: nome,
      quantidade: quantidade,
      unidade: unidade,
      categoria: categoria,
    );
    return ResultadoDedup.adicionado;
  }

  /// Adiciona um lote de itens (RF-23), um a um pela dedup. Copia nome/
  /// quantidade/unidade/categoria; **ignora preço e concluído**.
  Future<void> adicionarItensDedup(String listaId, Iterable<Item> itens) async {
    for (final item in itens) {
      await adicionarItemDedup(
        listaId: listaId,
        nome: item.nome,
        quantidade: item.quantidade,
        unidade: item.unidade,
        categoria: item.categoria,
      );
    }
  }
```

Import de `resultado_dedup.dart` no repositório.

Em `lib/features/listas/ui/tela_lista_screen.dart`, substituir o corpo de `_adicionarItemDedup` para usar o repositório (a sugestão de categoria continua na UI):

```dart
  Future<void> _adicionarItemDedup({
    required String nome,
    required double quantidade,
    required Unidade unidade,
  }) async {
    final categoria = await ref
        .read(sugestaoCategoriasProvider)
        .sugerirCategoria(nome);
    final resultado = await ref
        .read(listasRepositoryProvider)
        .adicionarItemDedup(
          listaId: widget.listaId,
          nome: nome,
          quantidade: quantidade,
          unidade: unidade,
          categoria: categoria,
        );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoDedup.somado:
        mostrarSnackBar(context, '$nome ${AppStrings.itemDuplicadoSomado}');
      case ResultadoDedup.substituido:
        mostrarSnackBar(context, '$nome: ${AppStrings.itemAtualizado}');
      case ResultadoDedup.adicionado:
        break;
    }
  }
```

> Ajuste os imports da tela (`resultado_dedup.dart`); remova imports que ficarem sem uso (`normalizarTexto` pode não ser mais usado na tela). `sugestaoCategoriasProvider` continua sendo usado.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (a suíte da tela valida a regressão do quick-add/chip).

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/features/listas/domain/resultado_dedup.dart lib/features/listas/data/listas_repository.dart lib/features/listas/ui/tela_lista_screen.dart test/features/listas/listas_repository_test.dart
git commit -m "F27-T01: extrai a dedup para o repositorio e adiciona em lote (RF-23)"
```

---

### Task 2: UI — modal "Adicionar de outra lista"

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Create: `lib/features/listas/ui/modal_adicionar_de_outra_lista.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (menu + case + abrir modal)
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `ListasRepository.adicionarItensDedup` (Task 1); `listasComContagemProvider`; `itensDaListaProvider`; `AppDropdown`; `Item`.
- Produces: `Future<List<Item>?> abrirModalAdicionarDeOutraLista(BuildContext, {required String listaAtualId})`; strings novas.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`, perto de `importarLista`:

```dart
  static const adicionarDeOutraLista = 'Adicionar de outra lista';
  static const escolherListaOrigem = 'Lista de origem';
  static const selecionarTodos = 'Selecionar todos';
  static const adicionarSelecionados = 'Adicionar';
  static const nenhumItemPendenteNaOrigem =
      'Nenhum item pendente nesta lista.';

  static String itensAdicionadosDeOutra(int n) => n == 1
      ? '1 item adicionado de outra lista.'
      : '$n itens adicionados de outra lista.';
```

- [ ] **Step 2: Escrever os testes que falham**

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar ao final de `void main()` (reuse o harness real do arquivo — `db`, `appDatabaseProvider`, `papelRepositoryProvider`, `syncStatusProvider`, como em `abrirListaF7t07`):

```dart
  testWidgets('deve_abrir_modal_de_outra_lista_quando_toca_menu', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await abrirListaF7t07(tester); // ajuste para abrir a lista "Atual"

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.adicionarDeOutraLista), findsOneWidget);
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.escolherListaOrigem), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_adicionar_selecionados_quando_confirma', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz', quantidade: 2);
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    // abrir a tela na lista `atual` (use o harness com o id de `atual`)

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.selecionarTodos));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.adicionarSelecionados),
    );
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(atual.id))).get();
    expect(itens.map((i) => i.nome), containsAll(['Arroz', 'Feijão']));
    expect(find.text(AppStrings.itensAdicionadosDeOutra(2)), findsOneWidget);
    await fechar(tester);
  });
```

> O harness `abrirListaF7t07` do arquivo abre uma lista fixa; adicione/parametrize um helper que aceite o `listaId` (ou crie as listas com o mesmo id que o harness usa). Mantenha os testes reais (Drift em memória).

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL — o item de menu e o modal ainda não existem.

- [ ] **Step 4: Implementar o modal e a entrada**

`lib/features/listas/ui/modal_adicionar_de_outra_lista.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../domain/item.dart';
import '../providers/listas_providers.dart';

/// Modal "Adicionar de outra lista" (RF-23): escolhe a origem, marca os
/// pendentes e devolve os selecionados (ou null se cancelado).
Future<List<Item>?> abrirModalAdicionarDeOutraLista(
  BuildContext context, {
  required String listaAtualId,
}) {
  return showDialog<List<Item>>(
    context: context,
    builder: (_) => ModalAdicionarDeOutraLista(listaAtualId: listaAtualId),
  );
}

class ModalAdicionarDeOutraLista extends ConsumerStatefulWidget {
  const ModalAdicionarDeOutraLista({super.key, required this.listaAtualId});

  final String listaAtualId;

  @override
  ConsumerState<ModalAdicionarDeOutraLista> createState() =>
      _ModalAdicionarDeOutraListaState();
}

class _ModalAdicionarDeOutraListaState
    extends ConsumerState<ModalAdicionarDeOutraLista> {
  String? _origemId;
  final _selecionados = <String>{};

  @override
  Widget build(BuildContext context) {
    final listas = (ref.watch(listasComContagemProvider).value ?? const [])
        .where((c) => c.lista.id != widget.listaAtualId)
        .toList();
    if (listas.isEmpty) {
      return AlertDialog(
        title: const Text(AppStrings.adicionarDeOutraLista),
        content: const Text(AppStrings.nenhumaLista),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancelar),
          ),
        ],
      );
    }
    final origemId = _origemId ?? listas.first.lista.id;
    final pendentes =
        (ref.watch(itensDaListaProvider(origemId)).value ?? const <Item>[])
            .where((i) => !i.concluido)
            .toList();
    return AlertDialog(
      title: const Text(AppStrings.adicionarDeOutraLista),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<String>(
              label: AppStrings.escolherListaOrigem,
              valor: origemId,
              itens: [
                for (final c in listas)
                  DropdownMenuItem(
                    value: c.lista.id,
                    child: Text(
                      c.lista.arquivadaEm == null
                          ? c.lista.titulo
                          : '${c.lista.titulo} · ${AppStrings.arquivada}',
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) {
                  setState(() {
                    _origemId = id;
                    _selecionados.clear();
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (pendentes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(AppStrings.nenhumItemPendenteNaOrigem),
              )
            else ...[
              TextButton(
                onPressed: () => setState(() {
                  if (_selecionados.length == pendentes.length) {
                    _selecionados.clear();
                  } else {
                    _selecionados
                      ..clear()
                      ..addAll(pendentes.map((i) => i.id));
                  }
                }),
                child: const Text(AppStrings.selecionarTodos),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in pendentes)
                        CheckboxListTile(
                          value: _selecionados.contains(item.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selecionados.add(item.id);
                            } else {
                              _selecionados.remove(item.id);
                            }
                          }),
                          title: Text(item.nome),
                          subtitle: Text('${item.quantidade} ${item.unidade.valor}'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: AppStrings.adicionarSelecionados,
          expandido: false,
          onPressed: _selecionados.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  pendentes.where((i) => _selecionados.contains(i.id)).toList(),
                ),
        ),
      ],
    );
  }
}
```

Em `lib/features/listas/ui/tela_lista_screen.dart`:
1. Import do modal.
2. No `itemBuilder` do menu, no bloco de quem escreve:
   ```dart
   if (podeEscrever)
     const PopupMenuItem(
       value: 'outraLista',
       child: Text(AppStrings.adicionarDeOutraLista),
     ),
   ```
3. No `_acaoMenu`, case:
   ```dart
   case 'outraLista':
     _adicionarDeOutraLista(context, ref, idLista);
   ```
4. Método:
   ```dart
   Future<void> _adicionarDeOutraLista(
     BuildContext context,
     WidgetRef ref,
     String idLista,
   ) async {
     final selecionados = await abrirModalAdicionarDeOutraLista(
       context,
       listaAtualId: idLista,
     );
     if (selecionados == null || selecionados.isEmpty || !context.mounted) {
       return;
     }
     await ref
         .read(listasRepositoryProvider)
         .adicionarItensDedup(idLista, selecionados);
     if (context.mounted) {
       mostrarSnackBar(
         context,
         AppStrings.itensAdicionadosDeOutra(selecionados.length),
       );
     }
   }
   ```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/modal_adicionar_de_outra_lista.dart lib/features/listas/ui/tela_lista_screen.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F27-T02: modal adicionar de outra lista no menu (RF-23)"
```

---

### Task 3: Docs donos e fechamento da Fase 27

**Files:**
- Modify: `docs/05-app-flutter.md` (§6.3 — menu e modal)
- Modify: `docs/10-wireframes-telas.md` (§3 — wireframe do modal)
- Modify: `docs/12-prd.md` (RF-23 + rastreabilidade)
- Modify: `docs/14-tarefas.md` (Fase 27 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A3 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: Docs 05 e 10**
  - `05 §6.3`: bullet "Adicionar de outra lista (RF-23, F27)" — item no menu ⋮ (dono/editor); modal com seletor de origem (todas menos a atual, arquivadas rotuladas) e pendentes com multi-seleção + "Selecionar todos"; adiciona com a dedup do app (soma/replace); não copia preço.
  - `10 §3`: wireframe/nota do modal (seletor + checklist + ação).

- [ ] **Step 2: Doc 12**
  - `12 §2`: `RF-23 | Adicionar itens de outra lista (pendentes, multi-seleção, dedup) | 05 §6.3 + 10 §3 | F27 | ...`; `§6`: rastreabilidade `RF-23 | US-01 | F27 | F27-T01, F27-T02 | Unit dedup/lote + widgets`.

- [ ] **Step 3: Doc 16**
  - Onda A linha A3 → `concluído (F27-T01…T03)`.

- [ ] **Step 4: Doc 14 (Fase 27 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 27 com F27-T01…T03 `[x]` e CPs.
  - Na tabela, após `| F26 Arquivar listas | 4 | 4 |`, adicionar `| F27 Itens de outra lista | 3 | 3 |` e atualizar o total para `| **Total** | **155** | **153** |`.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F27-T03: docs donos e fechamento da Fase 27 (RF-23)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 repositório/dedup → Task 1; §4 UI → Task 2; §5 detalhes (sem preço, origem ≠ atual) → Tasks 1–2; §6 testes → Tasks 1–2; §7 docs → Task 3.
- **Placeholders:** nenhum "TBD"; todo o código de produção está completo. Os testes de widget reusam o harness real do arquivo (o implementador parametriza o `listaId` do helper).
- **Consistência de tipos:** `ResultadoDedup`, `adicionarItemDedup({listaId,nome,quantidade,unidade,categoria}) -> Future<ResultadoDedup>`, `adicionarItensDedup(String, Iterable<Item>)`, `abrirModalAdicionarDeOutraLista(BuildContext,{listaAtualId}) -> Future<List<Item>?>`, progresso 155/153 — idênticos entre tarefas.
- **YAGNI:** sem schema, sem cópia de preço, sem RPC.
