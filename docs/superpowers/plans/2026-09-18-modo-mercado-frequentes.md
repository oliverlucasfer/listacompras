# Fase 22 — Modo Mercado e Itens Frequentes: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o modo mercado (RF-18, tela focada para usar no corredor) e itens frequentes (RF-19, chips de sugestão) como features offline-first, sem schema, RLS ou sync novos.

**Architecture:** O modo mercado é uma nova view sobre o `itensDaListaProvider` existente, que reaproveita `ListasRepository.editarItem` para marcar/desmarcar. Itens frequentes é uma consulta derivada (`customSelect` com `GROUP BY`) sobre `item_local`. Nenhuma escrita nova no Drift além das mutações já enfileiradas.

**Tech Stack:** Flutter · Riverpod · Drift (SQLite) · go_router · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-18-modo-mercado-frequentes-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F22-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `01`, `02` ou `03`** — esta fase não toca banco remoto nem sync.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart` (string fora do `AppStrings` é bug, doc 05 §7).
- Enum de unidades fechado: `un, kg, g, l, ml, caixa, pacote, pct, dz` (doc 01 §3.1).
- Acessibilidade RNF-06: alvos ≥48dp, `Semantics`, escala de texto 2.0 sem overflow.
- Docs donos atualizados **no mesmo commit** da mudança de comportamento (doc dono = autoridade).
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Limpezas — strings órfãs de IA e parser `pct`

**Files:**
- Modify: `lib/core/l10n/app_strings.dart:71`, `:78`
- Modify: `lib/core/importacao/parser_lista_local.dart:29`
- Modify: `test/core/importacao/parser_lista_local_test.dart`

**Interfaces:**
- Consumes: `Unidade.pct` (`lib/features/listas/domain/unidade.dart:11`) — já existe, valor `'pct'`.
- Produces: nada que tarefas posteriores consumam.

- [ ] **Step 1: Escrever o teste que falha do `pct`**

Acrescentar em `test/core/importacao/parser_lista_local_test.dart` (dentro do `group` já existente de unidades; se não houver, criar `group('unidades', () {`):

```dart
test('deve_mapear_pct_para_o_enum_pct_quando_unidade_abreviada', () {
  final r = analisarListaLocal('2 pct de ovos');
  expect(r.itens.single.quantidade, 2);
  expect(r.itens.single.unidade, Unidade.pct);
});

test('deve_mapear_pct_para_o_enum_pct_quando_colado_ao_numero', () {
  final r = analisarListaLocal('2pct de ovos');
  expect(r.itens.single.unidade, Unidade.pct);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: FAIL — o primeiro teste recebe `Unidade.pacote`.

- [ ] **Step 3: Corrigir o mapeamento**

Em `lib/core/importacao/parser_lista_local.dart`, trocar a linha 29:

```dart
  'pct': Unidade.pct,
```

(`'pacote'`/`'pacotes'` continuam `Unidade.pacote` — não tocar.)

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: PASS (todos).

- [ ] **Step 5: Remover as strings órfãs de IA**

Em `lib/core/l10n/app_strings.dart`:
- remover a linha 71 `static const importarPorIa = 'Importar por IA';`
- trocar a linha 78:

```dart
  static const criePrimeiraLista =
      'Crie sua primeira lista ou importe por texto.';
```

Confirmar que não há outras referências:

Run: `git grep -n "importarPorIa"` e `git grep -n "com IA"`
Expected: sem resultados.

- [ ] **Step 6: Rodar a suíte e commitar**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/core/l10n/app_strings.dart lib/core/importacao/parser_lista_local.dart test/core/importacao/parser_lista_local_test.dart
git commit -m "F22-T01: corrige pct no parser e remove strings orfas de IA"
```

---

### Task 2: Itens frequentes — domínio e consulta no repositório

**Files:**
- Create: `lib/features/listas/domain/sugestao_item.dart`
- Modify: `lib/features/listas/data/listas_repository.dart` (método novo após `watchItensDaLista`, ~linha 48)
- Create: `test/features/listas/itens_frequentes_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.itemLocal`, `AppDatabase.listaLocal`, `normalizarTexto` (`lib/core/texto/normalizar.dart`).
- Produces: `class SugestaoItem { final String nome; final int peso; }` e
  `Stream<List<SugestaoItem>> ListasRepository.watchItensFrequentes(String listaId)`.

- [ ] **Step 1: Criar o modelo**

`lib/features/listas/domain/sugestao_item.dart`:

```dart
/// Sugestão de item frequente (RF-19): nome de exibição + peso do ranking
/// derivado do histórico local (lista aberta pesa 2, demais listas pesam 1).
class SugestaoItem {
  const SugestaoItem({required this.nome, required this.peso});

  final String nome;
  final int peso;
}
```

- [ ] **Step 2: Escrever os testes que falham**

Criar `test/features/listas/itens_frequentes_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> item(
    String listaId,
    String nome, {
    bool concluido = false,
    bool deletado = false,
  }) => repo.adicionarItem(
    listaId: listaId,
    nome: nome,
    quantidade: 1,
    concluido: concluido,
  );

  test('deve_agrupar_por_nome_normalizado_quando_acento_e_caixa_diferem',
      () async {
    await item('l1', 'Leite');
    await item('l2', 'leite');
    await item('l2', 'LEITE');
    final s = await repo.watchItensFrequentes('l3').first;
    expect(s.single.nome, 'Leite');
    expect(s.single.peso, 3);
  });

  test('deve_ignorar_item_removido_quando_tombstone', () async {
    await item('l1', 'Arroz');
    final id = (await db.select(db.itemLocal).get()).single.id;
    await repo.removerItem(id);
    final s = await repo.watchItensFrequentes('l3').first;
    expect(s, isEmpty);
  });

  test('deve_excluir_itens_ativos_da_lista_aberta_quando_sugere', () async {
    await item('l1', 'Feijao');
    await item('l1', 'Arroz');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.map((e) => e.nome), isNot(contains('Feijao')));
  });

  test('deve_pesar_2_na_lista_aberta_e_1_nas_demais_quando_ordena', () async {
    await item('l1', 'Cafe');
    await item('l2', 'Leite');
    await item('l3', 'Leite');
    await item('l4', 'Leite');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.first.nome, 'Leite');
    expect(s.first.peso, 3);
    expect(s.last.nome, 'Cafe');
    expect(s.last.peso, 2);
  });

  test('deve_descartar_nome_abaixo_do_limiar_quando_peso_menor_que_2',
      () async {
    await item('l2', 'Unico');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s, isEmpty);
  });

  test('deve_limitar_a_8_sugestoes_quando_ha_mais_candidatos', () async {
    for (var i = 0; i < 12; i++) {
      await item('l2', 'Item $i');
      await item('l3', 'Item $i');
    }
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.length, 8);
  });

  test('deve_desempatar_por_nome_quando_pesos_iguais', () async {
    await item('l2', 'Zebra');
    await item('l3', 'Zebra');
    await item('l2', 'Abacate');
    await item('l3', 'Abacate');
    final s = await repo.watchItensFrequentes('l1').first;
    expect(s.map((e) => e.nome), ['Abacate', 'Zebra']);
  });
}
```

> Nota: `repo.adicionarItem` tem assinatura `({required String listaId, required String nome, required double quantidade, Unidade unidade = ..., CategoriaItem categoria = ...})`. O helper `item` usa só os obrigatórios para não depender dos enums. Se o compilador reclamar de argumento obrigatório, conferir a assinatura real em `listas_repository.dart:158` e ajustar o helper — **não** mudar o repositório por causa do teste.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/itens_frequentes_test.dart`
Expected: FAIL — `watchItensFrequentes` não existe.

