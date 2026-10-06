# Preço por Etiqueta (OCR da Prateleira) — Plano de Implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans` para executar tarefa a tarefa. Os passos usam checkbox (`- [ ]`).

**Goal:** Ler a etiqueta de prateleira com a câmera (OCR on-device) e, sem digitar, criar um item novo com preço, aplicar o preço a um item existente (modo mercado) ou preencher o campo "Preço (R$)" do editor.

**Architecture:** Um domínio novo e puro (`analisarEtiqueta`) extrai preço/nome do texto do OCR; a captura câmera/galeria + OCR já existente (RF-37) é extraída para um helper compartilhado; dois pontos de entrada (modo mercado e editor) consomem o resultado. 100% offline, sem dependência nem permissão nova.

**Tech Stack:** Flutter + Riverpod + Drift; `google_mlkit_text_recognition` e `image_picker` (já no projeto); l10n em pt/en/es.

**Spec:** [docs/superpowers/specs/2026-10-06-etiqueta-preco-camera-design.md](../specs/2026-10-06-etiqueta-preco-camera-design.md)

## Global Constraints

- **Offline total:** nenhuma rede; o Drift é a fonte da verdade; IDs UUID v4 no cliente.
- **Sem dependência nova e sem permissão nova:** reusar `OcrTexto`/`FonteImagem` (ML Kit + `image_picker`); `CAMERA`/`NSCameraUsageDescription` já existem. A imagem **não é persistida** (1 imagem por leitura).
- **Gate de plataforma:** tudo atrás de `plataformaComOcr()` (Android/iOS); Web/Desktop não mostram botões nem tocam os plugins.
- **Enum de unidades fechado:** `un, kg, g, l, ml, caixa, pacote, pct, pt, dz` (`lib/core/dominio/unidade.dart`).
- **Doc dono é autoridade:** comportamento/UI/requisito só mudam com o doc dono atualizado **no mesmo PR** (12 requisitos, 05 app, 10 layout, 09 operação, 15 design, 13 resumo, 14 tarefas).
- **i18n:** strings nos 3 ARB (`app_pt.arb` template, `app_en.arb`, `app_es.arb`).
- **Bump de versão:** ao mudar `version:` no `pubspec.yaml`, manter `web/version.json` em paridade (`version` e `build_number`) — guard `test/core/config/version_json_test.dart`.
- **CI verde:** `dart format .` + `flutter analyze` + `flutter test` antes de concluir qualquer tarefa.
- **Sem segredos** em código/commit/log. Commits concisos em pt-BR mencionando `RF-40` e o ID da tarefa (`F59-Txx`).

---

### Task 1: Domínio `analisarEtiqueta` (parser puro)

**Files:**
- Create: `lib/features/etiqueta/domain/etiqueta.dart`
- Test: `test/features/etiqueta/etiqueta_test.dart`

**Interfaces:**
- Consumes: `parsePrecoParaCentavos(String?) → int?` de `lib/features/listas/domain/preco.dart` (lança `ArgumentError` em inválido/negativo/acima do teto).
- Produces:
  - `class EtiquetaLida { final String? nome; final int precoCentavos; final int? precoPorKgCentavos; const EtiquetaLida({this.nome, required this.precoCentavos, this.precoPorKgCentavos}); }`
  - `EtiquetaLida? analisarEtiqueta(String texto)` — `null` quando nenhum preço é encontrado.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/features/etiqueta/etiqueta_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/etiqueta/domain/etiqueta.dart';

