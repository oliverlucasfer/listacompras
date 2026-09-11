# Importação de Lista por Texto sem IA (Parser Local) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Importar listas de texto livre sem IA/rede (parser local determinístico), com a IA como modo opcional no mesmo modal.

**Architecture:** Tipos compartilhados e parser puro em `lib/core/importacao/`; normalizador em `lib/core/texto/`; UI de importação (modal com seletor Rápido/IA e pré-visualização) movida para `lib/features/importacao/ui/` com nomes genéricos; a IA permanece em `lib/features/ia/` (cliente + contrato).

**Tech Stack:** Flutter 3.44.5 · Dart 3.12 · flutter_riverpod 3.4.2 · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-11-importacao-local-design.md`

## Global Constraints

- Parser **puro**: sem rede, DB ou I/O.
- Sem novas dependências.
- Enums fechados de unidade/categoria; unidade mapeada para `Unidade`, categoria para `CategoriaItem`.
- Categoria pelo fluxo local existente (memória → dicionário → `outros`).
- Limite: **Rápido 10.000**; **IA 2.000** caracteres.
- `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` verdes.
- Comentários de código só quando indispensáveis (padrão do repo).

---

## File Structure

**Criar**
- `lib/core/texto/normalizar.dart` — `normalizarTexto`
- `lib/core/importacao/resposta_import.dart` — `ItemExtraido`, `RespostaParse`, `maxCaracteresImportLocal`
- `lib/core/importacao/parser_lista_local.dart` — `analisarListaLocal`
- `lib/features/ia/domain/contrato_ia.dart` — `ErroIa`, `mensagemContratoIa`, `maxCaracteresEntradaIa`
- `lib/features/importacao/ui/modal_importar.dart` — `ModalImportar`, `abrirModalImportar`, `ModoImportacao`
- `lib/features/importacao/ui/modal_previsao_importacao.dart` — `ModalPrevisaoImportacao`, `confirmarItensImportados`
- `test/core/importacao/parser_lista_local_test.dart`
- `test/features/importacao/modal_importar_test.dart`
- `test/features/importacao/modal_previsao_importacao_test.dart`

**Mover/renomear**
- `lib/features/ia/ui/modal_importar_ia.dart` → `lib/features/importacao/ui/modal_importar.dart`
- `lib/features/ia/ui/modal_previsao_ia.dart` → `lib/features/importacao/ui/modal_previsao_importacao.dart`
- `test/features/ia/modal_importar_ia_test.dart` → `test/features/importacao/modal_importar_test.dart`
- `test/features/ia/modal_previsao_ia_test.dart` → `test/features/importacao/modal_previsao_importacao_test.dart`
- `lib/features/ia/domain/resposta_parse.dart` → dividido (removido)

**Modificar**
- `lib/core/categorias/sugestao_categorias.dart` (reusa `normalizarTexto`)
- `lib/features/ia/data/parse_lista_client.dart`, `lib/features/ia/providers/ia_providers.dart`
- `lib/features/listas/ui/tela_lista_screen.dart`
- `lib/core/l10n/app_strings.dart`
- `docs/12-prd.md`, `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/04-ia-edge-function.md`, `docs/14-tarefas.md`

---

## Task F11-T00: RF-16 e docs de planejamento

**Files:** `docs/12-prd.md`, `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/04-ia-edge-function.md`, `docs/14-tarefas.md`

- [ ] **Step 1: RF-16 no PRD**

Em `docs/12-prd.md` §2, adicionar após RF-15:

```markdown
| RF-16 | Importação de lista por texto livre **sem IA** (parser local determinístico, offline), com pré-visualização editável; IA permanece como modo opcional | 05 §6.4 | F11 | [05 §8](05-app-flutter.md) |
```

E na matriz §6, adicionar a linha:

```markdown
| RF-16 | — | F11 | F11-T01…T03 | Unit parser + widgets |
```

- [ ] **Step 2: doc 05 §6.4 (dono do comportamento)**

Substituir o início do §6.4 por:

```markdown
### 6.4. Modal "Importar lista" (RF-06 + RF-16)

