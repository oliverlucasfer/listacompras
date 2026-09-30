# Histórico de Compras — Fase 50 (registrar idas + histórico) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Registrar "idas" de compra (snapshot dos itens concluídos) ao finalizar a compra, e oferecer uma aba Histórico com resumo, lista de idas e detalhe — tudo 100% offline.

**Architecture:** Duas tabelas Drift novas (`idas_compra`, `itens_ida`) como snapshots imutáveis; um `HistoricoComprasRepository` que grava a ida numa transação e faz as consultas; uma ação "Finalizar compra" na tela da lista; e uma nova aba `/historico` no shell com detalhe `/historico/ida/:id`. As estatísticas (gráficos) ficam para a Fase 51.

**Tech Stack:** Flutter, Riverpod, Drift/SQLite, go_router.

**Spec:** `docs/superpowers/specs/2026-09-30-historico-compras-design.md`

## Global Constraints

- App 100% local: **nenhuma** rede; sem fila/sync/outbox (não existem). Nenhuma dependência nova nesta fase (`fl_chart` só na Fase 51).
- `Drift` é a fonte da verdade; IDs são **UUID v4 no cliente** (`Uuid().v4()`).
- Enums fechados: `Unidade` (`lib/core/dominio/unidade.dart`) e `CategoriaItem` (`lib/core/dominio/categoria.dart`) — usar `fromValor`/`.valor`.
- A ida é **snapshot imutável** dos itens **concluídos** (`concluido == true`, `deletado_em IS NULL`); nunca referencia `item_local`.
- `total_centavos` soma só itens **com preço** (`quantidade × preço`, arredondando cada subtotal) — mesma regra de `totalCarrinho` (`lib/features/listas/domain/preco.dart`).
- Não há “undo” após finalizar (a ida já foi gravada).
- Nomes de teste: `deve_<resultado>_quando_<condição>`.

---

## File Structure

- `lib/drift/tables/ida_compra.dart` — tabela `idas_compra`.
- `lib/drift/tables/item_ida.dart` — tabela `itens_ida` (FK cascade para `idas_compra`).
- `lib/features/historico/domain/ida.dart` — `Ida`, `ItemDaIda`, `ResumoHistorico` (+ `fromLocal`).
- `lib/features/historico/data/historico_compras_repository.dart` — grava/consulta idas.
- `lib/features/historico/providers/historico_providers.dart` — repository + streams + providers.
- `lib/features/historico/ui/historico_screen.dart` — aba Histórico (resumo + lista + vazio).
- `lib/features/historico/ui/ida_detalhe_screen.dart` — detalhe `/historico/ida/:id`.
- `lib/features/historico/ui/modal_finalizar_compra.dart` — confirmação + diálogo pós-finalizar.
- Modificados: `lib/drift/database.dart` (+tabelas, `schemaVersion = 12`, migração), `lib/router.dart` (+branch `/historico` e rota de detalhe), `lib/core/navigation/app_shell.dart` (+aba), `lib/features/listas/ui/tela_lista_screen.dart` (+ação), `lib/core/l10n/app_strings.dart`, `lib/drift/database.g.dart` (regen).

---

## Task 1: Drift v12 — tabelas de ida + domínio

**Files:**
- Create: `lib/drift/tables/ida_compra.dart`
- Create: `lib/drift/tables/item_ida.dart`
- Create: `lib/features/historico/domain/ida.dart`
- Modify: `lib/drift/database.dart`
- Regenerate: `lib/drift/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- Test: `test/features/historico/ida_schema_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`lib/drift/database.dart`), `Unidade.fromValor`, `CategoriaItem.fromValor`.
- Produces: tabelas `IdaCompra`/`ItemIda` e data classes `IdaCompraData`/`ItemIdaData`; domínio `Ida({id, listaId, titulo, finalizadaEm, totalCentavos, itensCount})`, `ItemDaIda({id, idaId, nome, quantidade, unidade, categoria, precoCentavos})`, `ResumoHistorico({totalGeralCentavos, ticketMedioCentavos, nIdas})`.

- [ ] **Step 1: Write the failing test**

