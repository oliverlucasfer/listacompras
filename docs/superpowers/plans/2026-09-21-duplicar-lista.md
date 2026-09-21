# Fase 23 — Duplicar Lista ("Comprar de novo"): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-20 — criar uma lista nova a partir dos itens **pendentes** de uma lista existente, pelo menu do painel de listas, 100% offline-first, sem schema/RLS/sync novos.

**Architecture:** Um método de domínio `ListasRepository.duplicarLista` lê os pendentes do Drift e reusa `criarLista` + `adicionarItem` (mesma fila de mutações do sync). A UI adiciona um item ao `PopupMenuButton` do card (`painel_listas.dart`) e reusa o `SheetTituloLista` (com um parâmetro opcional de descrição) para confirmar título e contagem.

**Tech Stack:** Flutter · Riverpod · Drift (SQLite) · go_router · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-21-duplicar-lista-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F23-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `01`, `02` ou `03`** — esta fase não toca banco remoto, RLS nem sync.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart` (string fora do `AppStrings` é bug, doc 05 §7).
- Enum de unidades fechado: `un, kg, g, l, ml, caixa, pacote, pct, dz` (doc 01 §3.1); categorias: `hortifruti, mercearia, frios, laticinios, congelados, padaria, bebidas, pet, limpeza, higiene, outros` (doc 01 §3.2).
- Escrita sempre local + fila (Drift primeiro, nunca `await` de rede); UUID v4 no cliente (doc 03).
- Docs donos atualizados **no mesmo PR** da mudança de comportamento.
- Testes: nome `deve_<resultado>_quando_<condição>` (doc 07 §1).
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Domínio — `ListasRepository.duplicarLista`

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (método novo após `limparConcluidos`, ~linha 414)
- Create: `test/features/listas/duplicar_lista_test.dart`

**Interfaces:**
- Consumes: `criarLista({titulo, donoId})`, `adicionarItem({listaId, nome, quantidade, unidade, categoria})` (já existentes); `Unidade.fromValor` (`lib/features/listas/domain/unidade.dart:18`), `CategoriaItem.fromValor` (`lib/features/listas/domain/categoria.dart:35`); Drift `itemLocal` (`ItemLocalData` com `nome`, `quantidade`, `unidade` (String), `categoria` (String), `concluido`, `ordem`).
- Produces: `Future<Lista> ListasRepository.duplicarLista({required String origemId, required String titulo, required String donoId})` — consumido pela Task 2.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/features/listas/duplicar_lista_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<ItemLocalData>> itensDe(String listaId) {
    return (db.select(db.itemLocal)
          ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
          ..orderBy([
            (i) => OrderingTerm.asc(i.ordem),
            (i) => OrderingTerm.asc(i.id),
          ]))
        .get();
  }

  test('deve_copiar_somente_pendentes_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'Semana', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    final comprado = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Leite',
    );
    await repo.editarItem(comprado.id, concluido: true);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Semana (2)',
      donoId: 'user-a',
    );

    final itens = await itensDe(nova.id);
    expect(itens.map((i) => i.nome), ['Arroz']);
    expect(itens.single.concluido, isFalse);
  });

  test(
    'deve_preservar_nome_quantidade_unidade_categoria_quando_duplica',
    () async {
      final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      await repo.adicionarItem(
        listaId: origem.id,
        nome: 'Queijo',
        quantidade: 0.5,
        unidade: Unidade.kg,
        categoria: CategoriaItem.frios,
      );

      final nova = await repo.duplicarLista(
        origemId: origem.id,
        titulo: 'Y',
        donoId: 'user-a',
      );

      final item = (await itensDe(nova.id)).single;
      expect(item.nome, 'Queijo');
      expect(item.quantidade, 0.5);
      expect(item.unidade, 'kg');
      expect(item.categoria, 'frios');
    },
  );

  test('deve_preservar_a_ordem_dos_itens_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final arroz = await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    final feijao = await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    final macarrao = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Macarrão',
    );
    await repo.reordenarItens(origem.id, [macarrao.id, arroz.id, feijao.id]);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    expect(
      (await itensDe(nova.id)).map((i) => i.nome),
      ['Macarrão', 'Arroz', 'Feijão'],
    );
  });

  test('deve_enfileirar_mutacao_de_lista_e_de_cada_item_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    final novas = (await db.select(db.mutacaoPendente).get())
        .where((m) => m.listaId == nova.id)
        .toList();
    expect(novas.where((m) => m.tabela == 'listas'), hasLength(1));
    expect(novas.where((m) => m.tabela == 'itens_lista'), hasLength(2));
  });

  test('deve_deixar_a_lista_original_intacta_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');

    await repo.duplicarLista(origemId: origem.id, titulo: 'Y', donoId: 'user-a');

    final itensOrigem = await itensDe(origem.id);
    expect(itensOrigem, hasLength(1));
    expect(itensOrigem.single.nome, 'Arroz');
  });

  test('deve_atribuir_o_novo_dono_quando_duplica', () async {
    final origem = await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-b');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Minha',
      donoId: 'user-a',
    );

    expect(nova.donoId, 'user-a');
    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(nova.id))).getSingle();
    expect(local.donoId, 'user-a');
  });

  test('deve_falhar_quando_nao_ha_pendentes', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    await repo.editarItem(item.id, concluido: true);

    expect(
      () => repo.duplicarLista(origemId: origem.id, titulo: 'Y', donoId: 'user-a'),
      throwsStateError,
    );

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/duplicar_lista_test.dart`
Expected: FAIL na compilação — `The method 'duplicarLista' isn't defined for the type 'ListasRepository'`.