Um único modal com seletor de modo **Rápido** (padrão, local/offline, RF-16) e **IA** (RF-06):

1. Textarea + contador de caracteres (Rápido ≤ 10.000; IA ≤ 2.000 — [04 §2](04-ia-edge-function.md)).
2. Botão "Extrair itens":
   - **Rápido:** parser local puro (`lib/core/importacao/parser_lista_local.dart`), sem rede; categoria pela cadeia local (memória → dicionário → `outros`, [§3](05-app-flutter.md)); disponível offline.
   - **IA:** fluxo atual (Edge Function `parse-lista`, loading e erros do contrato).
3. **Pré-visualização editável** (checkboxes, edição inline de nome/quantidade/unidade/categoria; `aviso`) — comum aos dois modos.
4. "Adicionar N itens à lista" → grava localmente (fila de INSERTs).
```

- [ ] **Step 3: doc 10 §4.1 (wireframe)**

Após o título `### 4.1. Modal de entrada`, adicionar:

```markdown
> Nota (RF-16): o modal tem um `SegmentedButton` no topo — **Rápido** | **IA** (Rápido padrão). O botão vira "Extrair itens" e o limite passa a 10.000 no modo Rápido.
```

- [ ] **Step 4: doc 04 §1 (IA opcional)**

Após o fluxo de UX em `docs/04-ia-edge-function.md §1`, adicionar:

```markdown
> **IA é opcional (RF-16):** o app oferece um modo de importação **local** (parser determinístico, offline) como padrão; a Edge Function é acionada apenas no modo IA.
```

- [ ] **Step 5: Fase 11 em `14-tarefas.md`**

Adicionar após a Fase 10 e antes do "## Progresso por fase":

```markdown
## Fase 11 — Importação local sem IA (spec em [superpowers/specs](superpowers/specs/2026-09-11-importacao-local-design.md))

- [ ] **F11-T00** — RF-16 + docs de planejamento
  Dep: F10-T04 · Docs: spec da fase
  CP: RF-16 no 12; 05 §6.4, 10 §4.1 e 04 §1 atualizados; Fase 11 no 14; sem tocar código de app.
- [ ] **F11-T01** — Tipos de importação, normalizador e parser local
  Dep: F11-T00 · Docs: [05 §3/§6.4](05-app-flutter.md), [01 §3](01-banco-de-dados.md)
  CP: parser puro com unit tests dos casos da spec §8; imports atualizados; `analyze`/`test` verdes.
- [ ] **F11-T02** — Modal com seletor Rápido/IA + pré-visualização (nomes genéricos)
  Dep: F11-T01 · Docs: [05 §6.4](05-app-flutter.md), [10 §4](10-wireframes-telas.md)
  CP: modo Rápido offline e modo IA preservado; botão "Importar lista"; testes verdes.
- [ ] **F11-T03** — Verificação final, docs e CI
  Dep: F11-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: `format`/`analyze`/`test` verdes; fase marcada.
```

Atualizar a tabela de progresso: nova linha `| F11 Import local | 4 | 0 |` e total `71→75` / `69→69`.

- [ ] **Step 6: Commit**

```bash
git add docs/12-prd.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/04-ia-edge-function.md docs/14-tarefas.md
git commit -m "F11-T00: RF-16 e planejamento da importacao local sem IA"
```

---

## Task F11-T01: Tipos, normalizador e parser local

**Files:**
- Create: `lib/core/texto/normalizar.dart`, `lib/core/importacao/resposta_import.dart`, `lib/core/importacao/parser_lista_local.dart`, `lib/features/ia/domain/contrato_ia.dart`
- Modify: `lib/core/categorias/sugestao_categorias.dart`, `lib/features/ia/data/parse_lista_client.dart`, `lib/features/ia/providers/ia_providers.dart`, `lib/core/l10n/app_strings.dart`, `test/features/ia/parse_lista_client_test.dart`
- Delete: `lib/features/ia/domain/resposta_parse.dart`
- Test: `test/core/importacao/parser_lista_local_test.dart`

