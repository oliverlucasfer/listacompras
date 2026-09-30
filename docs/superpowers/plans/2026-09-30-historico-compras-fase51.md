# Histórico de Compras — Fase 51 (estatísticas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sobre as idas já registradas (Fase 50), mostrar estatísticas locais: gasto por período (gráfico), gasto por categoria, itens mais comprados e evolução de preço por item.

**Architecture:** Consultas de agregação no `HistoricoComprasRepository` (lendo `idas_compra`/`itens_ida`) + funções puras de agrupamento no domínio; uma aba "Estatísticas" ao lado de "Idas" no `HistoricoScreen`; gráfico de barras com `fl_chart`. Tudo offline.

**Tech Stack:** Flutter, Riverpod, Drift/SQLite, `fl_chart` (puro Dart).

**Spec:** `docs/superpowers/specs/2026-09-30-historico-compras-design.md` (§6)

## Global Constraints

- App 100% local: **nenhuma** rede; a única dependência nova é **`fl_chart`** (offline).
- Só itens **com preço** entram nos valores monetários (`quantidade × preço`, subtotal arredondado) — mesma regra do `totalCarrinho` (`lib/features/listas/domain/preco.dart:52`).
- Categorias e unidades: enums fechados (`CategoriaItem`, `Unidade`) — usar `rotulo`/`valor`/`fromValor`.
- **Evolução de preço** só compara a **mesma unidade** (regra do RF-29).
- Período do gráfico: **últimos 12 meses** (mês corrente + 11 anteriores); "Itens mais comprados": **top 10** por frequência.
- Estados vazios explicativos; `App*` componentes/tokens; pt-BR; testes `deve_<resultado>_quando_<condição>`.

---

## File Structure

- `lib/features/historico/domain/estatisticas.dart` — `GastoPorMes`, `GastoPorCategoria`, `ItemFrequente`, `PontoPreco`, `ResumoEstatisticas` + funções puras.
- `lib/features/historico/data/historico_compras_repository.dart` — novos métodos de agregação (modificar).
- `lib/features/historico/providers/historico_providers.dart` — providers de estatística (modificar).
- `lib/features/historico/ui/grafico_gasto_mensal.dart` — gráfico de barras (`fl_chart`).
- `lib/features/historico/ui/estatisticas_tab.dart` — as 4 visões.
- `lib/features/historico/ui/historico_screen.dart` — `TabBar` Idas/Estatísticas (modificar).
- Modificados: `pubspec.yaml`, `lib/core/l10n/app_strings.dart`, docs.

---

## Task 1: Domínio e agregações no repositório

