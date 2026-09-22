# Fase 29 — Quantidades em Fração (RF-25): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-25 — aceitar frações na entrada (`1/2`, `1 1/2`, `½`, `1½`) e exibir glifos com corte de decimais longos, sem schema/RLS/sync.

**Architecture:** Funções puras `parseQuantidade`/`formatarQuantidade` (fonte única, já usada por linha/editor/mercado/importação/outra-lista). O parser compartilhado (`parser_lista_local.dart`) passa a reconhecer frações na entrada rápida e na importação.

**Tech Stack:** Dart puro (domínio) + regex do parser; Flutter para o editor. Sem banco.

**Spec:** `docs/superpowers/specs/2026-09-21-quantidades-fracao-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F29-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `docs/01`, `docs/02`, `docs/03`** — sem schema.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Frações: numéricas (`1/2`), mistas (`1 1/2`), glifos (`½`, `1½`); **sem palavras**.
- Quantidade continua `double` (numeric); `formatarQuantidade` é a fonte única da exibição.
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Domínio — `parseQuantidade` e `formatarQuantidade`

**Files:**
- Modify: `lib/features/listas/domain/quantidade.dart`
- Create: `test/features/listas/quantidade_test.dart`

**Interfaces:**
- Consumes: nada (funções puras).
- Produces: `double? parseQuantidade(String texto)`; `String formatarQuantidade(double q)` (atualizado); `const glifosFracao` (String com os glifos).

- [ ] **Step 1: Escrever os testes que falham**

`test/features/listas/quantidade_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/quantidade.dart';