**Interfaces:**
- Produces: `String normalizarTexto(String)`; `class ItemExtraido { String nome; double quantidade; Unidade unidade; CategoriaItem categoria; }`; `class RespostaParse { List<ItemExtraido> itens; String? aviso; }`; `const int maxCaracteresImportLocal = 10000;`; `RespostaParse analisarListaLocal(String texto)`; `class ErroIa { String code; String mensagem; }`; `String mensagemContratoIa(String)`; `const int maxCaracteresEntradaIa = 2000;`.

- [ ] **Step 1: Criar o normalizador**

`lib/core/texto/normalizar.dart`:

```dart
/// minúsculas + sem acento (pt-BR) + espaços colapsados nas pontas.
String normalizarTexto(String texto) {
  const acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final semAcento = texto
      .toLowerCase()
      .split('')
      .map((c) => acentos[c] ?? c)
      .join();
  return semAcento.trim().replaceAll(RegExp(r'\s+'), ' ');
}
```

- [ ] **Step 2: Mover os tipos compartilhados**

`lib/core/importacao/resposta_import.dart`:

```dart
import '../../features/listas/domain/categoria.dart';
import '../../features/listas/domain/unidade.dart';

/// Limite do modo local (sem IA) — spec RF-16.
const int maxCaracteresImportLocal = 10000;

/// Item importado (doc/contrato de importação): quantidade > 0, unidade no
/// enum fechado e categoria no enum fechado.
class ItemExtraido {
  const ItemExtraido({
    required this.nome,
    required this.quantidade,
    required this.unidade,
    this.categoria = CategoriaItem.outros,
  });

  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
}

/// Resultado da extração (local ou IA): itens + aviso opcional.
class RespostaParse {
  const RespostaParse({required this.itens, required this.aviso});

  final List<ItemExtraido> itens;
  final String? aviso;
}
```

`lib/features/ia/domain/contrato_ia.dart`:

```dart
import '../../../core/l10n/app_strings.dart';

/// Limite de entrada do contrato da IA (docs 04 §2/§3).
const int maxCaracteresEntradaIa = 2000;

/// Erro do contrato de IA (doc 04 §2): `code` para lógica, mensagem pronta
/// para a UI.
class ErroIa implements Exception {
  const ErroIa(this.code, this.mensagem);

  final String code;
  final String mensagem;
}

/// Mensagem amigável por código do contrato (doc 04 §2).
String mensagemContratoIa(String code) => switch (code) {
  'unauthorized' => AppStrings.iaSessaoExpirada,
  'texto_vazio' => AppStrings.iaTextoVazio,
  'texto_longo' => AppStrings.iaTextoLongo,
  'resposta_invalida' => AppStrings.iaRespostaInvalida,
  'rate_limit' => AppStrings.iaRateLimit,
  'cota_ia' => AppStrings.iaCotaIa,
  'timeout_ia' => AppStrings.iaTimeoutIa,
  _ => AppStrings.iaErroInterno,
};
```

Apagar `lib/features/ia/domain/resposta_parse.dart`.

- [ ] **Step 3: Atualizar imports do cliente e do provider**

Em `lib/features/ia/data/parse_lista_client.dart`, trocar
`import '../domain/resposta_parse.dart';` por:

```dart
import '../../../core/importacao/resposta_import.dart';
import '../domain/contrato_ia.dart';
```

Em `lib/features/ia/providers/ia_providers.dart`, nenhum import de domínio a mudar (só o cliente).

Em `test/features/ia/parse_lista_client_test.dart`, trocar o import
`.../features/ia/domain/resposta_parse.dart` por
`package:lista_compras/core/importacao/resposta_import.dart` (e, se o teste usar `ErroIa`/`mensagemContratoIa`/`maxCaracteresEntradaIa`, adicionar `package:lista_compras/features/ia/domain/contrato_ia.dart`).