**Files:**
- Create: `lib/features/historico/domain/estatisticas.dart`
- Modify: `lib/features/historico/data/historico_compras_repository.dart`
- Test: `test/features/historico/estatisticas_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `idaCompra`/`itemIda` (F50), `normalizarTexto` (`lib/core/texto/normalizar.dart`), `CategoriaItem`/`Unidade`.
- Produces: tipos de `estatisticas.dart` e métodos `Future<List<GastoPorMes>> gastoPorMes()`, `Future<List<GastoPorCategoria>> gastoPorCategoria()`, `Future<List<ItemFrequente>> itensMaisComprados({int limite = 10})`, `Future<List<String>> nomesComprados()`, `Future<List<PontoPreco>> evolucaoPreco(String nomeNormalizado, Unidade unidade)`, `Future<Unidade?> unidadeRecenteComprada(String nomeNormalizado)`.

- [ ] **Step 1: Write the failing test**

`test/features/historico/estatisticas_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
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

  Future<void> idaCom(List<(String, double, Unidade, CategoriaItem, int?)> itens) async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    for (final (nome, qtd, un, cat, preco) in itens) {
      final i = await listas.adicionarItem(
        listaId: l.id, nome: nome, quantidade: qtd,
        unidade: un, categoria: cat, precoCentavos: preco,
      );
      await listas.editarItem(i.id, concluido: true);
    }
    await historico.finalizar(l.id);
  }

  test('deve_somar_gasto_por_categoria_quando_ha_precos', () async {
    await idaCom([
      ('Arroz', 2, Unidade.kg, CategoriaItem.mercearia, 500),
      ('Queijo', 1, Unidade.un, CategoriaItem.frios, 1200),
      ('Sem preço', 1, Unidade.un, CategoriaItem.frios, null),
    ]);
    final porCategoria = await historico.gastoPorCategoria();
    final frios = porCategoria.firstWhere((g) => g.categoria == CategoriaItem.frios);
    expect(frios.totalCentavos, 1200); // 'Sem preço' não soma
    final mercearia = porCategoria.firstWhere((g) => g.categoria == CategoriaItem.mercearia);
    expect(mercearia.totalCentavos, 1000);
  });

  test('deve_contar_itens_mais_comprados_por_nome_normalizado', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('arroz', 3, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Leite', 1, Unidade.l, CategoriaItem.laticinios, 400)]);
    final top = await historico.itensMaisComprados();
    expect(top.first.nome.toLowerCase(), 'arroz');
    expect(top.first.vezes, 2);
  });

  test('deve_serie_de_evolucao_somente_mesma_unidade', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 600)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, 900)]);
    final serie = await historico.evolucaoPreco('arroz', Unidade.kg);
    expect(serie.map((p) => p.precoCentavos), [500, 600]);
    expect(serie.map((p) => p.unidade).toSet(), {Unidade.kg});
  });

  test('deve_agrupar_gasto_por_mes', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Leite', 1, Unidade.l, CategoriaItem.laticinios, 400)]);
    final porMes = await historico.gastoPorMes();
    expect(porMes, hasLength(1)); // ambas as idas no mês corrente
    expect(porMes.single.totalCentavos, 900);
  });

  test('deve_listar_nomes_comprados_uma_vez_quando_repete', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    expect(await historico.nomesComprados(), ['arroz']);
  });

  test('deve_retornar_unidade_mais_recente_quando_ha_compras', () async {
    await idaCom([('Arroz', 1, Unidade.kg, CategoriaItem.mercearia, 500)]);
    await idaCom([('Arroz', 1, Unidade.un, CategoriaItem.mercearia, 900)]);
    expect(await historico.unidadeRecenteComprada('arroz'), Unidade.un);
    expect(await historico.unidadeRecenteComprada('inexistente'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/estatisticas_repository_test.dart`
Expected: FAIL — tipos/métodos inexistentes.

- [ ] **Step 3: Implement domain + repository**

`lib/features/historico/domain/estatisticas.dart`:

```dart
import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';

class GastoPorMes {
  const GastoPorMes({required this.mes, required this.totalCentavos});
  final DateTime mes; // primeiro dia do mês (UTC)
  final int totalCentavos;
}

class GastoPorCategoria {
  const GastoPorCategoria({required this.categoria, required this.totalCentavos});
  final CategoriaItem categoria;
  final int totalCentavos;
}

class ItemFrequente {
  const ItemFrequente({required this.nome, required this.vezes, required this.totalCentavos});
  final String nome;
  final int vezes;
  final int totalCentavos;
}

class PontoPreco {
  const PontoPreco({required this.data, required this.precoCentavos, required this.unidade});
  final DateTime data;
  final int precoCentavos;
  final Unidade unidade;
}
```

No repositório, adicionar (tudo local; agrupa em Dart):

```dart
  Future<List<GastoPorMes>> gastoPorMes() async {
    final idas = await _db.select(_db.idaCompra).get();
    final mapa = <String, int>{};
    final meses = <String, DateTime>{};
    for (final i in idas) {
      final m = DateTime.utc(i.finalizadaEm.year, i.finalizadaEm.month, 1);
      final chave = '${m.year}-${m.month}';
      mapa[chave] = (mapa[chave] ?? 0) + i.totalCentavos;
      meses[chave] = m;
    }
    final lista = [
      for (final e in mapa.entries)
        GastoPorMes(mes: meses[e.key]!, totalCentavos: e.value),
    ]..sort((a, b) => a.mes.compareTo(b.mes));
    return lista;
  }

  Future<List<GastoPorCategoria>> gastoPorCategoria() async {
    final itens = await _db.select(_db.itemIda).get();
    final mapa = <String, int>{};
    for (final i in itens) {
      final preco = i.precoCentavos;
      if (preco == null) continue;
      final subtotal = (i.quantidade * preco).round();
      mapa[i.categoria] = (mapa[i.categoria] ?? 0) + subtotal;
    }
    final lista = [
      for (final e in mapa.entries)
        GastoPorCategoria(
          categoria: CategoriaItem.fromValor(e.key),
          totalCentavos: e.value,
        ),
    ]..sort((a, b) => b.totalCentavos.compareTo(a.totalCentavos));
    return lista;
  }

  Future<List<ItemFrequente>> itensMaisComprados({int limite = 10}) async {
    final itens = await _db.select(_db.itemIda).get();
    final vezes = <String, int>{};
    final totais = <String, int>{};
    final nomes = <String, String>{};
    for (final i in itens) {
      final chave = normalizarTexto(i.nome);
      nomes.putIfAbsent(chave, () => i.nome);
      vezes[chave] = (vezes[chave] ?? 0) + 1;
      final preco = i.precoCentavos;
      if (preco != null) {
        totais[chave] = (totais[chave] ?? 0) + (i.quantidade * preco).round();
      }
    }
    final lista = [
      for (final chave in vezes.keys)
        ItemFrequente(
          nome: nomes[chave]!, vezes: vezes[chave]!,
          totalCentavos: totais[chave] ?? 0,
        ),
    ]..sort((a, b) {
        final c = b.vezes.compareTo(a.vezes);
        return c != 0 ? c : a.nome.compareTo(b.nome);
      });
    return lista.take(limite).toList();
  }

  Future<List<String>> nomesComprados() async {
    final itens = await _db.select(_db.itemIda).get();
    final chaves = {for (final i in itens) normalizarTexto(i.nome)};
    final lista = chaves.toList()..sort();
    return lista;
  }

  Future<List<PontoPreco>> evolucaoPreco(String nomeNormalizado, Unidade unidade) async {
    final consulta = _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ]);
    final linhas = await consulta.get();
    final pontos = <PontoPreco>[];
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      final ida = linha.readTable(_db.idaCompra);
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      if (i.unidade != unidade.valor) continue;
      final preco = i.precoCentavos;
      if (preco == null) continue;
      pontos.add(PontoPreco(data: ida.finalizadaEm, precoCentavos: preco, unidade: unidade));
    }
    pontos.sort((a, b) => a.data.compareTo(b.data));
    return pontos;
  }

  Future<Unidade?> unidadeRecenteComprada(String nomeNormalizado) async {
    final consulta = _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ]);
    final linhas = await consulta.get();
    final pontos = <(DateTime, String)>[];
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      pontos.add((linha.readTable(_db.idaCompra).finalizadaEm, i.unidade));
    }
    if (pontos.isEmpty) return null;
    pontos.sort((a, b) => a.$1.compareTo(b.$1));
    return Unidade.fromValor(pontos.last.$2);
  }