void main() {
  test('deve_parsear_quantidade_quando_numerico', () {
    expect(parseQuantidade('2'), 2);
    expect(parseQuantidade('1,5'), 1.5);
    expect(parseQuantidade('1.5'), 1.5);
  });

  test('deve_parsear_quantidade_quando_fracao_numerica', () {
    expect(parseQuantidade('1/2'), 0.5);
    expect(parseQuantidade('3/4'), 0.75);
  });

  test('deve_parsear_quantidade_quando_glifo', () {
    expect(parseQuantidade('½'), 0.5);
    expect(parseQuantidade('1½'), 1.5);
    expect(parseQuantidade('2⅓'), closeTo(2.3333, 0.001));
  });

  test('deve_retornar_null_quando_invalido', () {
    expect(parseQuantidade('abc'), isNull);
    expect(parseQuantidade('1/0'), isNull);
    expect(parseQuantidade(''), isNull);
  });

  test('deve_formatar_quando_inteiro', () {
    expect(formatarQuantidade(2), '2');
    expect(formatarQuantidade(0), '0');
  });

  test('deve_formatar_quando_glifo_comum', () {
    expect(formatarQuantidade(0.5), '½');
    expect(formatarQuantidade(1.5), '1½');
    expect(formatarQuantidade(0.25), '¼');
    expect(formatarQuantidade(2 + 1 / 3), '2⅓');
  });

  test('deve_cortar_decimais_quando_nao_e_glifo_comum', () {
    expect(formatarQuantidade(1.25), '1.25');
    expect(formatarQuantidade(1 / 7), '0.143');
    expect(formatarQuantidade(0.3333), '⅓'); // tolerância casa 1/3
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/quantidade_test.dart`
Expected: FAIL na compilação — `The function 'parseQuantidade' isn't defined` e os glifos.

- [ ] **Step 3: Implementar**

Substituir `lib/features/listas/domain/quantidade.dart` por:

```dart
/// Glifos de fração aceitos/exibidos (½ ¼ ¾ ⅓ ⅔).
const glifosFracao = '½¼¾⅓⅔';

const Map<double, String> _glifos = {
  0.25: '¼',
  0.5: '½',
  0.75: '¾',
  1 / 3: '⅓',
  2 / 3: '⅔',
};

/// Interpreta uma quantidade: decimal pt-BR (`2`, `1,5`, `1.5`), fração
/// simples (`1/2`), glifo (`½`) ou mista colada (`1½`). `null` se não for
/// quantidade (ou inválida: denominador 0).
double? parseQuantidade(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return null;

  for (final e in _glifos.entries) {
    final i = t.indexOf(e.value);
    if (i < 0) continue;
    if (t.indexOf(e.value, i + e.value.length) >= 0) return null; // >1 glifo
    final prefixo = t.substring(0, i).trim();
    final sufixo = t.substring(i + e.value.length).trim();
    if (sufixo.isNotEmpty) return null;
    final inteiro = prefixo.isEmpty
        ? 0.0
        : double.tryParse(prefixo.replaceAll(',', '.'));
    if (inteiro == null || inteiro < 0) return null;
    return inteiro + e.key;
  }

  final fracao = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(t);
  if (fracao != null) {
    final numerador = int.parse(fracao.group(1)!);
    final denominador = int.parse(fracao.group(2)!);
    if (denominador == 0) return null;
    return numerador / denominador;
  }

  return double.tryParse(t.replaceAll(',', '.'));
}

/// Formata para exibição: inteiro → `2`; parte fracionária que casa um glifo
/// comum (½ ¼ ¾ ⅓ ⅔, com tolerância) → misto (`1½`, `2⅓`); senão arredonda
/// para ≤ 3 casas e corta zeros (`1.25`, `0.143`).
String formatarQuantidade(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  final inteiro = q.truncate();
  final fracao = q - inteiro;
  for (final e in _glifos.entries) {
    if ((fracao - e.key).abs() < 0.001) {
      return inteiro == 0 ? e.value : '$inteiro${e.value}';
    }
  }
  var texto = q.toStringAsFixed(3);
  texto = texto.replaceFirst(RegExp(r'0+$'), '');
  texto = texto.replaceFirst(RegExp(r'\.$'), '');
  return texto;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/quantidade_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde (a mudança de `formatarQuantidade` pode alterar testes existentes de exibição — se algum falhar por esperar `0.5`, ajuste o teste para `½`, pois é o novo contrato).

```bash
git add lib/features/listas/domain/quantidade.dart test/features/listas/quantidade_test.dart
git commit -m "F29-T01: parseQuantidade e glifos na formatacao (RF-25)"
```

---

### Task 2: Parser e editor — aceitar frações na entrada

**Files:**
- Modify: `lib/core/importacao/parser_lista_local.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_quantidadeLida`)
- Modify: `test/core/importacao/parser_lista_local_test.dart`
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `parseQuantidade`, `glifosFracao` (Task 1).
- Produces: parser reconhece frações (avulso + importação); editor aceita fração.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/core/importacao/parser_lista_local_test.dart`, acrescentar ao final de `void main()`:

```dart
  test('deve_ler_fracao_quando_glifo', () {
    final r = analisarListaLocal('½ kg de queijo');
    expect(r.itens.single.quantidade, 0.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_fracao_quando_numerica', () {
    final r = analisarListaLocal('1/2 kg de queijo');
    expect(r.itens.single.quantidade, 0.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_misto_quando_espacado', () {
    final r = analisarListaLocal('1 1/2 kg de queijo');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_misto_quando_colado', () {
    final r = analisarListaLocal('1½ kg de queijo');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_fracao_quando_avulso', () {
    final item = interpretarItemAvulso('1/2 kg banana');
    expect(item!.quantidade, 0.5);
    expect(item.unidade, Unidade.kg);
  });
```

> Ajuste os imports do arquivo se `Unidade`/`interpretarItemAvulso` ainda não estiverem importados (o arquivo já importa as funções do parser; `Unidade` pode precisar de import).

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar um teste do editor (reuse o harness real; abra o editor de um item e digite a fração):

```dart
  testWidgets('deve_aceitar_fracao_quando_digitada_no_editor', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Queijo');
    // abrir a lista e tocar no item para abrir o editor (harness real)

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '1/2',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    final atualizado = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(atualizado.quantidade, 0.5);
    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL — `1/2`/`½` ainda viram item sem quantidade reconhecida (0.5 não).

- [ ] **Step 3: Implementar**

Em `lib/core/importacao/parser_lista_local.dart`:

1. Import: `import '../../features/listas/domain/quantidade.dart';` e manter `unidade.dart`.
2. Trocar os regex de quantidade (usando `glifosFracao`) e adicionar a fração-só:

```dart
const _qtd = r'(\d+(?:[.,]\d+)?|\d+\s*/\s*\d+|['+glifosFracao+r']|\d+['+glifosFracao+r'])';
final _soNumero = RegExp('^$_qtd\$');
final _numeroColado = RegExp('^$_qtd([a-zA-ZÀ-ÿ]+)\$');
final _soFracaoSo = RegExp(r'^(\d+\s*/\s*\d+|[½¼¾⅓⅔])$');
final _soInteiro = RegExp(r'^\d+$');
```

3. `_numeroDoToken` passa a usar `parseQuantidade`:

```dart
double? _numeroDoToken(String token) {
  final colado = _numeroColado.firstMatch(token);
  if (colado != null) return parseQuantidade(colado.group(1)!);
  final numero = _soNumero.firstMatch(token);
  if (numero != null) return parseQuantidade(numero.group(1)!);
  return null;
}
```

4. `_qtdInicio` — combinar o misto separado (`1 1/2 kg`):

```dart
(double, Unidade, int, bool)? _qtdInicio(List<String> t) {
  final colado = _numeroColado.firstMatch(t.first);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) {
      final q = parseQuantidade(colado.group(1)!)!;
      return (_quantidadeValida(q), unidade, 1, true);
    }
  }
  final numero = _soNumero.firstMatch(t.first);
  if (numero == null) return null;
  var qtd = parseQuantidade(numero.group(1)!)!;
  var consumidos = 1;
  if (t.length > 1 && _soFracaoSo.hasMatch(t[1])) {
    qtd += parseQuantidade(t[1])!;
    consumidos = 2;
  }
  if (t.length > consumidos) {
    final unidade = _unidades[normalizarTexto(t[consumidos])];
    if (unidade != null) return (_quantidadeValida(qtd), unidade, consumidos + 1, true);
  }
  return (_quantidadeValida(qtd), Unidade.un, consumidos, false);
}
```

5. `_qtdFim` — misto separado no fim (`Arroz 1 1/2`):

```dart
(double, Unidade, int, bool)? _qtdFim(List<String> t) {
  final colado = _numeroColado.firstMatch(t.last);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) {
      final q = parseQuantidade(colado.group(1)!)!;
      return (_quantidadeValida(q), unidade, t.length - 1, true);
    }
  }
  final numero = _soNumero.firstMatch(t.last);
  if (numero == null) return null;
  var qtd = parseQuantidade(numero.group(1)!)!;
  var inicioNome = t.length - 1;
  if (t.length >= 2 && _soInteiro.hasMatch(t[t.length - 2]) && _soFracaoSo.hasMatch(t.last)) {
    qtd += parseQuantidade(t[t.length - 2])!;
    inicioNome = t.length - 2;
  }
  final idxUnidade = inicioNome - 1;
  if (idxUnidade >= 0) {
    final unidade = _unidades[normalizarTexto(t[idxUnidade])];
    if (unidade != null) return (_quantidadeValida(qtd), unidade, idxUnidade, true);
  }
  return (_quantidadeValida(qtd), Unidade.un, inicioNome, false);
}
```

6. Remover `_paraDouble` (substituído por `parseQuantidade`) — verifique que não há outros usos (`grep _paraDouble`).

Em `lib/features/listas/ui/tela_lista_screen.dart`, `_quantidadeLida`:

```dart
  double? _quantidadeLida() {
    final valor = parseQuantidade(_quantidade.text);
    if (valor == null || valor <= 0) return null;
    return valor;
  }