- [ ] **Step 4: Reusar o normalizador em `SugestaoCategorias`**

Em `lib/core/categorias/sugestao_categorias.dart`: importar `../texto/normalizar.dart`, substituir as chamadas `_normalizar(` por `normalizarTexto(` e **remover** a função privada `_normalizar` no fim do arquivo.

- [ ] **Step 5: Strings novas**

Em `lib/core/l10n/app_strings.dart`:

```dart
  static const importarLista = 'Importar lista';
  static const modoRapido = 'Rápido';
  static const modoIa = 'IA';
  static const importLocalAvisoPadrao =
      'Itens sem quantidade entraram com 1 un.';
  static const importLocalTextoLongo =
      'Texto muito longo. Envie até 10.000 caracteres.';
```

- [ ] **Step 6: Escrever o teste que falha do parser**

`test/core/importacao/parser_lista_local_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/parser_lista_local.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  test('deve_extrair_quantidade_unidade_e_nome_quando_1kg_de_arroz', () {
    final r = analisarListaLocal('1kg de arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_usar_1_un_quando_sem_quantidade_e_marcar_aviso', () {
    final r = analisarListaLocal('2 leites\nbanana');
    expect(r.itens.map((i) => i.nome), ['Leites', 'Banana']);
    expect(r.itens.first.quantidade, 2);
    expect(r.itens.last.quantidade, 1);
    expect(r.itens.last.unidade, Unidade.un);
    expect(r.aviso, isNotNull);
  });

  test('deve_reconhecer_quantidade_no_fim_quando_arroz_1kg', () {
    final r = analisarListaLocal('arroz 1kg');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_segmentar_por_virgula_ponto_e_virgula_linha_e_conjuncao', () {
    final r = analisarListaLocal('arroz, leite; pão\ncafé e açúcar');
    expect(r.itens.map((i) => i.nome), ['Arroz', 'Leite', 'Pão', 'Café', 'Açúcar']);
  });

  test('deve_mapear_sinonimos_de_unidade', () {
    expect(analisarListaLocal('2 quilos de feijão').itens.single.unidade, Unidade.kg);
    expect(analisarListaLocal('500 gramas queijo').itens.single.unidade, Unidade.g);
    expect(analisarListaLocal('2 litros de leite').itens.single.unidade, Unidade.l);
    expect(analisarListaLocal('1 cx de ovos').itens.single.unidade, Unidade.caixa);
    expect(analisarListaLocal('3 pct de café').itens.single.unidade, Unidade.pacote);
    expect(analisarListaLocal('1 dúzia de bananas').itens.single.unidade, Unidade.dz);
  });

  test('deve_tolerar_acento_e_caixa', () {
    expect(analisarListaLocal('1 DÚZIA DE BANANAS').itens.single.unidade, Unidade.dz);
  });

  test('deve_ignorar_texto_vazio', () {
    expect(analisarListaLocal('   ').itens, isEmpty);
  });
}
```

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: FAIL (arquivo do parser não existe).

- [ ] **Step 7: Implementar o parser**

`lib/core/importacao/parser_lista_local.dart`:

```dart
import '../../core/l10n/app_strings.dart';
import '../texto/normalizar.dart';
import 'resposta_import.dart';

const Map<String, Unidade> _unidades = {
  'un': Unidade.un, 'unidade': Unidade.un, 'unidades': Unidade.un,
  'kg': Unidade.kg, 'quilo': Unidade.kg, 'quilos': Unidade.kg,
  'quilograma': Unidade.kg, 'quilogramas': Unidade.kg,
  'g': Unidade.g, 'grama': Unidade.g, 'gramas': Unidade.g,
  'l': Unidade.l, 'litro': Unidade.l, 'litros': Unidade.l,
  'ml': Unidade.ml, 'mililitro': Unidade.ml, 'mililitros': Unidade.ml,
  'caixa': Unidade.caixa, 'caixas': Unidade.caixa, 'cx': Unidade.caixa,
  'pacote': Unidade.pacote, 'pacotes': Unidade.pacote, 'pct': Unidade.pacote,
  'dz': Unidade.dz, 'duzia': Unidade.dz, 'duzias': Unidade.dz,
};

const _conectivos = {'de', 'do', 'da', 'em', 'dos', 'das'};

final _separadores = RegExp(r'[\n,;]+|\s+e\s+', caseSensitive: false);
final _soNumero = RegExp(r'^(\d+(?:[.,]\d+)?)$');
final _numeroColado = RegExp(r'^(\d+(?:[.,]\d+)?)([a-zA-ZÀ-ÿ]+)$');

/// Parser local determinístico (RF-16): extrai itens de texto livre, offline.
RespostaParse analisarListaLocal(String texto) {
  final itens = <ItemExtraido>[];
  var algumSemNumero = false;
  for (final parte in texto.split(_separadores)) {
    final item = _parseSegmento(parte);
    if (item == null) continue;
    itens.add(item);
    if (item.quantidade == 1 && !_tinhaNumero(parte)) algumSemNumero = true;
  }
  return RespostaParse(
    itens: itens,
    aviso: algumSemNumero ? AppStrings.importLocalAvisoPadrao : null,
  );
}

bool _tinhaNumero(String parte) {
  final tokens = parte.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty) return false;
  return _soNumero.hasMatch(tokens.first) ||
      _numeroColado.hasMatch(tokens.first) ||
      _soNumero.hasMatch(tokens.last) ||
      _numeroColado.hasMatch(tokens.last);
}

ItemExtraido? _parseSegmento(String bruto) {
  final texto = bruto.trim().replaceAll(RegExp(r'[.]$'), '');
  if (texto.isEmpty) return null;
  final tokens = texto.split(RegExp(r'\s+'));

  // (qtd, unidade, índice inicial do nome)
  (double, Unidade, int)? inicio = _qtdInicio(tokens);
  (double, Unidade, int)? fim = _qtdFim(tokens);

  late double qtd;
  late Unidade unidade;
  late List<String> nome;
  if (inicio != null) {
    qtd = inicio.$1;
    unidade = inicio.$2;
    var i = inicio.$3;
    if (i < tokens.length && _conectivos.contains(normalizarTexto(tokens[i]))) {
      i++;
    }
    nome = tokens.sublist(i);
  } else if (fim != null) {
    qtd = fim.$1;
    unidade = fim.$2;
    var j = fim.$3;
    if (j > 0 && _conectivos.contains(normalizarTexto(tokens[j - 1]))) j--;
    nome = tokens.sublist(0, j);
  } else {
    qtd = 1;
    unidade = Unidade.un;
    nome = tokens;
  }

  final limpo = nome.join(' ').trim();
  if (limpo.isEmpty) return null;
  return ItemExtraido(
    nome: limpo[0].toUpperCase() + limpo.substring(1),
    quantidade: qtd,
    unidade: unidade,
  );
}

(double, Unidade, int)? _qtdInicio(List<String> t) {
  final mColado = _numeroColado.firstMatch(t.first);
  if (mColado != null) {
    final unidade = _unidades[normalizarTexto(mColado.group(2)!)];
    if (unidade != null) return (_paraDouble(mColado.group(1)!), unidade, 1);
  }
  final mNumero = _soNumero.firstMatch(t.first);
  if (mNumero == null) return null;
  final qtd = _paraDouble(mNumero.group(1)!);
  if (t.length > 1) {
    final unidade = _unidades[normalizarTexto(t[1])];
    if (unidade != null) return (qtd, unidade, 2);
  }
  return (qtd, Unidade.un, 1);
}

(double, Unidade, int)? _qtdFim(List<String> t) {
  final mColado = _numeroColado.firstMatch(t.last);
  if (mColado != null) {
    final unidade = _unidades[normalizarTexto(mColado.group(2)!)];
    if (unidade != null) return (_paraDouble(mColado.group(1)!), unidade, t.length - 1);
  }
  final mNumero = _soNumero.firstMatch(t.last);
  if (mNumero == null) return null;
  final qtd = _paraDouble(mNumero.group(1)!);
  if (t.length > 1) {
    final unidade = _unidades[normalizarTexto(t[t.length - 2])];
    if (unidade != null) return (qtd, unidade, t.length - 2);
  }
  return (qtd, Unidade.un, t.length - 1);
}

double _paraDouble(String valor) => double.parse(valor.replaceAll(',', '.'));
```