void main() {
  test('deve_extrair_preco_cheio_quando_etiqueta_simples', () {
    final e = analisarEtiqueta('Arroz Tio Joao\nR\$ 5,49');
    expect(e, isNotNull);
    expect(e!.nome, 'Arroz Tio Joao');
    expect(e.precoCentavos, 549);
    expect(e.precoPorKgCentavos, isNull);
  });

  test('deve_preferir_preco_do_por_quando_promocao', () {
    final e = analisarEtiqueta('de R\$ 9,99 por R\$ 6,99');
    expect(e!.precoCentavos, 699);
  });

  test('deve_usar_valor_por_kg_como_fallback_quando_unico', () {
    final e = analisarEtiqueta('R\$ 12,90/kg');
    expect(e!.precoCentavos, 1290);
    expect(e.precoPorKgCentavos, 1290);
  });

  test('deve_ignorar_valor_por_kg_quando_ha_preco_cheio', () {
    final e = analisarEtiqueta('Queijo\nR\$ 39,90\nR\$ 79,80/kg');
    expect(e!.precoCentavos, 3990);
    expect(e.precoPorKgCentavos, 7980);
  });

  test('deve_aceitar_milhar_quando_preco_grande', () {
    final e = analisarEtiqueta('TV 50 polegadas\nR\$ 1.234,56');
    expect(e!.precoCentavos, 123456);
  });

  test('deve_retornar_null_quando_sem_preco', () {
    expect(analisarEtiqueta('Oferta da semana'), isNull);
  });

  test('deve_omitir_nome_quando_etiqueta_so_preco', () {
    final e = analisarEtiqueta(r'R$ 5,49');
    expect(e!.nome, isNull);
    expect(e.precoCentavos, 549);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/etiqueta/etiqueta_test.dart`
Expected: FAIL — erro de import (arquivo `etiqueta.dart` não existe).

- [ ] **Step 3: Implementar**

Crie `lib/features/etiqueta/domain/etiqueta.dart`:

```dart
import '../../listas/domain/preco.dart';

/// Resultado da leitura de uma etiqueta de prateleira (RF-40).
class EtiquetaLida {
  const EtiquetaLida({
    this.nome,
    required this.precoCentavos,
    this.precoPorKgCentavos,
  });

  final String? nome;
  final int precoCentavos;
  final int? precoPorKgCentavos;
}

// Um número monetário: milhar com vírgula, vírgula decimal, ponto decimal
// (até 2 casas) ou inteiro — nesta ordem de precedência.
final _numero = RegExp(
  r'\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+,\d{1,2}|\d+\.\d{1,2}|\d+',
);

// Valor imediatamente após "por" (promo "de X por Y").
final _aposPor = RegExp(
  'por\\s*r?\\\$?\\s*(${_numero.pattern})',
  caseSensitive: false,
);

// Contexto de preço por kg / por 100 g / por unidade (não é o preço do item).
final _contextoKg = RegExp(
  r'(r\s*\$\s*/?\s*kg|/\s*kg|por\s*kg|por\s*100\s*g|por\s*unidade)',
  caseSensitive: false,
);

final _letras = RegExp(r'[A-Za-zÀ-ÿ]');
final _simbolos = RegExp(r'[\dR$.,/\-]');

/// Extrai preço (preço cheio; valor por kg como fallback) e, best-effort, o
/// nome do produto a partir do texto do OCR. Determinístico e offline.
/// Devolve `null` se nenhum preço for encontrado.
EtiquetaLida? analisarEtiqueta(String texto) {
  final linhas = <String>[
    for (final l in texto.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  final naoKg = <int>[];
  final porKg = <int>[];
  final promocional = <int>[];
  String? nome;

  for (final linha in linhas) {
    final ehKg = _contextoKg.hasMatch(linha);
    for (final m in _numero.allMatches(linha)) {
      final centavos = _centavos(m.group(0)!);
      if (centavos == null) continue;
      (ehKg ? porKg : naoKg).add(centavos);
    }
    for (final m in _aposPor.allMatches(linha)) {
      final centavos = _centavos(m.group(1)!);
      if (centavos != null) promocional.add(centavos);
    }
    nome ??= _nomeDaLinha(linha);
  }

  if (promocional.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: promocional.last,
      precoPorKgCentavos: _maior(porKg),
    );
  }
  if (naoKg.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: _maior(naoKg)!,
      precoPorKgCentavos: _maior(porKg),
    );
  }
  if (porKg.isNotEmpty) {
    final preco = _maior(porKg)!;
    return EtiquetaLida(
      nome: nome,
      precoCentavos: preco,
      precoPorKgCentavos: preco,
    );
  }
  return null;
}

int? _centavos(String bruto) {
  try {
    final c = parsePrecoParaCentavos(bruto);
    return (c == null || c <= 0) ? null : c;
  } on ArgumentError {
    return null;
  }
}

int? _maior(List<int> valores) {
  if (valores.isEmpty) return null;
  return valores.reduce((a, b) => a > b ? a : b);
}

/// Nome provável: primeira linha com ≥ 3 letras que não seja preço/promo/kg.
String? _nomeDaLinha(String linha) {
  final lower = linha.toLowerCase();
  if (lower.contains(r'r$') || lower.contains('por') || lower.contains('kg')) {
    return null;
  }
  final letras = _letras.allMatches(linha.replaceAll(_simbolos, '')).length;
  return letras >= 3 ? linha : null;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/etiqueta/etiqueta_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Formatar e analisar**

Run: `dart format lib/features/etiqueta test/features/etiqueta; flutter analyze lib/features/etiqueta test/features/etiqueta`
Expected: sem erros.

- [ ] **Step 6: Commit**

```bash
git add lib/features/etiqueta/domain/etiqueta.dart test/features/etiqueta/etiqueta_test.dart
git commit -m "feat(etiqueta): parser analisarEtiqueta (RF-40, F59-T01)"
```

---

### Task 2: Repositório — preço opcional na dedup

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart:268-310` (`adicionarItemDedup`)
- Test: `test/features/listas/listas_repository_test.dart` (adicionar um teste ao final de `main`)

**Interfaces:**
- Produces: `Future<ResultadoDedup> adicionarItemDedup({required String listaId, required String nome, required double quantidade, required Unidade unidade, required CategoriaItem categoria, int? precoCentavos})` — novo parâmetro **opcional**; quando informado, grava o preço no item inserido e o atualiza no item existente (soma/substituição preservadas quando `null`).
- Consumes: `adicionarItem(..., precoCentavos:)` e `editarItem(id, ..., precoCentavos:)` já existentes.

- [ ] **Step 1: Escrever o teste que falha**

Acrescente em `test/features/listas/listas_repository_test.dart`, dentro de `main()`:

```dart
  test('deve_aplicar_preco_quando_dedup_com_preco', () async {
    final lista = await repo.criarLista(titulo: 'L', donoId: 'local');
    await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
      unidade: Unidade.un,
      categoria: CategoriaItem.mercearia,
      precoCentavos: 549,
    );
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549);
  });

  test('deve_atualizar_preco_quando_dedup_em_item_existente', () async {
    final lista = await repo.criarLista(titulo: 'L', donoId: 'local');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 100,
    );
    await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
      unidade: Unidade.un,
      categoria: CategoriaItem.mercearia,
      precoCentavos: 549,
    );
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: FAIL — `adicionarItemDedup` não aceita `precoCentavos` (erro de compilação).

- [ ] **Step 3: Implementar**

Em `lib/features/listas/data/listas_repository.dart`, altere a assinatura e os dois ramos:

```dart
  Future<ResultadoDedup> adicionarItemDedup({
    required String listaId,
    required String nome,
    required double quantidade,
    required Unidade unidade,
    required CategoriaItem categoria,
    int? precoCentavos,
  }) async {
```

No ramo de item existente (mesma unidade), passe o preço:

```dart
      if (existente.unidade == unidade.valor) {
        await editarItem(
          existente.id,
          quantidade: existente.quantidade + quantidade,
          precoCentavos: precoCentavos,
        );
        return ResultadoDedup.somado;
      }
      await editarItem(
        existente.id,
        quantidade: quantidade,
        unidade: unidade,
        precoCentavos: precoCentavos,
      );
      return ResultadoDedup.substituido;
```

No ramo de inserção:

```dart
    await adicionarItem(
      listaId: listaId,
      nome: nome,
      quantidade: quantidade,
      unidade: unidade,
      categoria: categoria,
      precoCentavos: precoCentavos,
    );
    return ResultadoDedup.adicionado;
```

> `editarItem` com `precoCentavos: null` e `limparPreco: false` (padrão) mantém o preço inalterado — nenhum comportamento da dedup (RF-10) muda quando o parâmetro é omitido.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS (toda a suíte do arquivo).

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/data/listas_repository.dart test/features/listas/listas_repository_test.dart
git commit -m "feat(etiqueta): preco opcional na dedup (RF-40, F59-T02)"
```

---

### Task 3: Helper de captura compartilhado (refatoração do OCR)

**Files:**
- Create: `lib/features/ocr/ui/captura_foto.dart`
- Modify: `lib/features/importacao/ui/modal_importar.dart:66-143` (`_lerFoto`)
- Test: `test/features/importacao/modal_importar_foto_test.dart` (regressão — sem alterar o arquivo)

**Interfaces:**
- Produces:
  - `sealed class ResultadoCaptura` com `CapturaTexto(String texto)`, `CapturaCancelada()`, `CapturaVazia()`, `CapturaFalha()`.
  - `Future<ResultadoCaptura> capturarTextoDeFoto(BuildContext context, WidgetRef ref)`.
- Consumes: `ocrTextoProvider`, `fonteImagemProvider`, `context.l10n.tirarFoto/escolherDaGaleria`.
- Preserva o comportamento atual do "Importar por foto" (RF-37).

- [ ] **Step 1: Criar o helper**

Crie `lib/features/ocr/ui/captura_foto.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../providers/ocr_providers.dart';

/// Resultado de capturar uma foto e rodar o OCR (RF-37/RF-40).
sealed class ResultadoCaptura {
  const ResultadoCaptura();
}

class CapturaTexto extends ResultadoCaptura {
  const CapturaTexto(this.texto);
  final String texto;
}

class CapturaCancelada extends ResultadoCaptura {
  const CapturaCancelada();
}

/// OCR rodou, mas não reconheceu nenhum texto.
class CapturaVazia extends ResultadoCaptura {
  const CapturaVazia();
}

/// Falha de permissão, do picker ou do OCR.
class CapturaFalha extends ResultadoCaptura {
  const CapturaFalha();
}

/// Abre a escolha câmera/galeria, lê a imagem e devolve o texto reconhecido
/// (trimado). Não grava nada e não persiste a imagem.
Future<ResultadoCaptura> capturarTextoDeFoto(
  BuildContext context,
  WidgetRef ref,
) async {
  final origem = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.l10n.tirarFoto),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.l10n.escolherDaGaleria),
            onTap: () => Navigator.pop(context, 'galeria'),
          ),
        ],
      ),
    ),
  );
  if (origem == null) return const CapturaCancelada();

  final fonte = ref.read(fonteImagemProvider);
  String? caminho;
  try {
    caminho = origem == 'camera'
        ? await fonte.daCamera()
        : await fonte.daGaleria();
  } catch (_) {
    return const CapturaFalha();
  }
  if (caminho == null) return const CapturaCancelada();

  // Mantém o provider (autoDispose) vivo durante o OCR assíncrono.
  final assinatura = ref.listenManual(ocrTextoProvider, (_, _) {});
  String texto;
  try {
    texto = await ref.read(ocrTextoProvider).extrair(caminho);
  } catch (_) {
    return const CapturaFalha();
  } finally {
    assinatura.close();
  }
  final limpo = texto.trim();
  return limpo.isEmpty ? const CapturaVazia() : CapturaTexto(limpo);
}
```

- [ ] **Step 2: Usar o helper no modal de importar**

Em `lib/features/importacao/ui/modal_importar.dart`, substitua o corpo de `_lerFoto` por:

```dart
  Future<void> _lerFoto() async {
    setState(() {
      _lendoFoto = true;
      _erro = null;
    });
    final resultado = await capturarTextoDeFoto(context, ref);
    if (!mounted) return;
    setState(() => _lendoFoto = false);
    switch (resultado) {
      case CapturaTexto(:final texto):
        _controller.text = _controller.text.trim().isEmpty
            ? texto
            : '${_controller.text}\n$texto';
      case CapturaVazia():
        setState(() {
          _erro = context.l10n.ocrNenhumTexto;
          _tipoErro = AppBannerTipo.aviso;
        });
      case CapturaFalha():
        setState(() {
          _erro = context.l10n.ocrFalha;
          _tipoErro = AppBannerTipo.erro;
        });
      case CapturaCancelada():
        break;
    }
  }
