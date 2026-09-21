# Fase 25 — Preço por Item e Total no Carrinho (RF-21): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-21 — preço unitário opcional por item (em centavos) e o total ao vivo dos itens **marcados** ("no carrinho"), no rodapé da lista e no modo mercado, 100% offline-first.

**Architecture:** Uma coluna `preco_centavos integer` em `itens_lista` (Drift + payload LWW + aplicador remoto), sem policy nova. Funções puras de formatação/parse/total. O editor do item ganha o campo de preço; um `TotalCarrinho` (ConsumerWidget) deriva o total do `itensDaListaProvider`.

**Tech Stack:** Postgres/Supabase (coluna + CHECK) · Flutter · Riverpod · Drift (build_runner) · go_router · Material 3.

**Spec:** `docs/superpowers/specs/2026-09-21-precos-total-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes; as tarefas de banco rodam também `supabase db reset` + o script SQL.
- Uma tarefa = um commit, mensagem `F25-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `docs/02`** (RLS — não há policy nova) nem em `docs/03` além do payload de item (o dono do sync é atualizado na Task 5).
- Migrations **append-only**: `0017_preco_item.sql`.
- Dinheiro **nunca** em `double`: preço é `int` (centavos).
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- BRL fixo; `null` = sem preço; `0` é válido; negativo rejeitado.
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Banco — migration `0017` (coluna + CHECK) + testes SQL + CI

**Files:**
- Create: `supabase/migrations/0017_preco_item.sql`
- Create: `supabase/tests/preco_item_tests.sql`
- Modify: `.github/workflows/ci.yml` (novo step de `psql`, após o de `transferir_dono_tests`)
- Modify: `docs/07-qualidade-ci.md` (§3 esqueleto — nova linha)

**Interfaces:**
- Consumes: `public.itens_lista` (`docs/01 §4.3`).
- Produces: coluna `preco_centavos integer` com CHECK.

- [ ] **Step 1: Escrever a migration**

`supabase/migrations/0017_preco_item.sql`:

```sql
-- 0017_preco_item.sql — preço unitário do item (doc 01 §4.3, RF-21, F25).
-- Centavos inteiros (sem float); NULL = sem preço; 0 é válido; negativo rejeitado.
alter table public.itens_lista
  add column preco_centavos integer
  check (preco_centavos is null or (preco_centavos >= 0 and preco_centavos <= 99999999));
```

- [ ] **Step 2: Escrever os testes SQL**

`supabase/tests/preco_item_tests.sql`:

```sql
-- ============================================================================
-- preco_item_tests.sql — coluna preco_centavos (doc 01 §4.3, RF-21, F25-T01)
-- Casos:
--   PC-01: item sem preço (NULL) aceito.
--   PC-02: preço 0 aceito; preço normal aceito.
--   PC-03: preço negativo rejeitado; acima do teto rejeitado.
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values ('e0000000-0000-0000-0000-000000000000', 'preco@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('e9000000-0000-0000-0000-000000000000', 'Lista Preço', 'e0000000-0000-0000-0000-000000000000');

-- ===== PC-01: sem preço (NULL) =====
do $$
declare v int;
begin
  insert into public.itens_lista (lista_id, nome)
  values ('e9000000-0000-0000-0000-000000000000', 'Sem preco')
  returning preco_centavos into v;
  if v is not null then raise exception 'FALHOU PC-01: preco %', v; end if;
  raise notice 'OK PC-01: NULL aceito';
end $$;

-- ===== PC-02: zero e valor normal =====
do $$
declare v int;
begin
  insert into public.itens_lista (lista_id, nome, preco_centavos)
  values ('e9000000-0000-0000-0000-000000000000', 'Zero', 0)
  returning preco_centavos into v;
  if v <> 0 then raise exception 'FALHOU PC-02: zero virou %', v; end if;

  insert into public.itens_lista (lista_id, nome, preco_centavos)
  values ('e9000000-0000-0000-0000-000000000000', 'Normal', 549)
  returning preco_centavos into v;
  if v <> 549 then raise exception 'FALHOU PC-02: normal virou %', v; end if;
  raise notice 'OK PC-02: zero e normal aceitos';
end $$;

-- ===== PC-03: negativo e acima do teto rejeitados =====
do $$
begin
  begin
    insert into public.itens_lista (lista_id, nome, preco_centavos)
    values ('e9000000-0000-0000-0000-000000000000', 'Negativo', -1);
    raise exception 'FALHOU PC-03: negativo aceito';
  exception when check_violation then
    raise notice 'OK PC-03: negativo rejeitado';
  end;

  begin
    insert into public.itens_lista (lista_id, nome, preco_centavos)
    values ('e9000000-0000-0000-0000-000000000000', 'Acima', 100000000);
    raise exception 'FALHOU PC-03: acima do teto aceito';
  exception when check_violation then
    raise notice 'OK PC-03: acima do teto rejeitado';
  end;
end $$;

rollback;
```