- [ ] **Step 3: Implementar o método**

Em `lib/features/listas/data/listas_repository.dart`, inserir logo após `limparConcluidos` (antes do bloco `// ---- Internos ----`):

```dart
  /// Duplica uma lista a partir dos itens **pendentes** (RF-20, "comprar de
  /// novo"): cria uma lista nova do `donoId` e copia nome/quantidade/unidade/
  /// categoria de cada pendente, na ordem original; a origem não é tocada.
  /// Offline-first: reusa `criarLista`/`adicionarItem` e a fila de mutações.
  Future<Lista> duplicarLista({
    required String origemId,
    required String titulo,
    required String donoId,
  }) async {
    final pendentes =
        await (_db.select(_db.itemLocal)..where(
              (i) =>
                  i.listaId.equals(origemId) &
                  i.deletadoEm.isNull() &
                  i.concluido.equals(false),
            )
            ..orderBy([
              (i) => OrderingTerm.asc(i.ordem),
              (i) => OrderingTerm.asc(i.id),
            ]))
            .get();
    if (pendentes.isEmpty) {
      throw StateError('não há itens pendentes para duplicar');
    }

    final nova = await criarLista(titulo: titulo, donoId: donoId);
    for (final item in pendentes) {
      await adicionarItem(
        listaId: nova.id,
        nome: item.nome,
        quantidade: item.quantidade,
        unidade: Unidade.fromValor(item.unidade),
        categoria: CategoriaItem.fromValor(item.categoria),
      );
    }
    return nova;
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/duplicar_lista_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/listas/data/listas_repository.dart test/features/listas/duplicar_lista_test.dart
git commit -m "F23-T01: duplicar lista no repositorio (RF-20)"
```

---

### Task 2: UI — strings, descrição no sheet de título e menu "Comprar de novo"

**Files:**
- Modify: `lib/core/l10n/app_strings.dart:95` (após `listaRenomeada`)
- Modify: `lib/features/listas/ui/sheet_titulo_lista.dart`
- Modify: `lib/features/listas/ui/painel_listas.dart:272-300`
- Modify: `test/features/listas/minhas_listas_screen_test.dart`

**Interfaces:**
- Consumes: `ListasRepository.duplicarLista(...)` (Task 1); `abrirSheetTitulo(...)` e `SheetTituloLista` (existentes); `papelRepositoryProvider.atualizar(id, Papel.dono)`, `donoAtualIdProvider` (já importados no painel).
- Produces: `AppStrings.comprarDeNovo` (`const String`), `AppStrings.duplicarDescricao(int n)` (`String`); parâmetro opcional `String? descricao` em `SheetTituloLista`/`abrirSheetTitulo`.

- [ ] **Step 1: Escrever os testes que falham**

Acrescentar ao final de `void main()` em `test/features/listas/minhas_listas_screen_test.dart` (o helper `abrirTela` e `fechar` já existem no arquivo):

```dart
  testWidgets('deve_mostrar_comprar_de_novo_quando_ha_pendentes', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.comprarDeNovo), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_comprar_de_novo_quando_sem_pendentes', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.editarItem(item.id, concluido: true);
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.comprarDeNovo), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_criar_e_navegar_quando_confirma_duplicar', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.comprarDeNovo));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.duplicarDescricao(1)), findsOneWidget);
    expect(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();

    expect(find.textContaining('lista-'), findsOneWidget);
    expect(find.text(AppStrings.listaCriada), findsOneWidget);

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(2));
    await fechar(tester);
  });

  testWidgets('nao_deve_criar_quando_cancela_duplicar', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.comprarDeNovo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.cancelar));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart`
Expected: FAIL na compilação — `The getter 'comprarDeNovo' isn't defined for the type 'AppStrings'`.

- [ ] **Step 3: Adicionar as strings**

Em `lib/core/l10n/app_strings.dart`, logo após a linha `static const listaRenomeada = 'Lista renomeada.';` (linha 95):