```

Adicione o import no topo de `modal_importar.dart`:

```dart
import '../../ocr/ui/captura_foto.dart';
```

> Remova do arquivo os imports que ficaram sem uso (por exemplo `../../ocr/providers/ocr_providers.dart` **somente se** nenhuma outra parte o usar — confira antes com uma busca no arquivo).

- [ ] **Step 3: Rodar a regressão do OCR**

Run: `flutter test test/features/importacao/modal_importar_foto_test.dart`
Expected: PASS (todos os casos — preencher, aviso, falha, cancelar, gate).

- [ ] **Step 4: Analisar e formatar**

Run: `dart format lib/features/ocr lib/features/importacao; flutter analyze lib/features/ocr lib/features/importacao`
Expected: sem erros (sem imports não usados).

- [ ] **Step 5: Commit**

```bash
git add lib/features/ocr/ui/captura_foto.dart lib/features/importacao/ui/modal_importar.dart
git commit -m "refactor(ocr): helper compartilhado de captura por foto (RF-40, F59-T03)"
```

---

### Task 4: Editor do item — câmera no campo de preço

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (imports)
- Modify: `lib/features/listas/ui/sheet_editar_item.dart:284-294` (campo de preço) e adicionar `_lerEtiqueta`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Test: `test/features/etiqueta/editor_etiqueta_test.dart` (novo)

**Interfaces:**
- Consumes: `capturarTextoDeFoto(context, ref)` e `analisarEtiqueta(texto)` (Tasks 1 e 3).
- Produces: preenche o `TextEditingController` de nome/preço e `_unidade` do editor.

- [ ] **Step 1: Adicionar as strings (ARB)**

Em `lib/l10n/app_pt.arb`, antes do fechamento `}`:

```json
  "etiquetaLer": "Ler etiqueta da prateleira",
  "etiquetaTitulo": "Etiqueta lida",
  "etiquetaNovoItem": "Novo item",
  "etiquetaItemExistente": "Item existente",
  "etiquetaAplicar": "Aplicar",
  "etiquetaAplicada": "Preço aplicado.",
  "etiquetaNenhumTexto": "Nenhum texto reconhecido na foto.",
  "etiquetaNaoReconhecida": "Não reconheci um preço na etiqueta."