- [ ] **Step 4: Implementar a consulta**

Em `lib/features/listas/data/listas_repository.dart`, após `watchItensDaLista` (linha ~48), adicionar — e importar `sugestao_item.dart` no topo:

```dart
  /// Sugestões de itens frequentes (RF-19): ranking derivado do histórico
  /// local. Peso 2 para a lista aberta, 1 para as demais; nomes já ativos
  /// na lista aberta são excluídos; limiar >= 2 e limite de 8. Zero rede.
  Stream<List<SugestaoItem>> watchItensFrequentes(String listaId) {
    return _db
        .customSelect(
          '''
    SELECT i.nome AS nome,
           SUM(CASE WHEN i.lista_id = ? THEN 2 ELSE 1 END) AS peso
    FROM item_local i
    JOIN lista_local l ON l.id = i.lista_id AND l.deletado_em IS NULL
    WHERE i.deletado_em IS NULL
      AND lower(i.nome) NOT IN (
        SELECT lower(j.nome) FROM item_local j
        WHERE j.lista_id = ? AND j.deletado_em IS NULL
      )
    GROUP BY lower(i.nome)
    HAVING SUM(CASE WHEN i.lista_id = ? THEN 2 ELSE 1 END) >= 2
    ORDER BY peso DESC, i.nome ASC
    LIMIT 8
  ''',
          variables: [
            Variable.withString(listaId),
            Variable.withString(listaId),
            Variable.withString(listaId),
          ],
          readsFrom: {_db.itemLocal, _db.listaLocal},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => SugestaoItem(
                  nome: r.read<String>('nome'),
                  peso: r.read<int>('peso'),
                ),
              )
              .toList(),
        );
  }
```