```

Adicionar `import '../../../core/texto/normalizar.dart';` e `import '../../../core/dominio/categoria.dart';`/`unidade.dart` conforme necessário.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/historico/estatisticas_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/domain lib/features/historico/data test/features/historico
git commit -m "feat(historico): agregacoes de estatisticas (RF-34, F51)"
```

---

## Task 2: Gráfico de gasto mensal (`fl_chart`)

**Files:**
- Modify: `pubspec.yaml` (add `fl_chart` via `flutter pub add fl_chart`)
- Create: `lib/features/historico/ui/grafico_gasto_mensal.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/historico/grafico_gasto_mensal_test.dart`

**Interfaces:**
- Consumes: `List<GastoPorMes>` (Task 1), `formatarReais`.
- Produces: `GraficoGastoMensal({required List<GastoPorMes> dados})` — barras por mês (últimos 12 meses) com rótulos `MM/yy` e valor no topo; estado vazio quando não há dados.

- [ ] **Step 1: Add dependency**

Run: `flutter pub add fl_chart`
Expected: `pubspec.yaml` com `fl_chart`; `flutter pub get` OK.

- [ ] **Step 2: Write the failing widget test**

`test/features/historico/grafico_gasto_mensal_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/historico/domain/estatisticas.dart';
import 'package:lista_compras/features/historico/ui/grafico_gasto_mensal.dart';

void main() {
  testWidgets('deve_renderizar_barras_quando_ha_dados', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraficoGastoMensal(dados: [
          GastoPorMes(mes: DateTime.utc(2026, 8, 1), totalCentavos: 5000),
          GastoPorMes(mes: DateTime.utc(2026, 9, 1), totalCentavos: 7000),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('deve_mostrar_vazio_quando_sem_dados', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: GraficoGastoMensal(dados: [])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sem dados ainda.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Add strings and implement the chart**

Strings (junto do bloco histórico):

```dart
  static const estatisticas = 'Estatísticas';
  static const abaIdas = 'Idas';
  static const gastoPorPeriodo = 'Gasto por período';
  static const gastoPorCategoria = 'Gasto por categoria';
  static const itensMaisComprados = 'Itens mais comprados';
  static const evolucaoDePreco = 'Evolução de preço';
  static const semDadosAinda = 'Sem dados ainda.';
