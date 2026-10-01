# Preço por Mercado — Fase 52 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Registrar o **mercado** (loja) de cada ida e derivar, das idas, o **preço por mercado** (último + mais barato), exibindo-o no editor do item, no detalhe da ida, nas estatísticas e num chip na lista — tudo offline.

**Architecture:** Uma coluna `mercado` (text, nullable) em `idas_compra` (Drift v12→v13); os preços por mercado são **derivados** de `itens_ida × idas_compra.mercado` no `HistoricoComprasRepository` (sem tabela nova); UI reusa providers/props existentes.

**Tech Stack:** Flutter, Riverpod, Drift/SQLite, go_router.

**Spec:** `docs/superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md` (RF-35 / Fase 52)

## Global Constraints

- App 100% local: **nenhuma** rede; **nenhuma dependência nova** nesta fase.
- Drift é a fonte da verdade; migração **v12 → v13 aditiva**; sem sync/outbox.
- Preço por mercado só considera itens **com preço** e a **mesma unidade** (regra do RF-29).
- Comparação de mercado usa `normalizarTexto` (`lib/core/texto/normalizar.dart`); exibe a caixa da primeira ocorrência.
- `App*` componentes/tokens + `AppStrings`; pt-BR; testes `deve_<resultado>_quando_<condição>`.
- Sem "undo" e sem alterar o histórico passado.

---

## File Structure

- `lib/drift/tables/ida_compra.dart` (+`mercado`) · `lib/drift/database.dart` (v13) · `database.g.dart` (regen).
- `lib/features/historico/domain/ida.dart` (`Ida.mercado`) · `lib/features/historico/domain/mercado.dart` (`PrecoMercado`, `GastoPorMercado`).
- `lib/features/historico/data/historico_compras_repository.dart` (`finalizar(...,{mercado})`, `mercadosUsados`, `precosPorMercado`, `gastoPorMercado`).
- `lib/features/historico/providers/historico_providers.dart` (novos providers).
- `lib/features/historico/ui/modal_finalizar_compra.dart` (campo Mercado) · `ida_detalhe_screen.dart` (rótulo) · `estatisticas_tab.dart` (seção).
- `lib/features/listas/ui/tela_lista_screen.dart` (chip + linha "Por mercado" no editor).
- `lib/features/backup/data/backup_repository.dart` (exportar/importar `mercado`).
- `lib/core/l10n/app_strings.dart`.
- Modificados/testes conforme cada task.

---

## Task 1: Drift v13 (`mercado`) + domínio + `finalizar` + backup

**Files:**
- Modify: `lib/drift/tables/ida_compra.dart`, `lib/drift/database.dart` (regen `database.g.dart`)
- Modify: `lib/features/historico/domain/ida.dart`, `lib/features/historico/data/historico_compras_repository.dart`
- Modify: `lib/features/backup/data/backup_repository.dart`
- Test: `test/features/historico/ida_mercado_test.dart`, `test/drift/database_test.dart` (novo caso), `test/features/backup/backup_historico_test.dart` (ajuste)

**Interfaces:**
- Consumes: `AppDatabase`, `Ida`/`IdaCompraCompanion`, `normalizarTexto`.
- Produces: `Ida.mercado` (`String?`); `finalizar(String listaId, {String? mercado})`; `idas_compra.mercado`.

- [ ] **Step 1: Write the failing test**

`test/features/historico/ida_mercado_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late HistoricoComprasRepository historico;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    historico = HistoricoComprasRepository(db);
  });
  tearDown(() => db.close());

  Future<String> listaComConcluido() async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final i = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(i.id, concluido: true);
    return l.id;
  }

  test('deve_gravar_mercado_quando_finaliza_com_mercado', () async {
    final id = await listaComConcluido();
    final ida = await historico.finalizar(id, mercado: 'Mercado A');
    expect(ida.mercado, 'Mercado A');
    final lido = await historico.ida(ida.id);
    expect(lido!.mercado, 'Mercado A');
  });

  test('deve_deixar_mercado_nulo_quando_nao_informado', () async {
    final id = await listaComConcluido();
    final ida = await historico.finalizar(id);
    expect(ida.mercado, isNull);
  });
}
```