`test/features/historico/ida_schema_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('deve_ter_schema_v12_quando_abre', () {
    expect(db.schemaVersion, 12);
  });

  test('deve_gravar_ida_e_item_quando_insere', () async {
    await db.into(db.idaCompra).insert(
      IdaCompraCompanion.insert(
        id: 'ida-1',
        titulo: 'Semana',
        finalizadaEm: DateTime.utc(2026, 9, 30),
      ),
    );
    await db.into(db.itemIda).insert(
      ItemIdaCompanion.insert(
        id: 'item-1',
        idaId: 'ida-1',
        nome: 'Arroz',
        precoCentavos: const Value(549),
      ),
    );
    final itens = await db.select(db.itemIda).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 1.0);
    expect(itens.single.unidade, 'un');
    expect(itens.single.categoria, 'outros');
    expect(itens.single.precoCentavos, 549);
  });

  test('deve_apagar_itens_quando_apaga_a_ida', () async {
    await db.into(db.idaCompra).insert(
      IdaCompraCompanion.insert(
        id: 'ida-1', titulo: 'X', finalizadaEm: DateTime.utc(2026, 9, 30),
      ),
    );
    await db.into(db.itemIda).insert(
      ItemIdaCompanion.insert(id: 'item-1', idaId: 'ida-1', nome: 'Leite'),
    );
    await (db.delete(db.idaCompra)..where((t) => t.id.equals('ida-1'))).go();
    expect(await db.select(db.itemIda).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/ida_schema_test.dart`
Expected: FAIL — `db.idaCompra`/`db.itemIda` e `schemaVersion` 12 inexistentes.

- [ ] **Step 3: Write the tables**

`lib/drift/tables/ida_compra.dart`:

```dart
import 'package:drift/drift.dart';

/// Snapshot imutável de uma compra finalizada (RF-34). Local-only.
class IdaCompra extends Table {
  TextColumn get id => text()();
  TextColumn get listaId => text().nullable()();
  TextColumn get titulo => text()();
  DateTimeColumn get finalizadaEm => dateTime()();
  IntColumn get totalCentavos => integer().withDefault(const Constant(0))();
  IntColumn get itensCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
```

`lib/drift/tables/item_ida.dart`:

```dart
import 'package:drift/drift.dart';
import 'ida_compra.dart';

/// Item (snapshot) de uma ida (RF-34). A ida não referencia `item_local`.
class ItemIda extends Table {
  TextColumn get id => text()();
  TextColumn get idaId =>
      text().references(IdaCompra, #id, onDelete: KeyAction.cascade)();
  TextColumn get nome => text()();
  RealColumn get quantidade => real().withDefault(const Constant(1.0))();
  TextColumn get unidade => text().withDefault(const Constant('un'))();
  TextColumn get categoria => text().withDefault(const Constant('outros'))();
  IntColumn get precoCentavos => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
        'CHECK (quantidade > 0)',
        "CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz'))",
        "CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios','congelados',"
            "'padaria','bebidas','pet','limpeza','higiene','outros'))",
      ];
}
```

Em `lib/drift/database.dart`: adicionar imports, registrar as tabelas em `@DriftDatabase(tables: [..., IdaCompra, ItemIda])`, mudar `schemaVersion => 12`, e no `onUpgrade`:

```dart
      if (de < 12) {
        // v11 → v12: idas de compra (RF-34, F50). Local-only; sem sync.
        await m.createTable(idaCompra);
        await m.createTable(itemIda);
      }
```

- [ ] **Step 4: Regenerate and run**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/features/historico/ida_schema_test.dart`
Expected: PASS.

- [ ] **Step 5: Domain models**

`lib/features/historico/domain/ida.dart`:

```dart
import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';

class Ida {
  const Ida({
    required this.id,
    required this.listaId,
    required this.titulo,
    required this.finalizadaEm,
    required this.totalCentavos,
    required this.itensCount,
  });
  final String id;
  final String? listaId;
  final String titulo;
  final DateTime finalizadaEm;
  final int totalCentavos;
  final int itensCount;

  factory Ida.fromLocal(IdaCompraData d) => Ida(
        id: d.id, listaId: d.listaId, titulo: d.titulo,
        finalizadaEm: d.finalizadaEm, totalCentavos: d.totalCentavos,
        itensCount: d.itensCount,
      );
}