> **Atenção ao `GROUP BY`:** agrupar por `lower(i.nome)` faz o `SELECT i.nome` pegar um representante arbitrário do grupo — é o comportamento desejado (exibir a grafia mais recente não importa para o chip). O teste `deve_agrupar_por_nome_normalizado...` espera a grafia `'Leite'`; se o SQLite devolver outra, ajustar a asserção para comparar `normalizarTexto(s.nome)` e não a grafia literal.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/itens_frequentes_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 6: Suíte completa e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/listas/domain/sugestao_item.dart lib/features/listas/data/listas_repository.dart test/features/listas/itens_frequentes_test.dart
git commit -m "F22-T02: ranking de itens frequentes derivado do historico local"
```

---

### Task 3: Provider + chips de sugestão na tela da lista

**Files:**
- Modify: `lib/features/listas/providers/listas_providers.dart`
- Modify: `lib/core/l10n/app_strings.dart` (string do chip)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_CampoAdicionar`, linhas 400–541)
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `ListasRepository.watchItensFrequentes` e `SugestaoItem` (Task 2).
- Produces: `itensFrequentesProvider` (`StreamProvider.family<List<SugestaoItem>, String>`).
  Task 4 usa `papelEfetivoProvider` — já existente, não é produzido aqui.

- [ ] **Step 1: Adicionar o provider**

Em `lib/features/listas/providers/listas_providers.dart`, import `../domain/sugestao_item.dart` e acrescentar no fim:

```dart
/// Sugestões de itens frequentes da lista (RF-19).
final itensFrequentesProvider =
    StreamProvider.family<List<SugestaoItem>, String>(
      (ref, listaId) =>
          ref.watch(listasRepositoryProvider).watchItensFrequentes(listaId),
    );
```

- [ ] **Step 2: Adicionar a string**

Em `lib/core/l10n/app_strings.dart`, junto às strings de item (perto da linha 70):

```dart
  static const sugestoes = 'Sugestões';
  static String adicionarSugerido(String nome) => 'Adicionar $nome';
```

- [ ] **Step 3: Escrever o teste que falha**

Em `test/features/listas/tela_lista_screen_test.dart` adicionar:

```dart
testWidgets('deve_mostrar_chips_de_sugestoes_quando_ha_frequentes', (
  tester,
) async {
  final listaId = await listaComItens(tester);
  // Arrange: 2 itens "Leite" em OUTRA lista (peso >= 2).
  final repo = ListasRepository(db);
  final outra = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await tester.pumpAndSettle();
  expect(find.widgetWithText(ActionChip, 'Leite'), findsOneWidget);
  await fechar(tester);
});

testWidgets('deve_esconder_chips_quando_campo_tem_texto', (tester) async {
  final listaId = await listaComItens(tester);
  final repo = ListasRepository(db);
  final outra = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(AppCampoTexto).first, 'Arr');
  await tester.pumpAndSettle();
  expect(find.widgetWithText(ActionChip, 'Leite'), findsNothing);
  await fechar(tester);
});

testWidgets('deve_adicionar_item_quando_toca_no_chip', (tester) async {
  final listaId = await listaComItens(tester);
  final repo = ListasRepository(db);
  final outra = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await repo.adicionarItem(listaId: outra.id, nome: 'Leite', quantidade: 1);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ActionChip, 'Leite'));
  await tester.pumpAndSettle();
  final itens = await db.select(db.itemLocal).get();
  expect(itens.any((i) => i.nome == 'Leite' && i.listaId == listaId), isTrue);
  await fechar(tester);
});
```

> Requer importar `AppCampoTexto` e `ActionChip` (`package:flutter/material.dart`
> já cobre o chip) no arquivo de teste. Nota: `tela_lista_screen_test.dart` monta
> com `MaterialApp(home: TelaListaScreen(...))`, sem `GoRouter` — se os testes de
> chip precisarem navegar, manter o mesmo padrão dos demais (não introduzir router).

- [ ] **Step 4: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL — nenhum chip encontrado.

- [ ] **Step 5: Implementar os chips**

Em `lib/features/listas/ui/tela_lista_screen.dart`, dentro de `_CampoAdicionarState`:
- adicionar um `TextEditingController` listener no `initState` (ou usar o `onChanged` existente) para reconstruir quando o texto fica vazio/não vazio;
- retornar uma `Column` com a faixa de chips acima do `AppCampoTexto` quando `_controller.text.isEmpty`:

```dart
  @override
  Widget build(BuildContext context) {
    final sugestoes =
        ref.watch(itensFrequentesProvider(widget.listaId)).value ??
        const <SugestaoItem>[];
    final mostrarChips = _controller.text.trim().isEmpty && sugestoes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mostrarChips)
            Semantics(
              label: AppStrings.sugestoes,
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sugestoes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final s = sugestoes[i];
                    return Semantics(
                      button: true,
                      label: AppStrings.adicionarSugerido(s.nome),
                      child: ActionChip(
                        label: Text(s.nome),
                        onPressed: () => _adicionarSugerido(s.nome),
                      ),
                    );
                  },
                ),
              ),
            ),
          AppCampoTexto(/* ...como está hoje... */),
        ],
      ),
    );
  }
```

E o método que adiciona pelo chip (reaproveita a cadeia de sugestão de categoria):

```dart
  Future<void> _adicionarSugerido(String nome) async {
    final repo = ref.read(listasRepositoryProvider);
    final categoria = await ref
        .read(sugestaoCategoriasProvider)
        .sugerirCategoria(nome);
    await repo.adicionarItem(
      listaId: widget.listaId,
      nome: nome,
      quantidade: 1,
      categoria: categoria,
    );
    _controller.clear();
    if (mounted) {
      setState(() {});
      widget.onItemAdicionado?.call();
    }
  }
```

> O `AppCampoTexto` existente já tem `onChanged`; garantir que o `setState` do `onChanged` rode (ele hoje só limpa `_erro`). Ajustar para `setState(() { _erro = null; })` sempre, para os chips reagirem ao texto.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Suíte completa e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/listas/providers/listas_providers.dart lib/core/l10n/app_strings.dart lib/features/listas/ui/tela_lista_screen.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F22-T03: chips de itens frequentes na tela da lista (RF-19)"
```

---

### Task 4: Rota e tela do Modo Mercado

**Files:**
- Create: `lib/features/listas/ui/mercado_screen.dart`
- Modify: `lib/router.dart` (após a rota `/lista/:listaId`, linha ~133)
- Modify: `lib/core/l10n/app_strings.dart`
- Create: `test/features/listas/mercado_screen_test.dart`

**Interfaces:**
- Consumes: `itensDaListaProvider`, `listaPorIdProvider`, `listasRepositoryProvider`,
  `papelEfetivoProvider`, `IndicadorSync`, `botaoVoltarInicio`, `AppEsqueleto`,
  `AppEstadoErro`, `AppEstadoVazio`, `AppBotao`.
- Produces: `class MercadoScreen extends ConsumerStatefulWidget { const MercadoScreen({super.key, required this.listaId}); final String listaId; }`

- [ ] **Step 1: Adicionar as strings**

Em `lib/core/l10n/app_strings.dart`:

```dart
  static const modoMercado = 'Modo mercado';
  static String mercadoProgresso(int marcados, int total) =>
      '$marcados de $total';
  static const mercadoMarcados = 'Marcados';
  static const mercadoTudoComprado = 'Tudo comprado!';
  static const voltarParaLista = 'Voltar para a lista';