> Nota: `_qtdInicio` só retorna quando há número no início; `_qtdFim` idem no fim. Se houver número no início **e** no fim (ex.: "2 refri de 2 litros"), o início vence — comportamento aceitável (o usuário edita na pré-visualização).

- [ ] **Step 8: Rodar o teste para ver passar**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 9: Garantir que a suíte atual compila e passa**

Run: `flutter analyze; flutter test`
Expected: analyze limpo (imports atualizados); testes verdes.

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/core/texto lib/core/importacao lib/core/categorias/sugestao_categorias.dart lib/features/ia lib/core/l10n/app_strings.dart test/core/importacao
git commit -m "F11-T01: parser local de importacao + tipos compartilhados (RF-16)"
```

---

## Task F11-T02: Modal com seletor Rápido/IA + pré-visualização genérica

**Files:**
- Create: `lib/features/importacao/ui/modal_importar.dart`, `lib/features/importacao/ui/modal_previsao_importacao.dart`
- Delete: `lib/features/ia/ui/modal_importar_ia.dart`, `lib/features/ia/ui/modal_previsao_ia.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Test: move/rename `test/features/ia/modal_*` → `test/features/importacao/modal_*`

**Interfaces:**
- Consumes: `analisarListaLocal`, `RespostaParse`, `ItemExtraido`, `maxCaracteresImportLocal` (T01); `parseListaClientProvider`, `ErroIa`, `maxCaracteresEntradaIa` (ia); `sugestaoCategoriasProvider`.
- Produces: `enum ModoImportacao { rapido, ia }`; `Future<RespostaParse?> abrirModalImportar(BuildContext, WidgetRef, String listaId, {ModoImportacao modoInicial})`; `class ModalImportar`; `Future<void> confirmarItensImportados(...)`; `class ModalPrevisaoImportacao`.

- [ ] **Step 1: Mover a pré-visualização (renomear)**

Mover `lib/features/ia/ui/modal_previsao_ia.dart` → `lib/features/importacao/ui/modal_previsao_importacao.dart` e ajustar:
- imports relativos: `../../../core/l10n/app_strings.dart`, `../../../core/theme/tokens/app_spacing.dart`, `../../../core/widgets/app_banner.dart`, `../../../core/widgets/app_botao.dart`, `../../../core/widgets/app_snack_bar.dart`, `../../../core/importacao/resposta_import.dart`, `../../listas/domain/categoria.dart`, `../../listas/domain/unidade.dart`, `../../listas/providers/listas_providers.dart`.
- renomear `ModalPrevisaoIa` → `ModalPrevisaoImportacao` e `_ModalPrevisaoIaState` → `_ModalPrevisaoImportacaoState`.
- `confirmarItensImportados` permanece com a mesma assinatura e corpo.

- [ ] **Step 2: Mover o modal de entrada e adicionar o seletor**

Mover `lib/features/ia/ui/modal_importar_ia.dart` → `lib/features/importacao/ui/modal_importar.dart` e substituir o conteúdo por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/importacao/resposta_import.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../ia/domain/contrato_ia.dart';
import '../../ia/providers/ia_providers.dart';
import '../../listas/domain/categoria.dart';
import '../../listas/domain/unidade.dart';
import '../../listas/providers/listas_providers.dart';

/// Modo de importação (RF-16): Rápido = parser local offline; IA = Edge Function.
enum ModoImportacao { rapido, ia }