- [ ] **Step 3: Rodar `db reset` e o script**

Run:
```powershell
supabase db reset
Get-Content supabase/tests/preco_item_tests.sql -Raw | docker exec -i supabase_db_ListaCompras psql -U postgres -d postgres -v ON_ERROR_STOP=1
```
Expected: `OK PC-01`, `OK PC-02`, `OK PC-03` (duas mensagens) e `ROLLBACK`; nenhum `FALHOU`.

- [ ] **Step 4: Adicionar o script ao CI e ao doc 07**

Em `.github/workflows/ci.yml`, após o step "Testes da transferência de dono (08 §6)":

```yaml
      - name: Testes do preço do item (01 §4.3)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/preco_item_tests.sql
```

E no esqueleto do `docs/07-qualidade-ci.md` §3, após a linha do `transferir_dono_tests.sql`:

```
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/preco_item_tests.sql
```

- [ ] **Step 5: Gate Flutter e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde (nenhuma mudança no app nesta tarefa).

```bash
git add supabase/migrations/0017_preco_item.sql supabase/tests/preco_item_tests.sql .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F25-T01: coluna preco_centavos com CHECK e testes SQL (RF-21)"
```

---

### Task 2: Drift, domínio e repositório — `precoCentavos`

**Files:**
- Modify: `lib/drift/tables/item_local.dart`
- Regenerate: `lib/drift/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- Modify: `lib/features/listas/domain/item.dart`
- Modify: `lib/features/listas/data/listas_repository.dart`
- Modify: `lib/features/sync/data/aplicador_remoto.dart`
- Modify: `test/features/listas/listas_repository_test.dart`
- Modify: `test/features/sync/aplicador_remoto_test.dart`

**Interfaces:**
- Consumes: coluna `preco_centavos` (Task 1).
- Produces: `Item.precoCentavos` (`int?`); `ListasRepository.adicionarItem(..., int? precoCentavos)`; `ListasRepository.editarItem(..., int? precoCentavos, bool limparPreco = false)`; payload de item com `preco_centavos`; `duplicarLista` copia o preço.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/listas/listas_repository_test.dart`, acrescentar ao final de `void main()` (o arquivo já tem `db`, `repo`, `fila()`):

```dart
  test('deve_gravar_e_enfileirar_preco_quando_adicionar_item_com_preco', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, 549);

    final mutacoes = await fila();
    final payload = mutacoes.last['payload'] as Map<String, Object?>;
    expect(payload['preco_centavos'], 549);
  });

  test('deve_preservar_preco_quando_editar_outro_campo', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    await repo.editarItem(item.id, nome: 'Arroz Tio João');

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, 549);
  });

  test('deve_limpar_preco_quando_editar_com_limpar_preco', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    await repo.editarItem(item.id, limparPreco: true);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, isNull);
    final payload =
        (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['preco_centavos'], isNull);
  });
```

Em `test/features/sync/aplicador_remoto_test.dart`, acrescentar ao final de `void main()` (o arquivo já tem `db` no `setUp`/`tearDown` e usa a classe `AplicadorRemoto(db).aplicar(tabela, registro)`):