```

Em `lib/l10n/app_en.arb`:

```json
  "etiquetaLer": "Scan shelf label",
  "etiquetaTitulo": "Label read",
  "etiquetaNovoItem": "New item",
  "etiquetaItemExistente": "Existing item",
  "etiquetaAplicar": "Apply",
  "etiquetaAplicada": "Price applied.",
  "etiquetaNenhumTexto": "No text recognized in the photo.",
  "etiquetaNaoReconhecida": "I couldn't recognize a price on the label."
```

Em `lib/l10n/app_es.arb`:

```json
  "etiquetaLer": "Leer etiqueta",
  "etiquetaTitulo": "Etiqueta leída",
  "etiquetaNovoItem": "Nuevo artículo",
  "etiquetaItemExistente": "Artículo existente",
  "etiquetaAplicar": "Aplicar",
  "etiquetaAplicada": "Precio aplicado.",
  "etiquetaNenhumTexto": "No se reconoció texto en la foto.",
  "etiquetaNaoReconhecida": "No reconocí un precio en la etiqueta."
```

Run: `flutter gen-l10n`
Expected: gera `AppLocalizations` sem erro.

- [ ] **Step 2: Escrever o teste que falha**

Crie `test/features/etiqueta/editor_etiqueta_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

import '../../support/app_teste.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
  @override
  void close() {}
}

class _FonteFake implements FonteImagem {
  @override
  Future<String?> daCamera() async => '/tmp/a.jpg';
  @override
  Future<String?> daGaleria() async => '/tmp/a.jpg';
}