class ItemDaIda {
  const ItemDaIda({
    required this.id, required this.idaId, required this.nome,
    required this.quantidade, required this.unidade, required this.categoria,
    required this.precoCentavos,
  });
  final String id;
  final String idaId;
  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
  final int? precoCentavos;

  factory ItemDaIda.fromLocal(ItemIdaData d) => ItemDaIda(
        id: d.id, idaId: d.idaId, nome: d.nome, quantidade: d.quantidade,
        unidade: Unidade.fromValor(d.unidade),
        categoria: CategoriaItem.fromValor(d.categoria),
        precoCentavos: d.precoCentavos,
      );
}

class ResumoHistorico {
  const ResumoHistorico({
    required this.totalGeralCentavos,
    required this.ticketMedioCentavos,
    required this.nIdas,
  });
  final int totalGeralCentavos;
  final int ticketMedioCentavos;
  final int nIdas;
}
```

- [ ] **Step 6: Run tests, format and analyze**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde (a suíte anterior + os 3 novos).

- [ ] **Step 7: Commit**

```bash
git add lib/drift lib/features/historico/domain test/features/historico
git commit -m "feat(historico): tabelas de ida e dominio (RF-34, F50)"
```

---

## Task 2: `HistoricoComprasRepository` (gravar ida + consultas)

**Files:**
- Create: `lib/features/historico/data/historico_compras_repository.dart`
- Create: `lib/features/historico/providers/historico_providers.dart`
- Test: `test/features/historico/historico_compras_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `appDatabaseProvider` (`lib/features/listas/providers/listas_providers.dart`), `ListasRepository` (`criarLista`/`adicionarItem`/`editarItem` — usados nos testes), `Ida`/`ItemDaIda`/`ResumoHistorico` (Task 1), `totalCarrinho` pattern.
- Produces: `HistoricoComprasRepository(db, {Uuid? uuid})`; `Future<Ida> finalizar(String listaId)`; `Stream<List<Ida>> watchIdas()`; `Future<Ida?> ida(String id)`; `Future<List<ItemDaIda>> itensDaIda(String idaId)`; `Future<ResumoHistorico> resumo()`; e `historicoComprasRepositoryProvider`, `idasProvider`, `idaProvider(id)`, `itensDaIdaProvider(id)`, `resumoHistoricoProvider`.

- [ ] **Step 1: Write the failing test**