```dart
  test('deve_mapear_preco_ausente_para_null_quando_linha_antiga', () async {
    final aplicador = AplicadorRemoto(db);
    await db.into(db.listaLocal).insert(
          ListaLocalCompanion.insert(
            id: 'l-preco-1',
            createdAt: DateTime.utc(2026, 9, 21),
            updatedAt: DateTime.utc(2026, 9, 21),
            titulo: 'X',
            donoId: 'u',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'i-preco-1',
      'lista_id': 'l-preco-1',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'outros',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });

    final linha = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i-preco-1'))).getSingle();
    expect(linha.precoCentavos, isNull);
  });

  test('deve_mapear_preco_quando_presente', () async {
    final aplicador = AplicadorRemoto(db);
    await db.into(db.listaLocal).insert(
          ListaLocalCompanion.insert(
            id: 'l-preco-2',
            createdAt: DateTime.utc(2026, 9, 21),
            updatedAt: DateTime.utc(2026, 9, 21),
            titulo: 'X',
            donoId: 'u',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'i-preco-2',
      'lista_id': 'l-preco-2',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'outros',
      'concluido': false,
      'ordem': 0,
      'preco_centavos': 549,
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });

    final linha = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i-preco-2'))).getSingle();
    expect(linha.precoCentavos, 549);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart`
Expected: FAIL na compilação — `The named parameter 'precoCentavos' isn't defined` e `The getter 'precoCentavos' isn't defined`.

- [ ] **Step 3: Implementar Drift/domínio/repo/aplicador**

- `lib/drift/tables/item_local.dart` — após `categoria`:
  ```dart
  IntColumn get precoCentavos => integer().nullable()();
  ```
- Regerar: `dart run build_runner build --delete-conflicting-outputs`.
- `lib/features/listas/domain/item.dart` — campo `final int? precoCentavos;` no construtor e `precoCentavos: d.precoCentavos` em `Item.fromLocal`.
- `lib/features/listas/data/listas_repository.dart`:
  - `adicionarItem`: parâmetro `int? precoCentavos` e `precoCentavos: Value(precoCentavos)` no `ItemLocalCompanion.insert`; retorno `Item(..., precoCentavos: precoCentavos)`.
  - `editarItem`: parâmetros `int? precoCentavos` e `bool limparPreco = false`; no companion:
    ```dart
    precoCentavos: precoCentavos != null
        ? Value(precoCentavos)
        : (limparPreco ? const Value(null) : const Value.absent()),
    ```
  - `_payloadItem`: `'preco_centavos': i.precoCentavos,`.
  - `duplicarLista`: passar `precoCentavos: item.precoCentavos` na chamada de `adicionarItem`.
- `lib/features/sync/data/aplicador_remoto.dart` (`_aplicarItem`): adicionar
  ```dart
  precoCentavos: Value(
    (r['preco_centavos'] as num?)?.toInt(),
  ),
  ```
  (linha antiga sem a coluna → `null`, no padrão da tolerância de `categoria`).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart test/features/listas/duplicar_lista_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/drift/tables/item_local.dart lib/drift/database.g.dart lib/features/listas/domain/item.dart lib/features/listas/data/listas_repository.dart lib/features/sync/data/aplicador_remoto.dart test/features/listas/listas_repository_test.dart test/features/sync/aplicador_remoto_test.dart
git commit -m "F25-T02: precoCentavos no Drift, dominio, repositorio e aplicador (RF-21)"
```

---

### Task 3: Funções puras — formatação, parsing e total

**Files:**
- Create: `lib/features/listas/domain/preco.dart`
- Create: `test/features/listas/preco_test.dart`

**Interfaces:**
- Consumes: `Item.precoCentavos` (Task 2).
- Produces: `String formatarReais(int centavos)`; `int? parsePrecoParaCentavos(String? texto)`; `int totalCarrinho(Iterable<Item> itens)`.

- [ ] **Step 1: Escrever os testes que falham**

`test/features/listas/preco_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';

Item _item({
  required bool concluido,
  int? precoCentavos,
  double quantidade = 1,
}) => Item(
  id: 'i',
  listaId: 'l',
  nome: 'x',
  quantidade: quantidade,
  unidade: Unidade.un,
  categoria: CategoriaItem.outros,
  concluido: concluido,
  ordem: 0,
  criadoEm: DateTime(2026),
  atualizadoEm: DateTime(2026),
  precoCentavos: precoCentavos,
);

