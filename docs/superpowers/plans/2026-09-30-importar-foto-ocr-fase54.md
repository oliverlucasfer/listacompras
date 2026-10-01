# Importar por Foto (OCR) — Fase 54 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar um botão **"Foto"** ao modal de importar (RF-16) que tira/escolhe uma imagem, roda **OCR on-device** e preenche o campo de texto editável — mantendo o fluxo de importação atual.

**Architecture:** Dois contratos injetáveis (`OcrTexto` → ML Kit; `FonteImagem` → `image_picker`) atrás de providers, com gate `plataformaComOcr()` (Android/iOS). A UI vive no `modal_importar.dart` existente; nada de rede, nenhuma imagem é armazenada.

**Tech Stack:** Flutter, Riverpod, `google_mlkit_text_recognition`, `image_picker`.

**Spec:** `docs/superpowers/specs/2026-09-30-importar-foto-ocr-design.md` (RF-37 / Fase 54)

## Global Constraints

- App 100% local: **nenhuma** rede. OCR **on-device** (ML Kit bundled); a imagem **não é armazenada**.
- Dependências novas: **`google_mlkit_text_recognition`** e **`image_picker`** (nenhuma outra).
- Gate `plataformaComOcr()` (Android/iOS; Web/Desktop escondem o botão), no padrão de `plataformaComVoz()`.
- Testes **nunca** tocam os plugins reais (fakes injetáveis).
- `App*` componentes/tokens + `AppStrings`; pt-BR; testes `deve_<resultado>_quando_<condição>`.
- Não alterar o comportamento existente do import (RF-16): o OCR só **preenche o campo**.

---

## File Structure

- `lib/features/ocr/domain/ocr_texto.dart` · `lib/features/ocr/domain/fonte_imagem.dart`
- `lib/features/ocr/data/ocr_texto_mlkit.dart` · `lib/features/ocr/data/fonte_imagem_image_picker.dart`
- `lib/features/ocr/providers/ocr_providers.dart`
- `lib/features/importacao/ui/modal_importar.dart` (botão + fluxo)
- `lib/core/l10n/app_strings.dart`, `ios/Runner/Info.plist`, `pubspec.yaml`

---