```

`grafico_gasto_mensal.dart`: `StatelessWidget` que, sem dados, retorna `Text(AppStrings.semDadosAinda)`; com dados, `SizedBox(height: 200, child: BarChart(BarChartData(...)))`, uma barra por `GastoPorMes`, eixo X com `MM/yy` (helper local), `tooltip`/rótulo com `formatarReais`. Guia de implementação: consulte a API da versão resolvida de `fl_chart` (`flutter pub add` mostra a versão) e ajuste os nomes de API (`BarChartGroupData`, `BarChartRodData`, `titlesData`) para compilar.

- [ ] **Step 4: Run test, format and analyze**

Run: `flutter test test/features/historico/grafico_gasto_mensal_test.dart && dart format . && flutter analyze`
Expected: PASS e analyze limpo.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/historico/ui/grafico_gasto_mensal.dart lib/core/l10n/app_strings.dart test/features/historico
git commit -m "feat(historico): grafico de gasto mensal (RF-34, F51)"
```

---

## Task 3: Aba Estatísticas (Idas × Estatísticas)

**Files:**
- Create: `lib/features/historico/ui/estatisticas_tab.dart`
- Modify: `lib/features/historico/ui/historico_screen.dart`
- Modify: `lib/features/historico/providers/historico_providers.dart`
- Test: `test/features/historico/estatisticas_tab_test.dart`

**Interfaces:**
- Consumes: métodos de Task 1; `GraficoGastoMensal` (Task 2); `formatarReais`; `CategoriaItem.rotulo`.
- Produces: `EstatisticasTab` (as 4 visões) e providers `gastoPorMesProvider`, `gastoPorCategoriaProvider`, `itensMaisCompradosProvider`, `nomesCompradosProvider`, `evolucaoPrecoProvider((nome, unidade))`; `HistoricoScreen` com `TabBar` (Idas | Estatísticas).

- [ ] **Step 1: Write the failing widget test**

`test/features/historico/estatisticas_tab_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  testWidgets('deve_mostrar_estatisticas_quando_ha_idas', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final i = await listas.adicionarItem(
      listaId: l.id, nome: 'Arroz', quantidade: 2,
      unidade: Unidade.kg, categoria: CategoriaItem.mercearia,
      precoCentavos: 500,
    );
    await listas.editarItem(i.id, concluido: true);
    await historico.finalizar(l.id);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HistoricoScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Gasto por categoria'), findsOneWidget);
    expect(find.text('Itens mais comprados'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/estatisticas_tab_test.dart`
Expected: FAIL — sem TabBar/aba.

- [ ] **Step 3: Implement providers, tab and screen**

Providers (usando `FutureProvider`, derivando de `idasProvider` quando fizer sentido para reatividade — invalide/derive de forma que uma nova ida atualize as estatísticas):