```dart
  static const comprarDeNovo = 'Comprar de novo';

  static String duplicarDescricao(int n) => n == 1
      ? '1 item pendente será copiado.'
      : '$n itens pendentes serão copiados.';
```

- [ ] **Step 4: Adicionar `descricao` ao sheet de título**

Em `lib/features/listas/ui/sheet_titulo_lista.dart`:

No construtor de `SheetTituloLista`, após `this.mensagemSucesso,` (linha ~18), adicionar:

```dart
    this.descricao,
```

E o campo, após `final String? mensagemSucesso;` (linha ~24):

```dart
  final String? descricao;
```

No `build`, trocar o `const SizedBox(height: AppSpacing.lg),` que antecede o `AppCampoTexto` (linha ~93) por:

```dart
          if (widget.descricao != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.descricao!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
```

Em `abrirSheetTitulo`, adicionar o parâmetro `String? descricao` na assinatura (após `String? mensagemSucesso,`) e repassá-lo ao widget (após `mensagemSucesso: mensagemSucesso,`):

```dart
      descricao: descricao,
```

- [ ] **Step 5: Adicionar o menu e o handler no painel**

Em `lib/features/listas/ui/painel_listas.dart`, em `_CardListaState`, substituir os métodos `_itensDono`, `_itensMembro` e `_acaoMenu` (linhas ~272-300) por:

```dart
  int get _pendentes =>
      widget.contagem.totalItens - widget.contagem.concluidos;

  List<PopupMenuEntry<String>> _itensDono(BuildContext context) => [
    if (_pendentes > 0)
      const PopupMenuItem(
        value: 'duplicar',
        child: Text(AppStrings.comprarDeNovo),
      ),
    const PopupMenuItem(value: 'renomear', child: Text(AppStrings.renomear)),
    PopupMenuItem(
      value: 'excluir',
      child: Text(
        AppStrings.excluir,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  ];

  List<PopupMenuEntry<String>> _itensMembro() => [
    if (_pendentes > 0)
      const PopupMenuItem(
        value: 'duplicar',
        child: Text(AppStrings.comprarDeNovo),
      ),
    const PopupMenuItem(value: 'membros', child: Text(AppStrings.membros)),
    const PopupMenuItem(value: 'sair', child: Text(AppStrings.sairDaLista)),
  ];

  void _acaoMenu(String acao) {
    final listaId = widget.contagem.lista.id;
    switch (acao) {
      case 'duplicar':
        _duplicar();
      case 'renomear':
        _abrirSheetRenomear();
      case 'excluir':
        _confirmarExclusao();
      case 'membros':
        context.push('/membros/$listaId');
      case 'sair':
        confirmarSairDaLista(context, ref, listaId);
    }
  }

  Future<void> _duplicar() async {
    final lista = widget.contagem.lista;
    String? criadoId;
    await abrirSheetTitulo(
      context,
      titulo: AppStrings.comprarDeNovo,
      descricao: AppStrings.duplicarDescricao(_pendentes),
      rotuloBotao: AppStrings.criarLista,
      valorInicial: lista.titulo,
      mensagemSucesso: AppStrings.listaCriada,
      onSalvar: (nome) async {
        final nova = await ref
            .read(listasRepositoryProvider)
            .duplicarLista(
              origemId: lista.id,
              titulo: nome,
              donoId: ref.read(donoAtualIdProvider),
            );
        ref.read(papelRepositoryProvider).atualizar(nova.id, Papel.dono);
        criadoId = nova.id;
      },
    );
    if (criadoId != null && mounted) {
      context.push('/lista/$criadoId');
    }
  }
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os 4 novos).

- [ ] **Step 7: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/sheet_titulo_lista.dart lib/features/listas/ui/painel_listas.dart test/features/listas/minhas_listas_screen_test.dart
git commit -m "F23-T02: menu comprar de novo e sheet no painel (RF-20)"
```

---

### Task 3: Docs donos e fechamento da Fase 23