## Task 1: Contratos, plugins e gate de plataforma

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add google_mlkit_text_recognition image_picker`), `ios/Runner/Info.plist`
- Create: `lib/features/ocr/domain/ocr_texto.dart`, `lib/features/ocr/domain/fonte_imagem.dart`
- Create: `lib/features/ocr/data/ocr_texto_mlkit.dart`, `lib/features/ocr/data/fonte_imagem_image_picker.dart`
- Create: `lib/features/ocr/providers/ocr_providers.dart`
- Test: `test/features/ocr/ocr_plataforma_test.dart`

**Interfaces you produce (Task 2 depends on these):**
- `abstract interface class OcrTexto { Future<String> extrair(String caminhoImagem); }`
- `abstract interface class FonteImagem { Future<String?> daCamera(); Future<String?> daGaleria(); }`
- `bool plataformaComOcr();` · `ocrTextoProvider` · `fonteImagemProvider`

- [ ] **Step 1: Add dependencies + iOS permission**

Run: `flutter pub add google_mlkit_text_recognition image_picker`
Em `ios/Runner/Info.plist` (dentro do `<dict>`): `<key>NSPhotoLibraryUsageDescription</key><string>Acessar suas fotos para importar a lista de compras.</string>`

- [ ] **Step 2: Write the failing test**

`test/features/ocr/ocr_plataforma_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('deve_ser_verdadeiro_no_android_e_ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(plataformaComOcr(), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(plataformaComOcr(), isTrue);
  });

  test('deve_ser_falso_no_desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(plataformaComOcr(), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(plataformaComOcr(), isFalse);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/ocr/ocr_plataforma_test.dart`
Expected: FAIL — `plataformaComOcr` inexistente.

- [ ] **Step 4: Implement contracts, plugins, provider**

`lib/features/ocr/domain/ocr_texto.dart`:

```dart
/// OCR on-device (RF-37). A UI depende desta interface; os testes usam um fake.
abstract interface class OcrTexto {
  /// Reconhece o texto da imagem no [caminhoImagem]; devolve '' se não houver texto.
  Future<String> extrair(String caminhoImagem);
}
```

`lib/features/ocr/domain/fonte_imagem.dart`:

```dart
/// Origem de uma imagem para OCR (RF-37): câmera ou galeria.
/// Devolve o caminho do arquivo, ou `null` se o usuário cancelar.
abstract interface class FonteImagem {
  Future<String?> daCamera();
  Future<String?> daGaleria();
}
```

`lib/features/ocr/data/ocr_texto_mlkit.dart`:

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/ocr_texto.dart';

class OcrTextoMlKit implements OcrTexto {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extrair(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    final resultado = await _recognizer.processImage(input);
    return resultado.text;
  }
}
```

`lib/features/ocr/data/fonte_imagem_image_picker.dart`:

```dart
import 'package:image_picker/image_picker.dart';

import '../domain/fonte_imagem.dart';

class FonteImagemImagePicker implements FonteImagem {
  final _picker = ImagePicker();

  @override
  Future<String?> daCamera() async =>
      (await _picker.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<String?> daGaleria() async =>
      (await _picker.pickImage(source: ImageSource.gallery))?.path;
}
```

`lib/features/ocr/providers/ocr_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fonte_imagem_image_picker.dart';
import '../data/ocr_texto_mlkit.dart';
import '../domain/fonte_imagem.dart';
import '../domain/ocr_texto.dart';

/// O OCR só aparece onde o plugin on-device é suportado: Android/iOS.
bool plataformaComOcr() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final ocrTextoProvider = Provider<OcrTexto>((ref) => OcrTextoMlKit());
final fonteImagemProvider = Provider<FonteImagem>(
  (ref) => FonteImagemImagePicker(),
);
```

- [ ] **Step 5: Run test + builds**

Run: `flutter test test/features/ocr/ocr_plataforma_test.dart && dart format . && flutter analyze`
Also verify builds: `flutter build apk --debug` e `flutter build web --release` (garantir que os plugins não quebram o Web; se quebrarem, isolar o import dos plugins com conditional import/stub mantendo os contratos).
Expected: teste verde e builds OK.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/ocr ios/Runner/Info.plist test/features/ocr
git commit -m "feat(ocr): contratos, plugins e gate de plataforma (RF-37, F54)"
```

---

## Task 2: Botão "Foto" no modal de importar

**Files:**
- Modify: `lib/features/importacao/ui/modal_importar.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/importacao/modal_importar_foto_test.dart`

**Interfaces you consume:**
- `plataformaComOcr()`, `ocrTextoProvider`, `fonteImagemProvider` (Task 1); the existing modal (`_controller`, `_erro`, `_limite`, `maxCaracteresImportLocal`).

**Interfaces you produce:**
- New `AppStrings`: `foto`, `tirarFoto`, `escolherDaGaleria`, `ocrLendo`, `ocrNenhumTexto`, `ocrFalha`.

- [ ] **Step 1: Add strings**

```dart
  // Importar por foto / OCR (RF-37, F54)
  static const foto = 'Foto';
  static const tirarFoto = 'Tirar foto';
  static const escolherDaGaleria = 'Escolher da galeria';
  static const ocrLendo = 'Lendo a foto...';
  static const ocrNenhumTexto = 'Nenhum texto reconhecido na foto.';
  static const ocrFalha = 'Não foi possível ler a foto.';
```

- [ ] **Step 2: Write the failing widget tests**

`test/features/importacao/modal_importar_foto_test.dart` (fakes injetados via providers):

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/importacao/ui/modal_importar.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
}

class _FonteFake implements FonteImagem {
  _FonteFake({this.caminho});
  final String? caminho;
  @override
  Future<String?> daCamera() async => caminho;
  @override
  Future<String?> daGaleria() async => caminho;
}

Widget _app(AppDatabase db, {required String texto, String? caminho}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ocrTextoProvider.overrideWithValue(_OcrFake(texto)),
      fonteImagemProvider.overrideWithValue(_FonteFake(caminho: caminho)),
    ],
    child: const MaterialApp(home: Scaffold(body: _Abrir())),
  );
}