```

- [ ] **Step 2: Escrever os testes que falham**

Criar `test/features/listas/mercado_screen_test.dart` com o **próprio harness** (o arquivo é novo; seguir o padrão de overrides de `tela_lista_screen_test.dart`):

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/mercado_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> abrir(WidgetTester tester, String listaId) async {
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          donoAtualIdProvider.overrideWithValue('user-a'),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: MercadoScreen(listaId: listaId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_mostrar_somente_pendentes_quando_abre', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    final feijao = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Feijao',
      quantidade: 1,
    );
    await repo.editarItem(feijao.id, concluido: true);

    await abrir(tester, lista.id);

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijao'), findsOneWidget); // na faixa "Marcados"
    expect(find.text('0 de 2'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_marcar_item_quando_toca_e_mover_para_faixa', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1'), findsOneWidget);
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.concluido, isTrue);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_quando_tudo_comprado', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
    );
    await repo.editarItem(item.id, concluido: true);
    await abrir(tester, lista.id);
    expect(find.text(AppStrings.mercadoTudoComprado), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_estourar_em_escala_2x', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });
}
```

> O 5º teste (gate do botão para leitor) **é da Task 5** e vive em
> `tela_lista_screen_test.dart` — não duplicar aqui.
>
> `donoAtualIdProvider` tornará o papel efetivo `dono` (a lista é dele), então o
> mercado abre com escrita liberada. Para o teste de leitor do mercado, seria
> preciso uma lista de outro dono — **não é necessário** nesta fase: o gate de
> leitor é coberto na Task 5 pela ausência do botão.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/mercado_screen_test.dart`
Expected: FAIL — `MercadoScreen` não existe.

- [ ] **Step 4: Implementar a tela**

Criar `lib/features/listas/ui/mercado_screen.dart` com:
- `ConsumerStatefulWidget` `MercadoScreen({required String listaId})`;
- `AppBar` com título da lista (`listaPorIdProvider`), `botaoVoltarInicio(context, inicioDaLista(ehDono: ...))`, sem menu;
- corpo: `IndicadorSync`, contador `AppStrings.mercadoProgresso(marcados, total)`,
  `ListView` dos pendentes com `Checkbox` (alvo ≥48dp) e toque marcando via
  `repo.editarItem(item.id, concluido: true)`;
- rodapé: `ExpansionTile` "Marcados (n)" listando os concluídos, com toque desmarcando;  abre automaticamente na primeira marcação da sessão;
- estados: `AppEsqueleto` (carregando), `AppEstadoErro` com retry
  (`ref.invalidate(itensDaListaProvider(listaId))`), `AppEstadoVazio` "não encontrada"
  e "tudo comprado" com CTA `AppStrings.voltarParaLista` → `context.pop()` ou
  `context.go('/lista/$listaId')` se não houver pilha;
- **sem** grupos de categoria, busca, drag, swipe, menu ou import.

- [ ] **Step 5: Registrar a rota**

Em `lib/router.dart`, após a rota `/membros/:listaId`:

```dart
      GoRoute(
        path: '/mercado/:listaId',
        builder: (context, state) =>
            MercadoScreen(listaId: state.pathParameters['listaId']!),
      ),
```

E o import correspondente no topo.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/mercado_screen_test.dart`
Expected: PASS (4 testes; o 5º é da Task 5).

- [ ] **Step 7: Suíte completa e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