**Files:**
- Modify: `docs/12-prd.md` (§2 tabela de RF e §6 matriz de rastreabilidade)
- Modify: `docs/05-app-flutter.md` (§6.2)
- Modify: `docs/10-wireframes-telas.md` (nova §2.5)
- Modify: `docs/14-tarefas.md` (nova Fase 23 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A1 → concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: RF-20 no PRD**

Em `docs/12-prd.md`, após a linha do RF-19 (linha 42), adicionar:

```markdown
| RF-20 | Duplicar lista ("comprar de novo"): cria uma lista nova a partir dos itens pendentes de uma lista existente | 05 §6.2 + 10 §2.5 | F23 | [05 §8](05-app-flutter.md) |
```

Em §6 (matriz de rastreabilidade), após a linha do RF-19 (linha 133), adicionar:

```markdown
| RF-20 | US-01 | F23 | F23-T01, F23-T02 | Unit duplicar (só pendentes, preserva campos/ordem) + widget do painel |
```

- [ ] **Step 2: Doc 05 §6.2**

Em `docs/05-app-flutter.md`, após o bullet "Busca (F16, RF-17)" (linha 168), adicionar:

```markdown
* **Comprar de novo (RF-20, F23):** o menu `⋮` — dono **e** membro — ganha o item "Comprar de novo" quando a lista tem itens **pendentes**; abre o sheet de título (com a contagem de pendentes, título pré-preenchido com o da origem, editável) e cria uma lista nova copiando os pendentes — nome/quantidade/unidade/categoria, na ordem original, todos pendentes — com o usuário atual como dono; a lista nova abre em seguida. Escrita local + fila, sem rede (doc 03).
```

- [ ] **Step 3: Wireframe 10 §2.5**

Em `docs/10-wireframes-telas.md`, logo antes de `## 3. Tela da Lista de Compras` (linha 152), adicionar:

```markdown
### 2.5. Sheet "Comprar de novo" (F23/RF-20)

**Entrada:** item "Comprar de novo" no menu `⋮` do card (dono e membro), **só quando há pendentes** (doc 10 §2.1).

```
┌─────────────────────────────────┐
│  Comprar de novo             ✕  │
├─────────────────────────────────┤
│  3 itens pendentes serão        │
│  copiados.                      │
│                                 │
│  Nome da lista                  │
│  [ Compras da Semana         ]  │ ← pré-preenchido, editável
│                                 │
│  (       Criar lista      )     │ ← cria + abre a lista nova (RF-20)
└─────────────────────────────────┘
```
```

- [ ] **Step 4: Fase 23 e progresso em 14**

Em `docs/14-tarefas.md`, logo antes de `## Progresso por fase (atualize ao concluir)` (linha 566), adicionar:

```markdown
## Fase 23 — Duplicar lista ("comprar de novo")

Spec: [superpowers/specs/2026-09-21-duplicar-lista-design.md](superpowers/specs/2026-09-21-duplicar-lista-design.md) · Requisito: RF-20 (duplicar lista). · Docs donos: 05, 10, 12.

- [x] **F23-T01** — Duplicar lista no repositório (RF-20)
  Dep: — · Docs: [05 §6.2](05-app-flutter.md)
  CP: `ListasRepository.duplicarLista` copia só pendentes, preserva nome/quantidade/unidade/categoria e ordem, enfileira mutações e não altera a origem; unit tests verdes.
- [x] **F23-T02** — Menu "Comprar de novo" e sheet no painel (RF-20)
  Dep: F23-T01 · Docs: [05 §6.2](05-app-flutter.md), [10 §2.5](10-wireframes-telas.md)
  CP: item no menu `⋮` (dono e membro) só com pendentes; sheet com contagem e título editável; cria e abre a lista nova; widget tests verdes.
- [x] **F23-T03** — Docs donos e fechamento
  Dep: F23-T02 · Docs: [12](12-prd.md), [05](05-app-flutter.md), [10](10-wireframes-telas.md), [14](14-tarefas.md), [16](16-roadmap-pos-mvp.md)
  CP: RF-20 no 12; §6.2 no 05; §2.5 no 10; Fase 23 marcada e progresso atualizado.

```

Na tabela de progresso, após a linha `| F22 Modo mercado e itens frequentes | 5 | 5 |` (linha 589), adicionar:

```markdown
| F23 Duplicar lista | 3 | 3 |
```

E atualizar a linha do total (linha 590) para:

```markdown
| **Total** | **138** | **136** |
```

- [ ] **Step 5: Roadmap 16 — A1 concluído**

Em `docs/16-roadmap-pos-mvp.md`, na tabela "Em execução agora", trocar a linha do A1 por:

```markdown
| A1 | **Duplicar lista ("Comprar de novo")** | **RF-20** | F23 | [spec](superpowers/specs/2026-09-21-duplicar-lista-design.md) | concluído (F23-T01…T03) |
```

- [ ] **Step 6: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add docs/12-prd.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F23-T03: docs donos e fechamento da Fase 23 (RF-20)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 domínio → Task 1; §4 UI → Task 2; §5 reuso (`descricao` opcional) → Task 2 Step 4; §6 testes → Tasks 1–2; §7 decisões → refletidas nas tarefas; §2 escopo → nada de arquivar/escolher itens.
- **Placeholders:** nenhum "TBD/TODO"; todos os steps têm código/comando.
- **Consistência de tipos:** `duplicarLista({origemId, titulo, donoId}) → Future<Lista>`, `descricao` (String?), `comprarDeNovo` (String), `duplicarDescricao(int) → String`, `_pendentes` (int) — idênticos entre Tasks 1–2–3.