void main() {
  test('deve_formatar_reais_quando_centavos', () {
    expect(formatarReais(0), r'R$ 0,00');
    expect(formatarReais(549), r'R$ 5,49');
    expect(formatarReais(123456), r'R$ 1.234,56');
    expect(formatarReais(100000000), r'R$ 1.000.000,00');
  });

  test('deve_parsear_preco_quando_virgula_ponto_ou_inteiro', () {
    expect(parsePrecoParaCentavos('5,49'), 549);
    expect(parsePrecoParaCentavos('5.49'), 549);
    expect(parsePrecoParaCentavos('5'), 500);
    expect(parsePrecoParaCentavos(r'R$ 1.234,56'), 123456);
  });

  test('deve_retornar_null_quando_preco_vazio', () {
    expect(parsePrecoParaCentavos(''), isNull);
    expect(parsePrecoParaCentavos('   '), isNull);
    expect(parsePrecoParaCentavos(null), isNull);
  });

  test('deve_rejeitar_quando_preco_negativo', () {
    expect(() => parsePrecoParaCentavos('-1'), throwsArgumentError);
  });

  test('deve_somar_apenas_marcados_com_preco_quando_total', () {
    final itens = [
      _item(concluido: true, precoCentavos: 500),
      _item(concluido: false, precoCentavos: 999), // pendente: fora
      _item(concluido: true, precoCentavos: null), // sem preço: fora
      _item(concluido: true, precoCentavos: 250),
    ];
    expect(totalCarrinho(itens), 750);
  });

  test('deve_arredondar_subtotal_quando_quantidade_fracionaria', () {
    expect(
      totalCarrinho([_item(concluido: true, precoCentavos: 999, quantidade: 0.5)]),
      500, // 499,5 -> 500
    );
  });
}
```

> Import de `Unidade`/`CategoriaItem`: adicione `import 'package:lista_compras/features/listas/domain/unidade.dart';` e `.../categoria.dart` se o analisador pedir.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/preco_test.dart`
Expected: FAIL na compilação — `Target of URI doesn't exist: .../preco.dart`.

- [ ] **Step 3: Implementar as funções**

`lib/features/listas/domain/preco.dart`:

```dart
import 'item.dart';

/// Formata centavos em Real: 549 -> 'R$ 5,49'. Sem dependência de intl.
String formatarReais(int centavos) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final reais = absoluto ~/ 100;
  final resto = absoluto % 100;
  final texto =
      'R\$ ${_milhares(reais)},${resto.toString().padLeft(2, '0')}';
  return negativo ? '-$texto' : texto;
}

String _milhares(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Aceita '5,49', '5.49', '5', 'R$ 1.234,56'. Vazio/nulo -> null.
/// Valor não numérico ou negativo -> ArgumentError (a UI mostra erro inline).
int? parsePrecoParaCentavos(String? texto) {
  final bruto = (texto ?? '').replaceAll(RegExp(r'[R$\s]'), '').trim();
  if (bruto.isEmpty) return null;
  final normalizado = bruto.contains(',')
      ? bruto.replaceAll('.', '').replaceAll(',', '.')
      : bruto;
  final valor = double.tryParse(normalizado);
  if (valor == null) throw ArgumentError('preço inválido: $texto');
  if (valor < 0) throw ArgumentError('preço negativo: $texto');
  return (valor * 100).round();
}

/// Total dos itens **marcados** com preço; cada subtotal arredonda ao centavo.
int totalCarrinho(Iterable<Item> itens) {
  var total = 0;
  for (final item in itens) {
    final preco = item.precoCentavos;
    if (!item.concluido || preco == null) continue;
    total += (item.quantidade * preco).round();
  }
  return total;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/preco_test.dart`
Expected: PASS (6 testes).

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/features/listas/domain/preco.dart test/features/listas/preco_test.dart
git commit -m "F25-T03: formatacao, parsing e total do carrinho (RF-21)"
```

---

### Task 4: UI — campo de preço no editor e faixa do total

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (strings novas)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (editor + faixa)
- Create: `lib/features/listas/ui/total_carrinho.dart`
- Modify: `lib/features/listas/ui/mercado_screen.dart` (faixa)
- Modify: `test/features/listas/tela_lista_screen_test.dart`
- Modify: `test/features/listas/mercado_screen_test.dart`

**Interfaces:**
- Consumes: `parsePrecoParaCentavos`, `formatarReais`, `totalCarrinho` (Task 3); `editarItem(..., precoCentavos, limparPreco)` (Task 2); `itensDaListaProvider`.
- Produces: `TotalCarrinho` widget; campo "Preço (R$)" no editor.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`, após `static const categoria = ...` (procure a constante existente), adicionar:

```dart
  static const preco = 'Preço (R$)';
  static const erroPrecoInvalido = 'Preço inválido.';
  static const noCarrinho = 'No carrinho';

  static String semPreco(int n) => n == 1 ? '1 sem preço' : '$n sem preço';
```