`test/features/historico/historico_compras_repository_test.dart`:

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

  test('deve_gravar_snapshot_dos_concluidos_quando_finaliza', () async {
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final comprado = await listas.adicionarItem(
      listaId: l.id, nome: 'Arroz', quantidade: 2,
      unidade: Unidade.kg, categoria: CategoriaItem.mercearia,
      precoCentavos: 549,
    );
    await listas.editarItem(comprado.id, concluido: true);
    await listas.adicionarItem(listaId: l.id, nome: 'Pendente');

    final ida = await historico.finalizar(l.id);

    expect(ida.titulo, 'Semana');
    expect(ida.itensCount, 1);
    final itens = await historico.itensDaIda(ida.id);
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.unidade, Unidade.kg);
    expect(itens.single.categoria, CategoriaItem.mercearia);
    expect(itens.single.precoCentavos, 549);
  });

  test('deve_somar_somente_itens_com_preco_quando_calcula_total', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.adicionarItem(
      listaId: l.id, nome: 'Arroz', quantidade: 2, precoCentavos: 500);
    final b = await listas.adicionarItem(listaId: l.id, nome: 'Sem preço');
    await listas.editarItem(a.id, concluido: true);
    await listas.editarItem(b.id, concluido: true);

    final ida = await historico.finalizar(l.id);
    expect(ida.itensCount, 2);
    expect(ida.totalCentavos, 1000);
  });

  test('deve_falhar_quando_nao_ha_concluidos', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    await listas.adicionarItem(listaId: l.id, nome: 'Pendente');
    expect(() => historico.finalizar(l.id), throwsStateError);
    expect(await db.select(db.idaCompra).get(), isEmpty);
  });

  test('deve_listar_idas_mais_recentes_primeiro', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.adicionarItem(listaId: l.id, nome: 'A');
    await listas.editarItem(a.id, concluido: true);
    await historico.finalizar(l.id);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await historico.finalizar(l.id);
    final idas = await historico.watchIdas().first;
    expect(idas, hasLength(2));
    expect(idas.first.finalizadaEm.isAfter(idas.last.finalizadaEm), isTrue);
  });

  test('deve_calcular_resumo_quando_ha_idas', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.adicionarItem(
      listaId: l.id, nome: 'A', quantidade: 1, precoCentavos: 300);
    await listas.editarItem(a.id, concluido: true);
    await historico.finalizar(l.id);
    await historico.finalizar(l.id); // mesma ida, 2 registros
    final r = await historico.resumo();
    expect(r.nIdas, 2);
    expect(r.totalGeralCentavos, 600);
    expect(r.ticketMedioCentavos, 300);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/historico_compras_repository_test.dart`
Expected: FAIL — repositório inexistente.

- [ ] **Step 3: Implement the repository**

`lib/features/historico/data/historico_compras_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../drift/database.dart';
import '../domain/ida.dart';

class HistoricoComprasRepository {
  HistoricoComprasRepository(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<Ida> finalizar(String listaId) {
    return _db.transaction(() async {
      final lista = await (_db.select(_db.listaLocal)
            ..where((l) => l.id.equals(listaId)))
          .getSingle();
      final concluidos = await (_db.select(_db.itemLocal)
            ..where((i) =>
                i.listaId.equals(listaId) &
                i.concluido.equals(true) &
                i.deletadoEm.isNull())
            ..orderBy([
              (i) => OrderingTerm.asc(i.ordem),
              (i) => OrderingTerm.asc(i.id),
            ]))
          .get();
      if (concluidos.isEmpty) {
        throw StateError('Nenhum item concluído para finalizar');
      }
      final agora = DateTime.now().toUtc();
      final idaId = _uuid.v4();
      var total = 0;
      for (final i in concluidos) {
        final preco = i.precoCentavos;
        if (preco != null) total += (i.quantidade * preco).round();
      }
      await _db.into(_db.idaCompra).insert(
            IdaCompraCompanion.insert(
              id: idaId, listaId: Value(listaId), titulo: lista.titulo,
              finalizadaEm: agora, totalCentavos: Value(total),
              itensCount: Value(concluidos.length),
            ),
          );
      for (final i in concluidos) {
        await _db.into(_db.itemIda).insert(
              ItemIdaCompanion.insert(
                id: _uuid.v4(), idaId: idaId, nome: i.nome,
                quantidade: Value(i.quantidade), unidade: Value(i.unidade),
                categoria: Value(i.categoria),
                precoCentavos: Value(i.precoCentavos),
              ),
            );
      }
      return Ida(
        id: idaId, listaId: listaId, titulo: lista.titulo,
        finalizadaEm: agora, totalCentavos: total,
        itensCount: concluidos.length,
      );
    });
  }

  Stream<List<Ida>> watchIdas() => (_db.select(_db.idaCompra)
        ..orderBy([(t) => OrderingTerm.desc(t.finalizadaEm)]))
      .watch()
      .map((rows) => rows.map(Ida.fromLocal).toList());

  Future<Ida?> ida(String id) async {
    final row = await (_db.select(_db.idaCompra)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : Ida.fromLocal(row);
  }

  Future<List<ItemDaIda>> itensDaIda(String idaId) async {
    final rows = await (_db.select(_db.itemIda)
          ..where((t) => t.idaId.equals(idaId))
          ..orderBy([(t) => OrderingTerm.asc(t.nome), (t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(ItemDaIda.fromLocal).toList();
  }

  Future<ResumoHistorico> resumo() async {
    final idas = await _db.select(_db.idaCompra).get();
    final total = idas.fold<int>(0, (s, i) => s + i.totalCentavos);
    final n = idas.length;
    return ResumoHistorico(
      totalGeralCentavos: total,
      ticketMedioCentavos: n == 0 ? 0 : (total / n).round(),
      nIdas: n,
    );
  }
}
```

`lib/features/historico/providers/historico_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/historico_compras_repository.dart';
import '../domain/ida.dart';

final historicoComprasRepositoryProvider = Provider<HistoricoComprasRepository>(
  (ref) => HistoricoComprasRepository(ref.watch(appDatabaseProvider)),
);

final idasProvider = StreamProvider<List<Ida>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).watchIdas(),
);

final idaProvider = FutureProvider.family<Ida?, String>(
  (ref, id) => ref.watch(historicoComprasRepositoryProvider).ida(id),
);

final itensDaIdaProvider = FutureProvider.family<List<ItemDaIda>, String>(
  (ref, idaId) =>
      ref.watch(historicoComprasRepositoryProvider).itensDaIda(idaId),
);

final resumoHistoricoProvider = FutureProvider<ResumoHistorico>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).resumo(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/historico/historico_compras_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/historico/data lib/features/historico/providers test/features/historico
git commit -m "feat(historico): repositorio de idas de compra (RF-34, F50)"
```

---

## Task 3: Ação "Finalizar compra" na tela da lista

**Files:**
- Create: `lib/features/historico/ui/modal_finalizar_compra.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/historico/finalizar_compra_test.dart`

**Interfaces:**
- Consumes: `historicoComprasRepositoryProvider`, `Ida` (Task 2), `ListasRepository.limparConcluidos` (`lib/features/listas/data/listas_repository.dart`), `itensDaListaProvider`, `totalCarrinho`/`formatarReais` (`lib/features/listas/domain/preco.dart`).
- Produces: `Future<void> abrirFinalizarCompra(BuildContext, WidgetRef, String listaId)`.

- [ ] **Step 1: Add strings**

Em `AppStrings`:

```dart
  // Historico de compras (RF-34, F50)
  static const finalizarCompra = 'Finalizar compra';
  static const finalizarConfirmarTitulo = 'Finalizar esta compra?';
  static String finalizarResumo(int n, String total, int semPreco) =>
      semPreco == 0
          ? '$n ${n == 1 ? 'item' : 'itens'} · $total'
          : '$n ${n == 1 ? 'item' : 'itens'} · $total · $semPreco sem preço';
  static const finalizarLimpar = 'Limpar concluídos';
  static const finalizarManter = 'Manter a lista';
  static const compraRegistrada = 'Compra registrada no histórico.';
  static const historico = 'Histórico';
  static const historicoVazio = 'Nenhuma compra finalizada ainda.';
  static const historicoVazioDica =
      'Marque itens e use "Finalizar compra" para registrar uma ida.';
  static const totalGasto = 'Total gasto';
  static const ticketMedio = 'Ticket médio';
  static const numeroIdas = 'Idas';
```

- [ ] **Step 2: Write the failing widget test**

`test/features/historico/finalizar_compra_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/ui/modal_finalizar_compra.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  testWidgets('deve_finalizar_e_registrar_quando_confirmado', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final item = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(item.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      abrirFinalizarCompra(context, ref, l.id),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar compra'));
    await tester.pumpAndSettle();
    // Dialogo pos-finalizar: manter a lista.
    await tester.tap(find.text('Manter a lista'));
    await tester.pumpAndSettle();

    expect((await db.select(db.idaCompra).get()), hasLength(1));
    expect((await db.select(db.itemIda).get()), hasLength(1));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/historico/finalizar_compra_test.dart`
Expected: FAIL — `abrirFinalizarCompra` inexistente.

- [ ] **Step 4: Implement the modal**

`lib/features/historico/ui/modal_finalizar_compra.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/domain/preco.dart';
import '../../listas/providers/listas_providers.dart';
import '../providers/historico_providers.dart';

Future<void> abrirFinalizarCompra(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final itens = await ref.read(itensDaListaProvider(listaId).future);
  final marcados = itens.where((i) => i.concluido).toList();
  if (marcados.isEmpty) return;
  final semPreco = marcados.where((i) => i.precoCentavos == null).length;
  final total = totalCarrinho(itens);

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.finalizarConfirmarTitulo),
      content: Text(
        AppStrings.finalizarResumo(marcados.length, formatarReais(total), semPreco),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.cancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(AppStrings.finalizarCompra),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  await ref.read(historicoComprasRepositoryProvider).finalizar(listaId);
  if (!context.mounted) return;
  mostrarSnackBar(context, AppStrings.compraRegistrada);

  final limpar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.compraRegistrada),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.finalizarManter),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(AppStrings.finalizarLimpar),
        ),
      ],
    ),
  );
  if (limpar == true) {
    await ref.read(listasRepositoryProvider).limparConcluidos(listaId);
  }
}
```

Em `tela_lista_screen.dart`: adicionar import e, no `PopupMenuButton`, um item `value: 'finalizar'` com `AppStrings.finalizarCompra` (e no `_acaoMenu`, `case 'finalizar': await abrirFinalizarCompra(context, ref, listaId);`). Adicionar também um botão no rodapé (na `Column` da SafeArea, acima do botão "Importar lista") visível só quando há itens concluídos:

```dart
if (itens.any((i) => i.concluido))
  Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: AppBotao(
      rotulo: AppStrings.finalizarCompra,
      icone: Icons.shopping_bag_outlined,
      onPressed: () => abrirFinalizarCompra(context, ref, listaId),
    ),
  ),