/// Abre o modal de entrada da importação de lista (doc 05 §6.4, RF-06/RF-16).
/// Retorna os itens extraídos, ou null se cancelado.
Future<RespostaParse?> abrirModalImportar(
  BuildContext context,
  WidgetRef ref,
  String listaId, {
  ModoImportacao modoInicial = ModoImportacao.rapido,
}) {
  return showDialog<RespostaParse>(
    context: context,
    builder: (_) => ModalImportar(listaId: listaId, modoInicial: modoInicial),
  );
}

class ModalImportar extends ConsumerStatefulWidget {
  const ModalImportar({
    super.key,
    required this.listaId,
    this.modoInicial = ModoImportacao.rapido,
  });

  final String listaId;
  final ModoImportacao modoInicial;

  @override
  ConsumerState<ModalImportar> createState() => _ModalImportarState();
}

class _ModalImportarState extends ConsumerState<ModalImportar> {
  final _controller = TextEditingController();
  late ModoImportacao _modo = widget.modoInicial;
  bool _carregando = false;
  String? _erro;

  int get _limite => _modo == ModoImportacao.rapido
      ? maxCaracteresImportLocal
      : maxCaracteresEntradaIa;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _erro = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _caracteres => _controller.text.length;

  bool get _podeExtrair =>
      !_carregando &&
      _controller.text.trim().isNotEmpty &&
      _caracteres <= _limite;

  Future<void> _extrair() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = _modo == ModoImportacao.rapido
          ? await _extrairLocal(_controller.text)
          : await ref.read(parseListaClientProvider).parse(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroIa catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.mensagem;
        });
      }
    }
  }

  /// Parser local + categoria pela cadeia do app (memória → dicionário).
  Future<RespostaParse> _extrairLocal(String texto) async {
    final parse = analisarListaLocal(texto);
    if (parse.itens.isEmpty) {
      throw const ErroIa('resposta_invalida', AppStrings.iaRespostaInvalida);
    }
    final sugestao = ref.read(sugestaoCategoriasProvider);
    final enriquecidos = <ItemExtraido>[];
    for (final item in parse.itens) {
      final categoria = await sugestao.sugerirCategoria(item.nome);
      enriquecidos.add(
        ItemExtraido(
          nome: item.nome,
          quantidade: item.quantidade,
          unidade: item.unidade,
          categoria: categoria,
        ),
      );
    }
    return RespostaParse(itens: enriquecidos, aviso: parse.aviso);
  }

  @override
  Widget build(BuildContext context) {
    final excedeu = _caracteres > _limite;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(AppStrings.importarLista)),
          IconButton(
            tooltip: AppStrings.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ModoImportacao>(
            segments: const [
              ButtonSegment(
                value: ModoImportacao.rapido,
                label: Text(AppStrings.modoRapido),
                icon: Icon(Icons.bolt_outlined),
              ),
              ButtonSegment(
                value: ModoImportacao.ia,
                label: Text(AppStrings.modoIa),
                icon: Icon(Icons.auto_awesome),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() {
              _modo = s.first;
              _erro = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(AppStrings.iaColeOuDigite),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(hintText: AppStrings.iaExemplo),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_caracteres/$_limite',
              style: excedeu
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
          ],
          const SizedBox(height: AppSpacing.md),
          AppBotao(
            rotulo: _carregando ? AppStrings.iaLendo : AppStrings.iaExtrairItens,
            icone: _modo == ModoImportacao.ia
                ? Icons.auto_awesome
                : Icons.bolt_outlined,
            carregando: _carregando,
            onPressed: _podeExtrair ? _extrair : null,
          ),
        ],
      ),
    );
  }
}
```

> `sugestaoCategoriasProvider` já é exportado por `listas_providers.dart`; `CategoriaItem`/`Unidade` importados para o resultado.

- [ ] **Step 3: Atualizar a tela da lista**

Em `lib/features/listas/ui/tela_lista_screen.dart`, trocar os imports:

```dart
import '../../importacao/ui/modal_importar.dart';
import '../../importacao/ui/modal_previsao_importacao.dart';
```

e no bloco `_importarPorIa` trocar `abrirModalImportarIa(` por `abrirModalImportar(`. O botão usa `AppStrings.importarPorIa` → trocar por `AppStrings.importarLista` (texto "Importar lista").

- [ ] **Step 4: Mover e ajustar os testes**

Mover `test/features/ia/modal_importar_ia_test.dart` → `test/features/importacao/modal_importar_test.dart`:
- imports: `package:lista_compras/features/importacao/ui/modal_importar.dart`, `package:lista_compras/core/importacao/resposta_import.dart`, `package:lista_compras/features/ia/data/parse_lista_client.dart`, `package:lista_compras/features/ia/domain/contrato_ia.dart`, `package:lista_compras/features/ia/providers/ia_providers.dart`.
- no `_TelaAbrirModal`, chamar `abrirModalImportar(context, ref, 'lista-1', modoInicial: ModoImportacao.ia)` (os casos atuais testam o modo IA).
- adicionar testes do modo local:

```dart
  testWidgets('deve_extrair_localmente_quando_modo_rapido', (tester) async {
    RespostaParse? recebida;
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
      onResultado: (r) => recebida = r,
      modo: ModoImportacao.rapido,
    );
    await tester.enterText(find.byType(TextField), '1kg de arroz, 2 leites');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.iaExtrairItens));
    await tester.pumpAndSettle();

    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(2));
    expect(recebida!.itens.first.unidade.valor, 'kg');
    await tester.pumpWidget(const SizedBox.shrink());
  });