Adicionar em `test/drift/database_test.dart` (padrão do arquivo) um caso `deve_adicionar_mercado_quando_migrar_v12_para_v13` que cria um DB v12 (sem a coluna), abre (roda a migração) e insere/lê `ida_compra` com `mercado`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/ida_mercado_test.dart`
Expected: FAIL — `mercado` inexistente.

- [ ] **Step 3: Implement model/migration/repo/backup**

`lib/drift/tables/ida_compra.dart` — adicionar:

```dart
  TextColumn get mercado => text().nullable()();
```

`lib/drift/database.dart` — `schemaVersion => 13` e, no `onUpgrade` (append):

```dart
      if (de < 13) {
        // v12 → v13: mercado (loja) da ida (RF-35, F52).
        await m.addColumn(idaCompra, idaCompra.mercado);
      }
```

`lib/features/historico/domain/ida.dart` — `Ida` ganha `final String? mercado;` (parâmetro opcional) e `mercado: d.mercado` no `fromLocal`.

`lib/features/historico/data/historico_compras_repository.dart` — `finalizar`:

```dart
  Future<Ida> finalizar(String listaId, {String? mercado}) {
    return _db.transaction(() async {
      // ... igual ...
      final mercadoLimpo = (mercado ?? '').trim();
      await _db.into(_db.idaCompra).insert(
            IdaCompraCompanion.insert(
              id: idaId, listaId: Value(listaId), titulo: lista.titulo,
              finalizadaEm: agora, totalCentavos: Value(total),
              itensCount: Value(concluidos.length),
              mercado: Value(mercadoLimpo.isEmpty ? null : mercadoLimpo),
            ),
          );
      // ... itens ...
      return Ida(
        id: idaId, listaId: listaId, titulo: lista.titulo,
        finalizadaEm: agora, totalCentavos: total,
        itensCount: concluidos.length,
        mercado: mercadoLimpo.isEmpty ? null : mercadoLimpo,
      );
    });
  }
```

`lib/features/backup/data/backup_repository.dart` — no map de `idas`, acrescentar `'mercado': i.mercado`; no import, `mercado: Value(l['mercado'] as String?)`. **Sem** bump de versão (a v2 continua válida; backup antigo importa com `null`).

- [ ] **Step 4: Regenerate and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/features/historico/ida_mercado_test.dart && flutter test test/drift/database_test.dart test/features/backup`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/drift lib/features/historico lib/features/backup test
git commit -m "feat(mercado): mercado na ida e migracao v13 (RF-35, F52)"
```

---

## Task 2: Consultas derivadas (mercados, preço por mercado, gasto por mercado)

**Files:**
- Create: `lib/features/historico/domain/mercado.dart`
- Modify: `lib/features/historico/data/historico_compras_repository.dart`
- Modify: `lib/features/historico/providers/historico_providers.dart`
- Test: `test/features/historico/mercado_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `normalizarTexto`, `Unidade`.
- Produces: `PrecoMercado({mercado, precoCentavos, data})`, `GastoPorMercado({mercado, totalCentavos})`; `Future<List<String>> mercadosUsados()`; `Future<List<PrecoMercado>> precosPorMercado(String nomeNormalizado, Unidade unidade)`; `Future<List<GastoPorMercado>> gastoPorMercado()`; providers `mercadosUsadosProvider`, `precosPorMercadoProvider`, `gastoPorMercadoProvider`.

- [ ] **Step 1: Write the failing test**