```

> Onde `itens` é `ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[]` lido no build.

- [ ] **Step 5: Run tests, format and analyze**

Run: `flutter test test/features/historico/finalizar_compra_test.dart && dart format . && flutter analyze`
Expected: PASS e analyze limpo.

- [ ] **Step 6: Commit**

```bash
git add lib/features/historico/ui lib/features/listas/ui/tela_lista_screen.dart lib/core/l10n/app_strings.dart test/features/historico
git commit -m "feat(historico): acao finalizar compra na lista (RF-34, F50)"
```

---

## Task 4: Aba Histórico + detalhe da ida

**Files:**
- Create: `lib/features/historico/ui/historico_screen.dart`
- Create: `lib/features/historico/ui/ida_detalhe_screen.dart`
- Modify: `lib/router.dart`
- Modify: `lib/core/navigation/app_shell.dart`
- Test: `test/features/historico/historico_screen_test.dart`

**Interfaces:**
- Consumes: `idasProvider`, `resumoHistoricoProvider`, `idaProvider`, `itensDaIdaProvider` (Task 2); `AppEstadoVazio`, `AppEsqueleto`, `formatarReais`.
- Produces: `HistoricoScreen`, `IdaDetalheScreen({required String idaId})`; branches `/historico` e rota `/historico/ida/:idaId`.

- [ ] **Step 1: Write the failing widget test**

`test/features/historico/historico_screen_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';