- [ ] **Step 2: Escrever os testes de widget que falham**

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar ao final de `void main()`, reusando o padrão de abertura do arquivo (`db`, `appDatabaseProvider.overrideWithValue(db)`, `papelRepositoryProvider`, `syncStatusProvider` — como em `abrirListaF7t07`):

```dart
  Future<String> abrirListaComPreco(
    WidgetTester tester, {
    required bool marcado,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    if (marcado) await repo.editarItem(item.id, concluido: true);
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: ServidorFake((req) => (200, const <Object>[])),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    papelRepo.atualizar(lista.id, Papel.dono);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(papelRepo),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  testWidgets('deve_mostrar_total_no_rodape_quando_ha_marcado_com_preco', (
    tester,
  ) async {
    await abrirListaComPreco(tester, marcado: true);
    expect(find.textContaining(r'R$ 5,49'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_total_quando_nada_marcado', (tester) async {
    await abrirListaComPreco(tester, marcado: false);
    expect(find.textContaining(AppStrings.noCarrinho), findsNothing);
    await fechar(tester);
  });
```

Em `test/features/listas/mercado_screen_test.dart`, acrescentar um teste equivalente usando o harness do arquivo (que já monta a `MercadoScreen` com itens): criar a lista + item com `precoCentavos: 549` e `concluido: true`, abrir a tela e esperar `find.textContaining(r'R$ 5,49')`. Reuse os helpers/overrides já existentes no arquivo.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart test/features/listas/mercado_screen_test.dart`
Expected: FAIL — `find.textContaining('R$ 5,49')` sem resultado (a faixa ainda não existe).

- [ ] **Step 4: Implementar o widget e as telas**

`lib/features/listas/ui/total_carrinho.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../domain/item.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Faixa do total dos itens marcados com preço (RF-21, F25). Oculta quando
/// não há nenhum item marcado.
class TotalCarrinho extends ConsumerWidget {
  const TotalCarrinho({super.key, required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens =
        ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
    final marcados = itens.where((i) => i.concluido).toList();
    if (marcados.isEmpty) return const SizedBox.shrink();
    final semPreco = marcados.where((i) => i.precoCentavos == null).length;
    final texto = StringBuffer()
      ..write(AppStrings.noCarrinho)
      ..write(': ')
      ..write(formatarReais(totalCarrinho(itens)));
    if (semPreco > 0) {
      texto
        ..write(' · ')
        ..write(AppStrings.semPreco(semPreco));
    }
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          texto.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
```

Em `lib/features/listas/ui/tela_lista_screen.dart`, no `body: Column(...)`, inserir logo após o `Expanded(child: _ListaItens(...))` (antes do botão de importar):

```dart
                TotalCarrinho(listaId: listaId),
```

E no editor `_DialogoEditarItem`:
- Estado: `late final _preco = TextEditingController(text: _precoInicial(widget.item.precoCentavos));` e `String? _erroPreco;`
- `dispose`: `_preco.dispose();`
- Helper:
  ```dart
  String _precoInicial(int? centavos) =>
      centavos == null ? '' : (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');
  ```
- Em `_salvar`, ler o preço antes de gravar:
  ```dart
  int? preco;
  var precoValido = true;
  try {
    preco = parsePrecoParaCentavos(_preco.text);
  } on ArgumentError {
    precoValido = false;
  }
  setState(() {
    _erroNome = nome.isEmpty ? AppStrings.erroNomeVazio : null;
    _erroQuantidade = quantidade == null ? AppStrings.erroQuantidadeInvalida : null;
    _erroPreco = precoValido ? null : AppStrings.erroPrecoInvalido;
  });
  if (nome.isEmpty || quantidade == null || !precoValido) return;
  await ref.read(listasRepositoryProvider).editarItem(
    widget.item.id,
    nome: nome,
    quantidade: quantidade,
    unidade: _unidade,
    categoria: _categoria,
    precoCentavos: preco,
    limparPreco: preco == null,
  );
  ```
- No `build`, após o `AppDropdown<CategoriaItem>`:
  ```dart
            const SizedBox(height: AppSpacing.md),
            AppCampoTexto(
              controller: _preco,
              label: AppStrings.preco,
              erro: _erroPreco,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_erroPreco != null) setState(() => _erroPreco = null);
              },
            ),
  ```
- Imports: `../domain/preco.dart`.

Em `lib/features/listas/ui/mercado_screen.dart`, no `_CorpoMercado`, adicionar `TotalCarrinho(listaId: ...)` logo abaixo do contador de progresso. O `_CorpoMercado` recebe `itens`; passe o `listaId` até ele (novo campo `required this.listaId`) a partir do widget pai, e renderize `TotalCarrinho(listaId: listaId)` após o `Padding` do contador.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart test/features/listas/mercado_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/total_carrinho.dart lib/features/listas/ui/tela_lista_screen.dart lib/features/listas/ui/mercado_screen.dart test/features/listas/tela_lista_screen_test.dart test/features/listas/mercado_screen_test.dart
git commit -m "F25-T04: campo de preco no editor e faixa do total (RF-21)"
```

---

### Task 5: Docs donos e fechamento da Fase 25

**Files:**
- Modify: `docs/01-banco-de-dados.md` (§4.3 — coluna/check)
- Modify: `docs/03-sincronizacao-offline.md` (payload de item inclui `preco_centavos`)
- Modify: `docs/05-app-flutter.md` (editor com preço; faixa do total)
- Modify: `docs/10-wireframes-telas.md` (faixa do total + campo de preço)
- Modify: `docs/12-prd.md` (RF-21; tirar preço do "fora de escopo")
- Modify: `docs/14-tarefas.md` (Fase 25 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (D1 parcialmente concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–4.
- Produces: nada consumido por código.

- [ ] **Step 1: Docs 01 e 03**
  - `01 §4.3`: acrescentar `preco_centavos integer` à tabela SQL de `itens_lista` e à lista de campos, com o CHECK e a regra (`null` = sem preço; `0` válido; teto).
  - `03`: no ponto que descreve o payload de itens (Seção 4/5), incluir `preco_centavos` entre os campos sincronizados.

- [ ] **Step 2: Docs 05 e 10**
  - `05 §6.3`: na linha do editor de item, incluir o campo **Preço (R$)**; acrescentar um bullet sobre a **faixa do total** ("No carrinho: R$ … · N sem preço"), no rodapé da lista e no modo mercado, somando **itens marcados com preço**.
  - `10`: wireframe da faixa do total na tela da lista e no modo mercado; campo de preço no diálogo do item.

- [ ] **Step 3: Doc 12 e 16**
  - `12 §2`: adicionar `RF-21 | Preço unitário opcional + total dos itens marcados | 05 §6.3 + 10 | F25 | ...`; em §7 (fora de escopo), **remover** "preço/orçamento" e deixar apenas "orçamento/limite" e "comparação entre idas" como fora; em §6, linha de rastreabilidade `RF-21 | US-01 | F25 | F25-T02…T04 | Unit preço/total + widgets`.
  - `16`: Onda D linha D1 → `preço + total concluído (F25); orçamento e comparação pendentes`.

- [ ] **Step 4: Doc 14 (Fase 25 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 25 com F25-T01…T05 `[x]` e CPs.
  - Na tabela, após `| F24 Transferência de dono | 5 | 5 |`, adicionar `| F25 Preço e total | 5 | 5 |` e atualizar o total para `| **Total** | **148** | **146** |`.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/01-banco-de-dados.md docs/03-sincronizacao-offline.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F25-T05: docs donos e fechamento da Fase 25 (RF-21)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 banco → Task 1; §4 Drift/domínio → Task 2; §6 funções puras → Task 3; §5 UI → Task 4; §7 testes → Tasks 1–4; docs → Task 5. Orçamento/comparação ficam fora (spec §2).
- **Placeholders:** nenhum "TBD"; o código novo de produção está completo. Os testes de widget reusam o harness real dos arquivos (o implementador lê o arquivo para os overrides exatos — padrão já aceito nas fases anteriores).
- **Consistência de tipos:** `precoCentavos` (`int?`), `editarItem(..., int? precoCentavos, bool limparPreco)`, `formatarReais(int)`, `parsePrecoParaCentavos(String?)`, `totalCarrinho(Iterable<Item>)`, `TotalCarrinho({listaId})`, progresso 148/146 — idênticos entre tarefas.
- **YAGNI:** sem orçamento, sem histórico, sem `intl`, sem tabela nova.