`test/features/historico/mercado_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late HistoricoComprasRepository historico;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    historico = HistoricoComprasRepository(db);
  });
  tearDown(() => db.close());

  Future<void> ida(String mercado, List<(String, int, Unidade)> itens) async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    for (final (nome, preco, un) in itens) {
      final i = await listas.adicionarItem(
        listaId: l.id, nome: nome, unidade: un, precoCentavos: preco);
      await listas.editarItem(i.id, concluido: true);
    }
    await historico.finalizar(l.id, mercado: mercado);
  }

  test('deve_listar_mercados_usados_sem_repetir', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('mercado a', [('Arroz', 600, Unidade.kg)]);
    await ida('Mercado B', [('Leite', 400, Unidade.l)]);
    expect(await historico.mercadosUsados(), ['Mercado A', 'Mercado B']);
  });

  test('deve_derivar_ultimo_preco_por_mercado_quando_ha_compras', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado A', [('Arroz', 550, Unidade.kg)]);
    await ida('Mercado B', [('Arroz', 700, Unidade.kg)]);
    final precos = await historico.precosPorMercado('arroz', Unidade.kg);
    expect(precos.map((p) => p.mercado), ['Mercado A', 'Mercado B']);
    expect(precos.first.precoCentavos, 550); // último do A
    expect(precos.last.precoCentavos, 700);
  });

  test('deve_ignorar_outra_unidade_quando_deriva_preco', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado B', [('Arroz', 900, Unidade.un)]);
    final precos = await historico.precosPorMercado('arroz', Unidade.kg);
    expect(precos.map((p) => p.mercado), ['Mercado A']);
  });

  test('deve_agrupar_gasto_por_mercado_incluindo_sem_mercado', () async {
    await ida('Mercado A', [('Arroz', 500, Unidade.kg)]);
    await ida('Mercado B', [('Leite', 400, Unidade.l)]);
    await ida('', [('Pao', 300, Unidade.un)]);
    final gasto = await historico.gastoPorMercado();
    expect(gasto.firstWhere((g) => g.mercado == 'Mercado A').totalCentavos, 500);
    expect(gasto.firstWhere((g) => g.mercado == null).totalCentavos, 300);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/mercado_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement domain, queries and providers**

`lib/features/historico/domain/mercado.dart`:

```dart
class PrecoMercado {
  const PrecoMercado({
    required this.mercado, required this.precoCentavos, required this.data,
  });
  final String mercado;
  final int precoCentavos;
  final DateTime data;
}

class GastoPorMercado {
  const GastoPorMercado({required this.mercado, required this.totalCentavos});
  final String? mercado;
  final int totalCentavos;
}
```

No repositório (deriva das idas):

```dart
  Future<List<String>> mercadosUsados() async {
    final idas = await _db.select(_db.idaCompra).get();
    final vistos = <String, String>{}; // normalizado -> exibição
    for (final i in idas) {
      final m = i.mercado;
      if (m == null || m.trim().isEmpty) continue;
      vistos.putIfAbsent(normalizarTexto(m), () => m);
    }
    final lista = vistos.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lista;
  }

  Future<List<PrecoMercado>> precosPorMercado(
    String nomeNormalizado,
    Unidade unidade,
  ) async {
    final linhas = await _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ]).get();
    // Último preço por mercado (normalizado), só mesma unidade e com preço.
    final porMercado = <String, PrecoMercado>{};
    final exibicao = <String, String>{};
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      final ida = linha.readTable(_db.idaCompra);
      final m = ida.mercado;
      if (m == null || m.trim().isEmpty) continue;
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      if (i.unidade != unidade.valor) continue;
      final preco = i.precoCentavos;
      if (preco == null) continue;
      final chave = normalizarTexto(m);
      exibicao.putIfAbsent(chave, () => m);
      final atual = porMercado[chave];
      if (atual == null || ida.finalizadaEm.isAfter(atual.data)) {
        porMercado[chave] =
            PrecoMercado(mercado: m, precoCentavos: preco, data: ida.finalizadaEm);
      }
    }
    final lista = porMercado.values.toList()
      ..sort((a, b) => a.precoCentavos.compareTo(b.precoCentavos));
    return lista;
  }

  Future<List<GastoPorMercado>> gastoPorMercado() async {
    final idas = await _db.select(_db.idaCompra).get();
    final mapa = <String?, int>{};
    for (final i in idas) {
      final m = (i.mercado == null || i.mercado!.trim().isEmpty) ? null : i.mercado;
      mapa[m] = (mapa[m] ?? 0) + i.totalCentavos;
    }
    final lista = [
      for (final e in mapa.entries)
        GastoPorMercado(mercado: e.key, totalCentavos: e.value),
    ]..sort((a, b) => b.totalCentavos.compareTo(a.totalCentavos));
    return lista;
  }