void main() {
  testWidgets('deve_mostrar_vazio_quando_sem_idas', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma compra finalizada ainda.'), findsOneWidget);
  });

  testWidgets('deve_listar_ida_quando_existe', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final i = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(i.id, concluido: true);
    await historico.finalizar(l.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Semana'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/historico/historico_screen_test.dart`
Expected: FAIL — `HistoricoScreen` inexistente.

- [ ] **Step 3: Implement the screens**

`lib/features/historico/ui/historico_screen.dart` — `ConsumerWidget` com `AppBar(title: AppStrings.historico)`, resumo (três linhas/branches com `Total gasto`, `Ticket médio`, `Idas` usando `resumoHistoricoProvider`), e a lista de idas (`idasProvider`):
- `loading` → `AppEsqueleto(linhas: 4)`; `error` → `AppEstadoErro`; vazio → `AppEstadoVazio(titulo: AppStrings.historicoVazio, descricao: AppStrings.historicoVazioDica)`.
- Cada ida: `ListTile(title: Text(ida.titulo), subtitle: Text(<data dd/MM/yyyy> · N itens), trailing: Text(formatarReais(ida.totalCentavos)), onTap: () => context.push('/historico/ida/${ida.id}'))`.
- Data formatada sem intl: helper local `'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'`.

`lib/features/historico/ui/ida_detalhe_screen.dart` — `ConsumerWidget` com `idaProvider(idaId)` + `itensDaIdaProvider(idaId)`: `AppBar(title: ida.titulo)`, lista dos itens (nome, `quantidade unidade`, categoria, `formatarReais(preco)` ou `AppStrings.semValor`) e um rodapé com o total (`formatarReais(ida.totalCentavos)`); estados de loading/erro/não encontrada.

- [ ] **Step 4: Wire route and shell**

Em `lib/router.dart`: adicionar o import de `HistoricoScreen`/`IdaDetalheScreen`; inserir um **novo branch** entre `/listas` e `/configuracoes` (para que Configurações continue sendo o último destino — preserva `TourKeys.abaConfiguracoes`):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/historico',
                builder: (context, state) => const HistoricoScreen(),
              ),
            ],
          ),