```

Isso exige que `abrir(...)` aceite `ModoImportacao modo = ModoImportacao.ia` e passe `modoInicial: modo` no `_TelaAbrirModal`. Ajustar o helper e a `_TelaAbrirModal` para receber o modo.

Mover `test/features/ia/modal_previsao_ia_test.dart` → `test/features/importacao/modal_previsao_importacao_test.dart`:
- imports: `package:lista_compras/core/importacao/resposta_import.dart`, `package:lista_compras/features/importacao/ui/modal_previsao_importacao.dart`.
- se o teste referenciar `ModalPrevisaoIa`, trocar por `ModalPrevisaoImportacao` (o entry `confirmarItensImportados` não muda).

- [ ] **Step 5: Rodar os testes de importação e o analyze**

Run: `flutter test test/features/importacao test/core/importacao; flutter analyze`
Expected: PASS; analyze limpo.

- [ ] **Step 6: Rodar a suíte completa**

Run: `flutter test`
Expected: todos verdes (a suíte da tela da lista cobre o botão/renome).

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add -A lib/features/importacao lib/features/ia lib/features/listas/ui/tela_lista_screen.dart test/features/importacao
git commit -m "F11-T02: modal Importar lista com modos Rapido/IA e nomes genericos (RF-16)"
```

---

## Task F11-T03: Verificação final e fechamento

**Files:** `docs/14-tarefas.md`

- [ ] **Step 1: CI local**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Expected: tudo verde.

- [ ] **Step 2: Marcar a fase 11**

Em `docs/14-tarefas.md`, trocar `- [ ]` por `- [x]` em F11-T00…F11-T03 e atualizar a tabela: `| F11 Import local | 4 | 4 |` e total `| **Total** | **75** | **73** |`.

- [ ] **Step 3: Commit**

```bash
git add docs/14-tarefas.md
git commit -m "F11-T03: fecha a importacao local sem IA (CI verde, RF-16)"
```

---

## Notas de execução

- A pré-visualização e a gravação são as mesmas para os dois modos — só muda o motor de extração.
- O modo Rápido não usa rede nem IA; a categoria vem de `SugestaoCategorias` (memória → dicionário → `outros`).
- Nenhuma mudança de schema/contrato; sem migration.
- Doc dono: comportamento de importação é do **05 §6.4**; requisito é o **12 (RF-16)**.