```bash
git add lib/features/listas/ui/mercado_screen.dart lib/router.dart lib/core/l10n/app_strings.dart test/features/listas/mercado_screen_test.dart
git commit -m "F22-T04: tela do modo mercado com rota dedicada (RF-18)"
```

---

### Task 5: Botão de entrada no modo mercado (gate por papel) + docs donos

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`AppBar.actions`, ~linha 255)
- Modify: `test/features/listas/tela_lista_screen_test.dart`
- Modify: `docs/05-app-flutter.md` (§3, §4, §6.3)
- Modify: `docs/10-wireframes-telas.md` (wireframe do mercado + chips)
- Modify: `docs/12-prd.md` (RF-18, RF-19 + matriz)
- Modify: `docs/14-tarefas.md` (Fase 22 + progresso)
- Modify: `docs/15-design-system.md` (só se criar/alterar componente)

**Interfaces:**
- Consumes: `MercadoScreen` (Task 4), `itensFrequentesProvider` (Task 3), `papelEfetivoProvider`.
- Produces: nada — fecha a fase.

- [ ] **Step 1: Escrever o teste que falha do gate**

Em `test/features/listas/tela_lista_screen_test.dart`:

```dart
testWidgets('deve_mostrar_botao_de_mercado_quando_pode_escrever', (
  tester,
) async {
  await listaComItens(tester, papel: Papel.dono);
  expect(find.byTooltip(AppStrings.modoMercado), findsOneWidget);
  await fechar(tester);
});

testWidgets('nao_deve_mostrar_botao_de_mercado_para_leitor', (tester) async {
  await listaComItens(tester, papel: Papel.leitor);
  expect(find.byTooltip(AppStrings.modoMercado), findsNothing);
  await fechar(tester);
});
```

> `listaComItens` já aceita `papel:` — o helper está em
> `test/features/listas/tela_lista_screen_test.dart:69`. Não criar helper novo.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL no primeiro (botão ausente).

- [ ] **Step 3: Implementar o botão**

Em `tela_lista_screen.dart`, `AppBar.actions` (antes da lupa), dentro do `data:` em que a `lista` já existe:

```dart
                if (_papelNaLista(lista.id) != Papel.leitor)
                  IconButton(
                    tooltip: AppStrings.modoMercado,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    onPressed: () => context.push('/mercado/${lista.id}'),
                  ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Atualizar os docs donos**

- `docs/05-app-flutter.md`: §3 (provider `itensFrequentesProvider`), §4 (rota `/mercado/:listaId` e botão), §6.3 (chips de sugestão e comportamento resumido do mercado).
- `docs/10-wireframes-telas.md`: wireframe do modo mercado (contador, pendentes, faixa "Marcados") e chips acima do campo.
- `docs/12-prd.md`: RF-18 e RF-19 nas tabelas §2/§6.
- `docs/14-tarefas.md`: Fase 22 com as 5 tarefas e a tabela de progresso (Total 130→135, F21 1/4 inalterada, F22 5/5 ao fim).
- `docs/15-design-system.md`: registrar `ActionChip`/faixa como uso de componente existente; só criar componente novo se o padrão do doc 15 exigir.

- [ ] **Step 6: Suíte completa, formatação e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde (≈410+ testes).

```bash
git add -A
git commit -m "F22-T05: botao do modo mercado, docs donos da Fase 22 e fechamento"
```

> **Antes do `git add -A`:** conferir `git status` para não capturar artefatos (ex.: `.firebase/`, `node_modules/`). Se aparecer algo inesperado, adicionar os arquivos por caminho explícito.

---

## Notas de execução

- **Ordem obrigatória:** Task 1 é independente; Task 2 antes da 3; Task 4 antes da 5.
- **Se o Drift reclamar de `customSelect` com `Variable.withString`:** conferir a versão do `drift` no `pubspec.yaml` — a API de `variables:` aceita `List<Variable>` no 2.x; usar `Variable<String>(listaId)` se necessário.
- **Não alterar** `supabase/`, `docs/01`, `docs/02`, `docs/03` nesta fase.
- Fechamento: rodar a suíte completa e reportar o total de testes antes de qualquer push; push só com autorização do dono.