```

Providers (derivar de `idasProvider` como as demais estatísticas):

```dart
final mercadosUsadosProvider = FutureProvider<List<String>>((ref) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).mercadosUsados();
});

final precosPorMercadoProvider =
    FutureProvider.family<List<PrecoMercado>, (String, Unidade)>((ref, args) {
  ref.watch(idasProvider);
  return ref
      .watch(historicoComprasRepositoryProvider)
      .precosPorMercado(args.$1, args.$2);
});

final gastoPorMercadoProvider = FutureProvider<List<GastoPorMercado>>((ref) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).gastoPorMercado();
});
```

- [ ] **Step 4: Run test, format and analyze**

Run: `flutter test test/features/historico/mercado_repository_test.dart && dart format . && flutter analyze`
Expected: PASS e analyze limpo.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico test/features/historico
git commit -m "feat(mercado): consultas de preco e gasto por mercado (RF-35, F52)"
```

---

## Task 3: UI do mercado (finalizar + editor + detalhe + chip)

**Files:**
- Modify: `lib/features/historico/ui/modal_finalizar_compra.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Modify: `lib/features/historico/ui/ida_detalhe_screen.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/historico/finalizar_mercado_test.dart`, `test/features/listas/tela_lista_mercado_test.dart`

**Interfaces:**
- Consumes: `mercadosUsadosProvider`, `precosPorMercadoProvider`, `idasProvider`, `finalizar({mercado})`.
- Produces: `abrirFinalizarCompra(context, ref, listaId)` com campo Mercado; linha "Por mercado" no editor; rótulo no detalhe; chip na lista.

- [ ] **Step 1: Add strings**

```dart
  // Mercado da compra (RF-35, F52)
  static const mercado = 'Mercado';
  static const mercadoOpcional = 'Mercado (opcional)';
  static const porMercado = 'Por mercado';
  static const maisBarato = 'mais barato';
  static const gastoPorMercado = 'Gasto por mercado';
  static const semMercado = 'Sem mercado';
  static const mercadosSugeridos = 'Mercados usados';
```

- [ ] **Step 2: Write failing tests**

`test/features/historico/finalizar_mercado_test.dart` — abre `abrirFinalizarCompra`, digita no campo "Mercado (opcional)" o valor `Mercado A`, confirma, e assertion: a ida gravada tem `mercado == 'Mercado A'` e o item foi registrado. (Reuse o padrão de `finalizar_compra_test.dart`, incluindo o `fechar(tester)`.)

`test/features/listas/tela_lista_mercado_test.dart` — renderiza a lista com uma ida finalizada de `Mercado A` e asserta o chip "Mercado A" na tela; sem ida → chip ausente.

- [ ] **Step 3: Implement UI**

`modal_finalizar_compra.dart`: transformar o diálogo de confirmação em um `StatefulWidget` com o resumo **e** um `AppCampoTexto(label: AppStrings.mercadoOpcional)`; abaixo, chips de sugestão (`mercadosUsadosProvider`) que preenchem o campo. Retornar `(confirmar, mercado)`; repassar a `finalizar(listaId, mercado: mercado)`.

`tela_lista_screen.dart`:
- No `_SheetEditarItem`, abaixo de `_linhaHistoricoPreco`, adicionar `_linhaPorMercado` que observa `precosPorMercadoProvider((normalizarTexto(nome), _unidade))` e mostra cada mercado com o preço, destacando o **mais barato** (`AppStrings.maisBarato`). Oculta quando a lista está vazia.
- No topo do corpo da lista, um `Chip`/`ActionChip` com o mercado da **última ida** da lista: derive de `idasProvider` (`where listaId`, o mais recente) — sem query nova. Oculto se não houver mercado.

`ida_detalhe_screen.dart`: quando `ida.mercado != null`, mostrar o mercado (ex.: no `AppBar` `bottom`/subtítulo ou como primeiro item com ícone de loja).

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/historico/finalizar_mercado_test.dart test/features/listas/tela_lista_mercado_test.dart && dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/ui lib/features/listas/ui lib/core/l10n/app_strings.dart test
git commit -m "feat(mercado): finalizar com mercado, por mercado no editor e chip (RF-35, F52)"
```