class _Abrir extends ConsumerWidget {
  const _Abrir();
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () => abrirModalImportar(context, ref, 'l'),
        child: const Text('abrir'),
      );
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('deve_mostrar_botao_foto_quando_ha_ocr', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: 'Arroz 2kg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Foto'), findsOneWidget);
  });

  testWidgets('deve_preencher_campo_quando_le_a_foto', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: 'Arroz 2kg', caminho: '/tmp/a.jpg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz 2kg'), findsOneWidget);
  });

  testWidgets('deve_avisar_quando_ocr_sem_texto', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: '', caminho: '/tmp/a.jpg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum texto reconhecido na foto.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/importacao/modal_importar_foto_test.dart`
Expected: FAIL — botão "Foto" inexistente.

- [ ] **Step 4: Implement in `modal_importar.dart`**

- Estado novo: `bool _lendoFoto = false;`.
- No `build`, quando `plataformaComOcr()`, um `OutlinedButton.icon`/`AppBotao` **"Foto"** (ícone `Icons.photo_camera_outlined`) logo abaixo do campo, desabilitado enquanto `_lendoFoto`/`_carregando`.
- `Future<void> _lerFoto()`:
  1. `final origem = await showModalBottomSheet<...>` com **"Tirar foto"** e **"Escolher da galeria"** (ou dois botões simples).
  2. `final fonte = ref.read(fonteImagemProvider); final caminho = origem == camera ? await fonte.daCamera() : await fonte.daGaleria();` — `null` → retorna sem efeito.
  3. `setState(_lendoFoto = true; _erro = null)`; `try { texto = await ref.read(ocrTextoProvider).extrair(caminho); } catch { _erro = AppStrings.ocrFalha; return; } finally { _lendoFoto = false }`.
  4. `texto.trim().isEmpty` → `setState(_erro = AppStrings.ocrNenhumTexto)`; senão **preenche** o campo: se vazio, `_controller.text = texto`; senão `_controller.text = '${_controller.text}\n$texto'`.
- Enquanto `_lendoFoto`, mostrar `AppStrings.ocrLendo` (ex.: no lugar do hint / num texto auxiliar) e desabilitar "Extrair".
- Reuse o `_erro`/`AppBanner` já existente no modal para `ocrFalha`/`ocrNenhumTexto`.

> O contador/limite continua o mesmo (o texto entra no campo e é validado como hoje).

- [ ] **Step 5: Run tests, format and analyze**

Run: `flutter test test/features/importacao/modal_importar_foto_test.dart && dart format . && flutter analyze && flutter test`
Expected: tudo verde (existentes preservados).

- [ ] **Step 6: Commit**

```bash
git add lib/features/importacao/ui/modal_importar.dart lib/core/l10n/app_strings.dart test/features/importacao
git commit -m "feat(ocr): botao Foto no modal de importar (RF-37, F54)"
```

---

## Task 3: Docs donos e fechamento da Fase 54

**Files:** `docs/12-prd.md` (RF-37 + matriz), `docs/05-app-flutter.md` (§6.16 ou próximo 6.x; contratos/providers/gate), `docs/10-wireframes-telas.md` (§4.1 botão Foto + escolha), `docs/04-importacao-lista.md` (nota: OCR alimenta o parser), `docs/09-runbook-operacoes.md` (deps + permissão iOS de fotos), `docs/15-design-system.md` (se houver componente), `docs/14-tarefas.md` (Fase 54 + progresso), `docs/16-roadmap-pos-mvp.md` (frente).

- [ ] **Step 1–3:** add RF-37 (tabela+matriz+fora de escopo); doc 05 com o fluxo/contratos; doc 10 wireframe; doc 04 nota; doc 09 deps (`google_mlkit_text_recognition`, `image_picker`) + `NSPhotoLibraryUsageDescription` + nota do tamanho do app; doc 14 (Fase 54 + tabela de progresso; Total atual 290/288 → 293/291); doc 16 (frente).

- [ ] **Step 4: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs(ocr): RF-37, 04, 05, 09, 10, 14 e 16 (F54)"
```

---

## Self-Review (cobertura da spec — Fase 54)

- §3 contratos + gate + deps → Task 1.
- §4 fluxo/UI (botão Foto, câmera/galeria, preenche o campo, erros) → Task 2.
- §5 regras (cancelar, sem texto, imagem não guardada, limite) → Task 2.
- §6 deps/permissões/riscos → Tasks 1 e 3.
- §7 testes (fake, gate, fluxo) → Tasks 1 e 2.
- §9 decisões 1–5 → Tasks 1/2.

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-importar-foto-ocr-design.md`
- [04 Importação](../04-importacao-lista.md) · [05 App Flutter](../05-app-flutter.md) · [09 Runbook](../09-runbook-operacoes.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