```

Import de `quantidade.dart` (se ainda não importado).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/importacao/parser_lista_local.dart lib/features/listas/ui/tela_lista_screen.dart test/core/importacao/parser_lista_local_test.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F29-T02: parser e editor aceitam fracoes (RF-25)"
```

---

### Task 3: Docs donos e fechamento da Fase 29

**Files:**
- Modify: `docs/04-importacao-lista.md` (§3/§4 — frações no contrato)
- Modify: `docs/05-app-flutter.md` (§6.3 — entrada/editor)
- Modify: `docs/10-wireframes-telas.md` (nota de exibição com glifos)
- Modify: `docs/12-prd.md` (RF-25 + rastreabilidade)
- Modify: `docs/14-tarefas.md` (Fase 29 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A5 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: Docs 04 e 05 e 10**
  - `04 §3/§4`: o contrato do parser aceita fração numérica (`1/2`), mista (`1 1/2`) e glifos (`½`, `1½`), com exemplos; unidade/quantidade inalteradas no resto.
  - `05 §6.3`: o campo "Adicionar item" e o editor aceitam frações; a exibição usa glifos comuns (`½`, `1½`, `⅓`) e corta decimais longos.
  - `10`: nota curta de exibição (quantidade com glifo na linha do item).

- [ ] **Step 2: Doc 12 e 16**
  - `12 §2`: `RF-25 | Quantidades em fração na entrada e exibição (½, 1/2, 1 1/2) | 04 §3 + 05 §6.3 | F29 | ...`; §6: rastreabilidade `RF-25 | US-01, US-02 | F29 | F29-T01, F29-T02 | Unit parse/format + parser + editor`.
  - `16`: Onda A linha A5 → `concluído (F29-T01…T03)`.

- [ ] **Step 3: Doc 14 (Fase 29 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 29 com F29-T01…T03 `[x]` e CPs.
  - Na tabela, após `| F28 Ordem das categorias | 3 | 3 |`, adicionar `| F29 Quantidades em fração | 3 | 3 |` e atualizar o total para `| **Total** | **161** | **159** |`.

- [ ] **Step 4: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/04-importacao-lista.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F29-T03: docs donos e fechamento da Fase 29 (RF-25)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 domínio → Task 1; §4 parser → Task 2; §5 editor → Task 2; §6 testes → Tasks 1–2; §7 docs → Task 3.
- **Placeholders:** nenhum "TBD"; todo o código novo está completo. O teste do editor reusa o harness real (o implementador abre o editor pelo toque no item).
- **Consistência de tipos:** `parseQuantidade(String) -> double?`, `formatarQuantidade(double) -> String`, `glifosFracao`; parser reusa `parseQuantidade`; `_quantidadeLida` usa `parseQuantidade`; progresso 161/159 — idênticos entre tarefas.
- **Risco conhecido:** `formatarQuantidade` muda a exibição (`0.5` → `½`); testes existentes que esperem `0.5` precisam ser ajustados ao novo contrato (Task 1, Step 5).