---

## Task 4: Estatísticas "Gasto por mercado"

**Files:**
- Modify: `lib/features/historico/ui/estatisticas_tab.dart`
- Test: `test/features/historico/estatisticas_mercado_test.dart`

**Interfaces:**
- Consumes: `gastoPorMercadoProvider`, `formatarReais`, `AppStrings`.
- Produces: seção `_SecaoGastoPorMercado` na `EstatisticasTab`.

- [ ] **Step 1: Write the failing widget test**

`test/features/historico/estatisticas_mercado_test.dart`: com uma ida de `Mercado A` (R$5,00) e uma sem mercado, após abrir a aba Estatísticas, asserta que aparece `Gasto por mercado` e o valor `R$ 5,00` associado a `Mercado A`, e `Sem mercado` para a outra. (Reuse o harness de `estatisticas_tab_test.dart`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/estatisticas_mercado_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the section**

Em `estatisticas_tab.dart`, adicionar em `build` (entre as seções):
```dart
        const AppCabecalhoSecao(AppStrings.gastoPorMercado),
        const _SecaoGastoPorMercado(),
```
E o widget (mesmo padrão de `_SecaoGastoPorCategoria`), usando `gastoPorMercadoProvider`, mostrando `mercado ?? AppStrings.semMercado` e `formatarReais(totalCentavos)`, com `_SemDados` quando vazio.

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/historico/estatisticas_mercado_test.dart && dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/ui/estatisticas_tab.dart test/features/historico
git commit -m "feat(mercado): estatisticas de gasto por mercado (RF-35, F52)"
```

---

## Task 5: Docs donos e fechamento da Fase 52

**Files:**
- Modify: `docs/12-prd.md` (RF-35 + matriz)
- Modify: `docs/05-app-flutter.md` (§6.14 mercado; tabelas/migração v13)
- Modify: `docs/10-wireframes-telas.md` (campo Mercado; "Por mercado"; chip; "Gasto por mercado")
- Modify: `docs/14-tarefas.md` (Fase 52 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (frente; F53 pendente)

- [ ] **Step 1: PRD e doc 05**

- `docs/12-prd.md`: **RF-35** na tabela + matriz (F52), e ajustar "fora de escopo" (preço por mercado deixa de ser fora).
- `docs/05-app-flutter.md`: nova seção (próximo número após §6.13 → §6.14) com: `mercado` na ida (migração v13), preços derivados, `finalizar({mercado})`, queries/providers, e onde aparece (editor/detalhe/estatísticas/chip). Atualizar a árvore/tabelas.

- [ ] **Step 2: 10/14/16**

- `docs/10-wireframes-telas.md`: wireframes do campo Mercado no finalizar, da linha "Por mercado" no editor, do chip na lista e da seção "Gasto por mercado".
- `docs/14-tarefas.md`: `## Fase 52 — Preço por mercado (RF-35)` com F52-T01…T05; atualizar a tabela de progresso (somar a fase; Total atual 279/277 → +5).
- `docs/16-roadmap-pos-mvp.md`: registrar a frente RF-35 (F52) e deixar RF-36 (F53) pendente.

- [ ] **Step 3: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs(mercado): RF-35, 05, 10, 14 e 16 (F52)"
```

---

## Self-Review (cobertura da spec §3/§5 — Fase 52)

- §3 migração v13 (`mercado`) → Task 1.
- §4/§5 preços derivados, `finalizar(mercado)`, editor "Por mercado", detalhe, chip → Tasks 1/2/3.
- §5 estatísticas "Gasto por mercado" → Task 4.
- §9 testes (repo + widget) → Tasks 1–4.
- **Fora desta fase:** RF-36 alertas de orçamento (Fase 53).

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md`
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