void main() {
  testWidgets('deve_preencher_preco_quando_le_etiqueta_no_editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake('Arroz\nR\$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o editor tocando no item.
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    // A câmera ao lado do campo de preço lê a etiqueta e preenche.
    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '5,49'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/etiqueta/editor_etiqueta_test.dart`
Expected: FAIL — não encontra o ícone de câmera (não implementado).

- [ ] **Step 4: Implementar**

Em `lib/features/listas/ui/tela_lista_screen.dart`, adicione os imports:

```dart
import '../../etiqueta/domain/etiqueta.dart';
import '../../ocr/providers/ocr_providers.dart';
import '../../ocr/ui/captura_foto.dart';
```

Em `lib/features/listas/ui/sheet_editar_item.dart`, no campo de preço (o `Expanded` com `AppCampoTexto(controller: _preco, ...)`), acrescente o `sufixo`:

```dart
              Expanded(
                child: AppCampoTexto(
                  controller: _preco,
                  label: context.l10n.preco,
                  erro: _erroPreco,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  sufixo: plataformaComOcr()
                      ? IconButton(
                          tooltip: context.l10n.etiquetaLer,
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: _lerEtiqueta,
                        )
                      : null,
                  onChanged: (_) => setState(() => _erroPreco = null),
                ),
              ),
```

Adicione o método em `_SheetEditarItemState` (antes de `_salvar`):

```dart
  /// Lê a etiqueta (RF-40) e preenche preço/nome/unidade do editor, que já é
  /// o preview editável. Nada é gravado aqui.
  Future<void> _lerEtiqueta() async {
    final resultado = await capturarTextoDeFoto(context, ref);
    if (!mounted) return;
    switch (resultado) {
      case CapturaTexto(:final texto):
        final etiqueta = analisarEtiqueta(texto);
        if (etiqueta == null) {
          mostrarSnackBar(context, context.l10n.etiquetaNaoReconhecida);
          return;
        }
        setState(() {
          _preco.text = _precoInicial(etiqueta.precoCentavos) ?? '';
          if (_nome.text.trim().isEmpty && (etiqueta.nome?.isNotEmpty ?? false)) {
            _nome.text = etiqueta.nome!;
          }
          if (etiqueta.precoPorKgCentavos != null &&
              etiqueta.precoPorKgCentavos == etiqueta.precoCentavos) {
            _unidade = Unidade.kg;
          }
          _erroPreco = null;
        });
      case CapturaVazia():
        mostrarSnackBar(context, context.l10n.etiquetaNenhumTexto);
      case CapturaFalha():
        mostrarSnackBar(context, context.l10n.ocrFalha);
      case CapturaCancelada():
        break;
    }
  }
```

> Confirme que `mostrarSnackBar` já está disponível nesse `part` (é importado por `tela_lista_screen.dart:24`).

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/etiqueta/editor_etiqueta_test.dart`
Expected: PASS.

- [ ] **Step 6: Rodar a suíte de listas (regressão)**

Run: `flutter test test/features/listas`
Expected: PASS (nenhuma regressão no editor).

- [ ] **Step 7: Commit**

```bash
git add lib/l10n lib/features/listas/ui/tela_lista_screen.dart lib/features/listas/ui/sheet_editar_item.dart test/features/etiqueta/editor_etiqueta_test.dart
git commit -m "feat(etiqueta): camera no campo de preco do editor (RF-40, F59-T04)"
```

---

### Task 5: Modo mercado — botão de câmera + preview "Etiqueta lida"

**Files:**
- Create: `lib/features/etiqueta/ui/sheet_etiqueta.dart`
- Modify: `lib/features/listas/ui/mercado_screen.dart`
- Test: `test/features/etiqueta/mercado_etiqueta_test.dart` (novo)

**Interfaces:**
- Consumes: `capturarTextoDeFoto`, `analisarEtiqueta`, `listasRepositoryProvider.adicionarItemDedup(..., precoCentavos:)` (Task 2), `editarItem(id, precoCentavos:)`, `sugestaoCategoriasProvider.sugerirCategoria`, `itensDaListaProvider`.
- Produces: `class SheetEtiqueta extends ConsumerStatefulWidget { const SheetEtiqueta({super.key, required this.listaId, required this.etiqueta}); }`

- [ ] **Step 1: Criar o bottom sheet de preview**

Crie `lib/features/etiqueta/ui/sheet_etiqueta.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/quantidade.dart';
import '../../../core/dominio/unidade.dart';
import '../../../core/l10n/categoria_l10n.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/domain/item.dart';
import '../../listas/domain/preco.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/etiqueta.dart';

enum _Origem { novo, existente }

/// Preview editável da etiqueta lida (RF-40): cria um item novo com preço ou
/// aplica o preço a um item existente da lista. 100% local.
class SheetEtiqueta extends ConsumerStatefulWidget {
  const SheetEtiqueta({
    super.key,
    required this.listaId,
    required this.etiqueta,
  });

  final String listaId;
  final EtiquetaLida etiqueta;

  @override
  ConsumerState<SheetEtiqueta> createState() => _SheetEtiquetaState();
}

class _SheetEtiquetaState extends ConsumerState<SheetEtiqueta> {
  late final _nome = TextEditingController(text: widget.etiqueta.nome ?? '');
  late final _quantidade = TextEditingController(text: '1');
  late final _preco = TextEditingController(
    text: (widget.etiqueta.precoCentavos / 100)
        .toStringAsFixed(2)
        .replaceAll('.', ','),
  );
  late Unidade _unidade =
      widget.etiqueta.precoPorKgCentavos == widget.etiqueta.precoCentavos
      ? Unidade.kg
      : Unidade.un;
  CategoriaItem _categoria = CategoriaItem.outros;
  _Origem _origem = _Origem.novo;
  String? _itemId;
  String? _erroNome;
  String? _erroPreco;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _sugerirCategoria();
  }

  Future<void> _sugerirCategoria() async {
    final nome = widget.etiqueta.nome;
    if (nome == null || nome.trim().isEmpty) return;
    final c = await ref.read(sugestaoCategoriasProvider).sugerirCategoria(nome);
    if (mounted) setState(() => _categoria = c);
  }

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    _preco.dispose();
    super.dispose();
  }

  int? _precoValido() {
    try {
      return parsePrecoParaCentavos(_preco.text);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final preco = _precoValido();
    final nome = _nome.text.trim();
    final quantidade = parseQuantidade(_quantidade.text) ?? 0;
    setState(() {
      _erroNome = (_origem == _Origem.novo && nome.isEmpty)
          ? context.l10n.erroNomeVazio
          : null;
      _erroPreco = preco == null ? context.l10n.erroPrecoInvalido : null;
    });
    if (preco == null) return;
    if (_origem == _Origem.novo && nome.isEmpty) return;
    if (_origem == _Origem.existente && _itemId == null) return;

    setState(() => _salvando = true);
    final repo = ref.read(listasRepositoryProvider);
    try {
      if (_origem == _Origem.novo) {
        await repo.adicionarItemDedup(
          listaId: widget.listaId,
          nome: nome,
          quantidade: quantidade > 0 ? quantidade : 1,
          unidade: _unidade,
          categoria: _categoria,
          precoCentavos: preco,
        );
      } else {
        await repo.editarItem(_itemId!, precoCentavos: preco);
      }
      if (!mounted) return;
      Navigator.pop(context);
      mostrarSnackBar(context, context.l10n.etiquetaAplicada);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackBar(context, context.l10n.erroGenerico);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itens =
        ref.watch(itensDaListaProvider(widget.listaId)).value ?? const <Item>[];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.etiquetaTitulo,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<_Origem>(
            segments: [
              ButtonSegment(
                value: _Origem.novo,
                label: Text(context.l10n.etiquetaNovoItem),
              ),
              ButtonSegment(
                value: _Origem.existente,
                label: Text(context.l10n.etiquetaItemExistente),
              ),
            ],
            selected: {_origem},
            onSelectionChanged: (s) => setState(() => _origem = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_origem == _Origem.novo) ...[
            AppCampoTexto(
              controller: _nome,
              label: context.l10n.nomeDoItem,
              erro: _erroNome,
              onChanged: (_) => setState(() => _erroNome = null),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppCampoTexto(
                    controller: _quantidade,
                    label: context.l10n.quantidade,
                    teclado: TextInputType.text,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppDropdown<Unidade>(
                    label: context.l10n.unidade,
                    expandido: true,
                    valor: _unidade,
                    itens: [
                      for (final u in Unidade.values)
                        DropdownMenuItem(value: u, child: Text(u.valor)),
                    ],
                    onChanged: (u) {
                      if (u != null) setState(() => _unidade = u);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<CategoriaItem>(
              label: context.l10n.categoria,
              expandido: true,
              valor: _categoria,
              itens: [
                for (final c in CategoriaItem.values)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c.rotulo(context)),
                  ),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _categoria = c);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ] else
            AppDropdown<String>(
              label: context.l10n.etiquetaItemExistente,
              expandido: true,
              valor: _itemId,
              itens: [
                for (final i in itens)
                  DropdownMenuItem(value: i.id, child: Text(i.nome)),
              ],
              onChanged: (id) => setState(() => _itemId = id),
            ),
          const SizedBox(height: AppSpacing.md),
          AppCampoTexto(
            controller: _preco,
            label: context.l10n.preco,
            erro: _erroPreco,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _erroPreco = null),
          ),
          const SizedBox(height: AppSpacing.lg),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancelar),
              ),
              AppBotao(
                rotulo: _origem == _Origem.existente
                    ? context.l10n.etiquetaAplicar
                    : context.l10n.salvar,
                expandido: false,
                carregando: _salvando,
                onPressed: _salvar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

> Confirmar a assinatura de `AppDropdown` em `lib/core/widgets/app_dropdown.dart` (parâmetros `label`, `expandido`, `valor`, `itens`, `onChanged`) — é a mesma usada em `sheet_editar_item.dart`.

- [ ] **Step 2: Escrever o teste que falha**

Crie `test/features/etiqueta/mercado_etiqueta_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/mercado_screen.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

import '../../support/app_teste.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
  @override
  void close() {}
}

class _FonteFake implements FonteImagem {
  @override
  Future<String?> daCamera() async => '/tmp/a.jpg';
  @override
  Future<String?> daGaleria() async => '/tmp/a.jpg';
}

void main() {
  testWidgets('deve_criar_item_com_preco_quando_le_etiqueta', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake('Arroz\nR\$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    // Preview "Etiqueta lida" aberto; confirma a criação do item.
    expect(find.text('Etiqueta lida'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.nome, 'Arroz');
    expect(item.precoCentavos, 549);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_aplicar_preco_em_item_existente', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake(r'R$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item existente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecione').last); // abre o dropdown
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arroz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_avisar_quando_sem_preco_na_etiqueta', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake('Oferta da semana')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(find.text('Não reconheci um preço na etiqueta.'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
```

> Se o rótulo do placeholder do `AppDropdown` não for "Selecione", ajuste o finder no Step 2 consultando `lib/core/widgets/app_dropdown.dart` (o dropdown sem valor mostra o `hint`/`label`). A intenção do passo é: escolher a origem "Item existente", abrir o dropdown e escolher "Arroz".

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/etiqueta/mercado_etiqueta_test.dart`
Expected: FAIL — sem botão de câmera/sheet.

- [ ] **Step 4: Implementar o ponto de entrada no modo mercado**

Em `lib/features/listas/ui/mercado_screen.dart`, adicione os imports:

```dart
import '../../etiqueta/domain/etiqueta.dart';
import '../../etiqueta/ui/sheet_etiqueta.dart';
import '../../ocr/providers/ocr_providers.dart';
import '../../ocr/ui/captura_foto.dart';
```

Em `_MercadoScreenState`, adicione os métodos:

```dart
  /// Lê a etiqueta (RF-40): com preço reconhecido, abre o preview; senão avisa.
  Future<void> _lerEtiqueta() async {
    final resultado = await capturarTextoDeFoto(context, ref);
    if (!mounted) return;
    switch (resultado) {
      case CapturaTexto(:final texto):
        final etiqueta = analisarEtiqueta(texto);
        if (etiqueta == null) {
          mostrarSnackBar(context, context.l10n.etiquetaNaoReconhecida);
          return;
        }
        await AppSheet.mostrar<void>(
          context,
          child: SheetEtiqueta(
            listaId: widget.listaId,
            etiqueta: etiqueta,
          ),
        );
      case CapturaVazia():
        mostrarSnackBar(context, context.l10n.etiquetaNenhumTexto);
      case CapturaFalha():
        mostrarSnackBar(context, context.l10n.ocrFalha);
      case CapturaCancelada():
        break;
    }
  }
```

Acrescente o import de `AppSheet`:

```dart
import '../../../core/widgets/app_sheet.dart';
```

No `AppBar` do ramo `data` (o que tem `title: Text(lista.titulo)`), adicione as ações:

```dart
            appBar: AppBar(
              leading: botaoVoltarInicio(context, inicio),
              title: Text(lista.titulo),
              actions: [
                if (plataformaComOcr())
                  IconButton(
                    tooltip: context.l10n.etiquetaLer,
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: _lerEtiqueta,
                  ),
              ],
            ),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/etiqueta/mercado_etiqueta_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: Regressão do modo mercado**

Run: `flutter test test/features/listas/mercado_screen_test.dart`
Expected: PASS (o botão novo não quebra os fluxos existentes).

- [ ] **Step 7: Commit**

```bash
git add lib/features/etiqueta/ui/sheet_etiqueta.dart lib/features/listas/ui/mercado_screen.dart test/features/etiqueta/mercado_etiqueta_test.dart
git commit -m "feat(etiqueta): botao no modo mercado e preview da etiqueta (RF-40, F59-T05)"
```

---

### Task 6: Docs donos, bump e fechamento

**Files:**
- Modify: `docs/12-prd.md` (RF-40 na tabela §2, na matriz de rastreabilidade §6 e no fora de escopo §7)
- Modify: `docs/05-app-flutter.md` (nova §6.19 + referência em §6.3/§6.5 + árvore/providers)
- Modify: `docs/10-wireframes-telas.md` (botão no mercado, ícone no editor, preview)
- Modify: `docs/09-runbook-operacoes.md` (nota: sem dependência/permissão nova)
- Modify: `docs/13-premodelo-tecnico.md` (resumo do fluxo/parser)
- Modify: `docs/15-design-system.md` (componentes usados/estados)
- Modify: `docs/16-roadmap-pos-mvp.md` (frente)
- Modify: `docs/14-tarefas.md` (Fase 59 com tarefas/CP + linha na tabela de progresso)
- Modify: `pubspec.yaml` e `web/version.json` (bump)
- Test: `test/core/config/version_json_test.dart` (guard existente — deve passar)

**Interfaces:**
- Nenhuma de código; conteúdo normativo.

- [ ] **Step 1: Atualizar o PRD (doc dono de requisitos)**

Em `docs/12-prd.md §2`, adicione a linha:

```markdown
| RF-40 | Ler a **etiqueta de prateleira** por **OCR on-device** e usar o preço: **criar item** com nome/preço, **aplicar** o preço a um item existente (modo mercado) ou **preencher** o campo "Preço (R$)" do editor; **preview editável** sempre; a imagem **não é armazenada** (não é leitura de código de barras) | 05 §6.19 + 10 §3.3/§3.1 | F59 | [05 §8](05-app-flutter.md) |
```

Em `§6` (matriz), adicione a rastreabilidade:

```markdown
| RF-40 | US-01 | F59 | F59-T01..T05 | Unit parser + widgets (fakes) |
```

Em `§7` (fora de escopo), acrescente após "scan de código de barras":

```markdown
O **scan de código de barras** permanece **fora de escopo** — a leitura da **etiqueta de prateleira** por OCR entra como **RF-40** (pós-MVP/F59).
```

- [ ] **Step 2: Documentar no app (05)**

Em `docs/05-app-flutter.md`, adicione a seção **§6.19 "Preço por etiqueta (OCR)"** (após §6.18) descrevendo: gate `plataformaComOcr()`; helper `capturarTextoDeFoto` (`lib/features/ocr/ui/captura_foto.dart`); parser `analisarEtiqueta` (`lib/features/etiqueta/domain/etiqueta.dart`, preço cheio / R$/kg fallback); entrada no **modo mercado** (AppBar, preview `SheetEtiqueta` com "novo item"/"item existente") e no **editor** (ícone no campo de preço); `adicionarItemDedup(..., precoCentavos:)`; casos-limite. Referencie a §6.19 a partir de §6.3 (editor) e §6.5 (modo mercado).

- [ ] **Step 3: Atualizar os demais docs donos**

- `docs/10-wireframes-telas.md §3.3` (mercado): botão de câmera na `AppBar` e o sheet "Etiqueta lida"; `§3.1` (lista/editor): ícone de câmera no campo "Preço (R$)".
- `docs/09-runbook-operacoes.md §2.14`: nota de que a etiqueta **reusa** `google_mlkit_text_recognition`/`image_picker` — sem dependência nem permissão nova, sem mudança de tamanho.
- `docs/13-premodelo-tecnico.md`: uma linha em fluxos (etiqueta → `analisarEtiqueta` → preview) e no quadro de entidades/contratos.
- `docs/15-design-system.md §3`: componentes (ícone de câmera, `SegmentedButton` de origem, bottom sheet) e estados de carregando/erro.
- `docs/16-roadmap-pos-mvp.md`: frente do RF-40.

- [ ] **Step 4: Registrar a fase em 14-tarefas**

Em `docs/14-tarefas.md`, adicione a **Fase 59 — Preço por etiqueta (OCR) (RF-40)** com as tarefas `F59-T01` a `F59-T06` e seus CPs (espelhando este plano) e a nota de que é 100% offline e sem dependência nova. Atualize a **tabela de progresso** (`| F59 Preço por etiqueta (OCR) | 6 | 6 |`) e o `| **Total** |` (somar 6 em tarefas e concluídas).

- [ ] **Step 5: Bump de versão com paridade**

Em `pubspec.yaml`, mude `version: 1.7.0+20` para `version: 1.8.0+21`.
Em `web/version.json`, atualize para:

```json
{"app_name":"Minhas Listas","version":"1.8.0","build_number":"21","package_name":"lista_compras"}
```

- [ ] **Step 6: Verificação final**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: tudo verde, incluindo `test/core/config/version_json_test.dart` (paridade de versão) e toda a suíte nova.

- [ ] **Step 7: Commit**

```bash
git add docs pubspec.yaml web/version.json
git commit -m "docs(etiqueta): RF-40, fase 59 e bump 1.8.0+21 (RF-40, F59-T06)"
```

---

## Self-Review

**1. Cobertura do spec:**
- Domínio `analisarEtiqueta` (preço cheio; R$/kg fallback; nome best-effort) → Task 1. ✔
- Captura compartilhada (`ResultadoCaptura`/`capturarTextoDeFoto`) e reuso no "Importar por foto" → Task 3. ✔
- Modo mercado (botão + preview criar/aplicar) → Task 5. ✔
- Editor (ícone no campo de preço; editor é o preview) → Task 4. ✔
- `adicionarItemDedup` com preço (criar item novo) → Task 2. ✔
- Casos-limite (OCR vazio/sem preço/falha/cancelar; gate plataforma; imagem não persistida; 1 imagem) → Tasks 3/4/5. ✔
- Sem dependência/permissão nova → Global Constraints + Task 6. ✔
- Governança (12/05/10/09/13/15/16/14), i18n pt/en/es e bump/`web/version.json` → Tasks 4/6. ✔
- Testes unit/widget/regressão/CI → cada tarefa + Task 6. ✔

**2. Placeholders:** nenhum "TBD"/"TODO"; todos os passos de código trazem o conteúdo. Os dois pontos que pedem confirmação (rótulo do `AppDropdown` e remoção de imports) são passos de verificação explícitos, não lacunas de conteúdo.

**3. Consistência de tipos:** `EtiquetaLida{nome, precoCentavos, precoPorKgCentavos}` (Task 1) é o mesmo consumido em Tasks 4/5; `ResultadoCaptura`/`CapturaTexto|Cancelada|Vazia|Falha` (Task 3) idênticos em Tasks 4/5; `adicionarItemDedup(..., int? precoCentavos)` (Task 2) é o chamado em Task 5. ✔