```dart
final gastoPorMesProvider = FutureProvider<List<GastoPorMes>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).gastoPorMes(),
);
final gastoPorCategoriaProvider = FutureProvider<List<GastoPorCategoria>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).gastoPorCategoria(),
);
final itensMaisCompradosProvider = FutureProvider<List<ItemFrequente>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).itensMaisComprados(),
);
final nomesCompradosProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).nomesComprados(),
);
final evolucaoPrecoProvider = FutureProvider.family<List<PontoPreco>, (String, Unidade)>(
  (ref, args) => ref.watch(historicoComprasRepositoryProvider).evolucaoPreco(args.$1, args.$2),
);
```

> **Reatividade:** como em F50 o resumo passou a derivar de `idasProvider`, faça os providers de estatística observarem `idasProvider` (`ref.watch(idasProvider)`) e só então chamar o repositório, para que uma nova ida atualize as estatísticas sem invalidar manualmente.

`estatisticas_tab.dart`: `ListView` com seções (títulos via `AppStrings`): **Gasto por período** (usa `GraficoGastoMensal`), **Gasto por categoria** (lista com `categoria.rotulo` + `formatarReais` + %), **Itens mais comprados** (lista `nome · Nx · total`), **Evolução de preço** (dropdown de `nomesCompradosProvider`; ao escolher, mostra a série de `evolucaoPrecoProvider` da **unidade do item selecionado** — use a unidade do último ponto; lista `dd/MM/yyyy · R$` + mini gráfico). Cada seção com estado vazio (`AppStrings.semDadosAinda`) e loading (`AppEsqueleto`).

`historico_screen.dart`: envolver o corpo em `DefaultTabController(length: 2)` com `TabBar` (`AppStrings.abaIdas`, `AppStrings.estatisticas`) e `TabBarView`: aba 1 = conteúdo atual (resumo + lista); aba 2 = `EstatisticasTab()`.

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/historico/estatisticas_tab_test.dart && dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico test/features/historico
git commit -m "feat(historico): aba de estatisticas (RF-34, F51)"
```

---

## Task 4: Docs donos e fechamento da Fase 51

**Files:**
- Modify: `docs/12-prd.md` (RF-34 aceite/fases)
- Modify: `docs/05-app-flutter.md` (§6.13: estatísticas; dependência `fl_chart`)
- Modify: `docs/10-wireframes-telas.md` (§8: aba Estatísticas)
- Modify: `docs/09-runbook-operacoes.md` (dependência `fl_chart`, offline)
- Modify: `docs/14-tarefas.md` (Fase 51 T01–T04 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (frente RF-34 concluída)

- [ ] **Step 1: 12/05/09**

- `docs/12-prd.md`: RF-34 já existe; ajustar a rastreabilidade para incluir as tarefas da Fase 51 (F51-T01…T04).
- `docs/05-app-flutter.md` §6.13: documentar as estatísticas (gasto por período/categoria, mais comprados, evolução de preço), a aba Idas/Estatísticas, os providers e a dependência `fl_chart`.
- `docs/09-runbook-operacoes.md`: registrar `fl_chart` como dependência local (offline).

- [ ] **Step 2: 10/14/16**

- `docs/10-wireframes-telas.md` §8: wireframe da aba Estatísticas (gráfico + categoria + mais comprados + evolução).
- `docs/14-tarefas.md`: `## Fase 51 — Histórico: estatísticas (RF-34)` com F51-T01…T04 (marcadas) e a tabela de progresso (somar a fase). Ajustar o Total.
- `docs/16-roadmap-pos-mvp.md`: frente A9 marcada como concluída (F50+F51).

- [ ] **Step 3: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs(historico): estatisticas RF-34 F51 (05, 09, 10, 12, 14, 16)"
```

---

## Self-Review (cobertura da spec §6)

- Gasto por período (gráfico) → Tasks 1/2/3.
- Gasto por categoria → Tasks 1/3.
- Itens mais comprados → Tasks 1/3.
- Evolução de preço por item (mesma unidade) → Tasks 1/3.
- Ticket médio/total geral → já no resumo (F50), reafirmado.
- Estados vazios → Tasks 2/3.

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-historico-compras-design.md` (§6)
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