```

E, fora do shell (junto de `/lista/:listaId`):

```dart
      GoRoute(
        path: '/historico/ida/:idaId',
        builder: (context, state) =>
            IdaDetalheScreen(idaId: state.pathParameters['idaId']!),
      ),
```

Em `lib/core/navigation/app_shell.dart`: adicionar ao array `icones` (na 2ª posição) `(normal: Icons.history_outlined, selecionado: Icons.history)` e a `rotulos` (2ª posição) `AppStrings.historico`. **A ordem dos arrays deve espelhar a ordem dos branches no router** (`/listas`, `/historico`, `/configuracoes`).

- [ ] **Step 5: Run tests, format and analyze**

Run: `flutter test test/features/historico/historico_screen_test.dart && dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 6: Commit**

```bash
git add lib/features/historico/ui lib/router.dart lib/core/navigation/app_shell.dart test/features/historico
git commit -m "feat(historico): aba Historico e detalhe da ida (RF-34, F50)"
```

---

## Task 5: Docs donos e fechamento da Fase 50

**Files:**
- Modify: `docs/12-prd.md` (RF-34 + matriz)
- Modify: `docs/05-app-flutter.md` (telas/rotas/repositório + Drift v12)
- Modify: `docs/10-wireframes-telas.md` (aba Histórico, detalhe, finalizar)
- Modify: `docs/14-tarefas.md` (Fase 50 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (frente)
- (Fase 51 fica registrada como próxima; `fl_chart` e estatísticas entram lá.)

- [ ] **Step 1: RF-34 no PRD**

Adicionar à tabela de RF e à matriz de rastreabilidade:

```
| RF-34 | Histórico de compras: ação "Finalizar compra" grava uma ida (snapshot dos itens concluídos) + aba Histórico (lista/resumo/detalhe); estatísticas na Fase 51 | 05 §6.13 + 10 | F50 · F51 | [05 §8] |
```
Matriz: `| RF-34 | US-01 | F50 · F51 | F50-T01…T05 (F51 depois) | Unit repo + widgets |`

- [ ] **Step 2: Doc dono 05**

Nova seção `§6.13 Histórico de compras (RF-34)`: ação "Finalizar compra" (menu + botão), snapshot dos concluídos, diálogo limpar/manter; aba `/historico` + `/historico/ida/:id`; repositório `HistoricoComprasRepository`; tabelas Drift `idas_compra`/`itens_ida` e migração v11→v12. Atualizar a árvore de pastas com `lib/features/historico/` e a lista de tabelas.

- [ ] **Step 3: Wireframe 10, roadmap e tarefas**

- `docs/10-wireframes-telas.md`: wireframes da aba Histórico (resumo + lista + vazio), do detalhe da ida e do fluxo "Finalizar compra" (confirmação + diálogo pós).
- `docs/16-roadmap-pos-mvp.md`: registrar a frente RF-34 (F50 entregue o núcleo; F51 estatísticas pendente) com ID único.
- `docs/14-tarefas.md`: criar `## Fase 50 — Histórico de compras: registrar idas (RF-34)` com F50-T01…T05; atualizar a tabela de progresso (somar a fase). Registrar a Fase 51 como próxima (tarefas a especificar).

- [ ] **Step 4: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs(historico): RF-34, 05, 10, 14 e 16 (F50)"
```

---

## Self-Review (cobertura da spec — Fase 50)

- §3 modelo (`idas_compra`/`itens_ida`, snapshot, migração v12) → Task 1.
- §4 fluxo finalizar (transação, total só com preço, StateError, limpar/manter) → Task 2 + Task 3.
- §5 aba Histórico (resumo, lista, vazio, detalhe) → Task 4.
- §5/§7 estados, ordenação `finalizada_em` desc → Tasks 2/4.
- §10 decisões 1–3 e 5–7 → Tasks 2/3/4 + docs.
- **Fora desta fase:** §6 estatísticas e `fl_chart` (Fase 51).

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-historico-compras-design.md`
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
