# Fase 30 — Adicionar Item por Voz (RF-26): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o RF-26 — microfone no campo "Adicionar item" que preenche o campo com o texto reconhecido **on-device** (pt-BR); o usuário confirma e o parser cuida do resto.

**Architecture:** Abstração `ReconhecimentoVoz` (interface) com implementação real sobre `speech_to_text` e um **fake** para testes; a UI depende da interface via provider. Sem schema/RLS/sync.

**Tech Stack:** Flutter · Riverpod · `speech_to_text` · Android/iOS config.

**Spec:** `docs/superpowers/specs/2026-09-21-adicionar-por-voz-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F30-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `supabase/migrations/`, `docs/01`, `docs/02`, `docs/03`** — sem schema/sync.
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- Reconhecimento **on-device** (`onDevice: true`), pt-BR; **sem rede/serviço**; microfone **só em Android/iOS**.
- Sem segredo; o reconhecimento real não roda no CI (smoke em device).
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Abstração, plugin, provider e plataforma

**Files:**
- Modify: `pubspec.yaml` (+ `pubspec.lock`) — dependência `speech_to_text`
- Create: `lib/features/voz/domain/reconhecimento_voz.dart`
- Create: `lib/features/voz/data/reconhecimento_voz_plugin.dart`
- Create: `lib/features/voz/providers/reconhecimento_voz_provider.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: `speech_to_text`.
- Produces: `enum EstadoVoz { parado, ouvindo, indisponivel }`; `abstract interface class ReconhecimentoVoz`; `ReconhecimentoVozPlugin`; `reconhecimentoVozProvider`; `bool plataformaComVoz()`.

- [ ] **Step 1: Adicionar a dependência**

Run: `flutter pub add speech_to_text`
Expected: `pubspec.yaml` ganha a dependência (versão estável) e `pubspec.lock` é atualizado.

- [ ] **Step 2: Abstração**

`lib/features/voz/domain/reconhecimento_voz.dart`:

```dart
/// Estado do reconhecimento de voz para a UI.
enum EstadoVoz { parado, ouvindo, indisponivel }

/// Contrato do reconhecimento de voz **on-device** (RF-26). A UI depende desta
/// interface; a implementação real usa `speech_to_text` e os testes usam um fake.
abstract interface class ReconhecimentoVoz {
  /// Inicializa e começa a ouvir (on-device, pt-BR). Devolve `false` quando o
  /// reconhecimento não está disponível (sem modelo/permissão negada) — nesse
  /// caso chama [onIndisponivel]. [onTexto] recebe o texto parcial/final.
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  });

  Future<void> parar();

  Future<void> cancelar();
}
```

- [ ] **Step 3: Implementação real + provider**

`lib/features/voz/data/reconhecimento_voz_plugin.dart`:

```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/reconhecimento_voz.dart';

/// Reconhecimento **no dispositivo** (RF-26): sem rede e sem serviço externo.
/// Erros/indisponibilidade (modelo ausente, permissão negada) viram
/// [onIndisponivel] — o app nunca cai para reconhecimento por rede.
class ReconhecimentoVozPlugin implements ReconhecimentoVoz {
  final _speech = stt.SpeechToText();

  @override
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  }) async {
    onEstado(EstadoVoz.parado);
    final disponivel = await _speech.initialize(
      onError: (_) => onIndisponivel(),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') onEstado(EstadoVoz.parado);
      },
    );
    if (!disponivel) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    onEstado(EstadoVoz.ouvindo);
    final ok = await _speech.listen(
      onResult: (r) => onTexto(r.recognizedWords, r.finalResult),
      onDevice: true,
      localeId: 'pt_BR',
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
    if (!ok) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
    }
    return ok;
  }

  @override
  Future<void> parar() => _speech.stop();

  @override
  Future<void> cancelar() => _speech.cancel();
}
```

`lib/features/voz/providers/reconhecimento_voz_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reconhecimento_voz_plugin.dart';
import '../domain/reconhecimento_voz.dart';

/// O microfone só aparece onde o reconhecimento on-device é suportado:
/// Android/iOS (Web/Desktop ocultam — doc 05).
bool plataformaComVoz() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final reconhecimentoVozProvider = Provider<ReconhecimentoVoz>(
  (ref) => ReconhecimentoVozPlugin(),
);
```

> Se a API do `speech_to_text` na versão instalada divergir (ex.: `listen` sem `listenOptions` ou retornando `void`), ajuste o wrapper mantendo `onDevice: true` e `localeId: 'pt_BR'`.

- [ ] **Step 4: Config de plataforma**

`android/app/src/main/AndroidManifest.xml` — adicionar junto das permissões existentes (antes de `<application>`):

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

`ios/Runner/Info.plist` — adicionar dentro do `<dict>` raiz:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>Usamos o microfone para você ditar itens da lista.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Usamos o reconhecimento de voz, no aparelho, para ditar itens.</string>
```

- [ ] **Step 5: Gate e commit**

Run: `flutter pub get && dart format . && flutter analyze && flutter test`
Expected: verde (nenhuma UI ainda usa a abstração).

```bash
git add pubspec.yaml pubspec.lock lib/features/voz/domain/reconhecimento_voz.dart lib/features/voz/data/reconhecimento_voz_plugin.dart lib/features/voz/providers/reconhecimento_voz_provider.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "F30-T01: abstracao de voz on-device, plugin e plataforma (RF-26)"
```

---

### Task 2: UI — microfone no campo e testes com o fake

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_CampoAdicionar`)
- Create: `test/features/voz/fake_reconhecimento_voz.dart`
- Modify: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `ReconhecimentoVoz`, `EstadoVoz`, `reconhecimentoVozProvider`, `plataformaComVoz`.
- Produces: microfone no campo; strings `ditarItem`/`vozIndisponivel`.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`:

```dart
  static const ditarItem = 'Ditar item';
  static const vozIndisponivel =
      'Reconhecimento de voz indisponível neste aparelho.';
```

- [ ] **Step 2: Fake (test-only)**

`test/features/voz/fake_reconhecimento_voz.dart`:

```dart
import 'package:lista_compras/features/voz/domain/reconhecimento_voz.dart';

class FakeReconhecimentoVoz implements ReconhecimentoVoz {
  FakeReconhecimentoVoz({this.disponivel = true});

  bool disponivel;
  bool parou = false;
  bool cancelou = false;

  void Function(String texto, bool finalizado)? _onTexto;
  void Function()? _onIndisponivel;
  void Function(EstadoVoz)? _onEstado;

  @override
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  }) async {
    _onTexto = onTexto;
    _onIndisponivel = onIndisponivel;
    _onEstado = onEstado;
    if (!disponivel) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    onEstado(EstadoVoz.ouvindo);
    return true;
  }

  /// Emite texto reconhecido (chamado pelo teste).
  void emitir(String texto, {bool finalizado = false}) =>
      _onTexto?.call(texto, finalizado);

  @override
  Future<void> parar() async {
    parou = true;
    _onEstado?.call(EstadoVoz.parado);
  }

  @override
  Future<void> cancelar() async => cancelou = true;
}
```

- [ ] **Step 3: Escrever os testes de widget que falham**

Em `test/features/listas/tela_lista_screen_test.dart`, acrescentar ao final de `void main()` (reuse o harness real; o `defaultTargetPlatform` dos testes é Android, então o microfone aparece):

```dart
  testWidgets('deve_preencher_campo_quando_reconhece', (tester) async {
    final fake = FakeReconhecimentoVoz();
    await abrirListaF7t07(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip(AppStrings.ditarItem));
    await tester.pump();
    fake.emitir('meio quilo de queijo');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, AppStrings.adicionarItem),
          )
          .controller!
          .text,
      'meio quilo de queijo',
    );
    await fechar(tester);
  });

  testWidgets('deve_mostrar_snackbar_quando_indisponivel', (tester) async {
    final fake = FakeReconhecimentoVoz(disponivel: false);
    await abrirListaF7t07(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip(AppStrings.ditarItem));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.vozIndisponivel), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_parar_quando_toca_de_novo', (tester) async {
    final fake = FakeReconhecimentoVoz();
    await abrirListaF7t07(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip(AppStrings.ditarItem));
    await tester.pump();
    await tester.tap(find.byTooltip(AppStrings.ditarItem));
    await tester.pump();

    expect(fake.parou, isTrue);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_microfone_para_leitor', (tester) async {
    // abrir a lista como leitor (harness com papel leitor)
    await abrirListaComoLeitor(tester);
    expect(find.byTooltip(AppStrings.ditarItem), findsNothing);
    await fechar(tester);
  });
```

> Ajuste o helper `abrirListaF7t07` (ou crie um `abrirListaComVoz`) para aceitar um `ReconhecimentoVoz? reconhecimento` e sobrepor `reconhecimentoVozProvider` no `ProviderScope`. Para o caso do leitor, use/parametrize um helper com papel `Papel.leitor` (o arquivo já tem testes de gate de leitor).

- [ ] **Step 4: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL — o botão de microfone e o provider ainda não existem.

- [ ] **Step 5: Implementar a UI**

Em `lib/features/listas/ui/tela_lista_screen.dart`, em `_CampoAdicionarState`:
- Estado: `EstadoVoz _estadoVoz = EstadoVoz.parado;`
- Métodos:

```dart
  void _aoEstadoVoz(EstadoVoz estado) {
    if (mounted) setState(() => _estadoVoz = estado);
  }

  Future<void> _ditar() async {
    final voz = ref.read(reconhecimentoVozProvider);
    if (_estadoVoz == EstadoVoz.ouvindo) {
      await voz.parar();
      return;
    }
    await voz.iniciar(
      onTexto: (texto, _) {
        if (!mounted) return;
        setState(() {
          _controller.text = texto;
          _erro = null;
        });
      },
      onIndisponivel: () {
        if (mounted) mostrarSnackBar(context, AppStrings.vozIndisponivel);
      },
      onEstado: _aoEstadoVoz,
    );
  }
```

- No `sufixo` (Row), antes do `IconButton` do `Icons.add`:

```dart
                if (plataformaComVoz())
                  IconButton(
                    tooltip: AppStrings.ditarItem,
                    icon: Icon(
                      _estadoVoz == EstadoVoz.ouvindo
                          ? Icons.mic
                          : Icons.mic_none,
                    ),
                    onPressed: _ditar,
                  ),
```

- Imports: `../../voz/domain/reconhecimento_voz.dart`, `../../voz/providers/reconhecimento_voz_provider.dart`.

> O `_CampoAdicionar` só é renderizado quando o papel permite escrever (`tela_lista_screen.dart` já esconde o campo do leitor), então o gate de dono/editor vem de graça; o teste do leitor confirma.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/listas/ui/tela_lista_screen.dart test/features/voz/fake_reconhecimento_voz.dart test/features/listas/tela_lista_screen_test.dart
git commit -m "F30-T02: microfone no campo adicionar item (RF-26)"
```

---

### Task 3: Docs donos e fechamento da Fase 30

**Files:**
- Modify: `docs/05-app-flutter.md` (§6.3 + plataforma)
- Modify: `docs/10-wireframes-telas.md` (microfone no campo)
- Modify: `docs/12-prd.md` (RF-26 + rastreabilidade)
- Modify: `docs/14-tarefas.md` (Fase 30 + progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (A6 concluído)

**Interfaces:**
- Consumes: comportamento entregue nas Tasks 1–2.
- Produces: nada consumido por código.

- [ ] **Step 1: Docs 05 e 10**
  - `05 §6.3`: o campo "Adicionar item" ganha o **microfone** (dono/editor) que preenche o campo com o texto reconhecido **on-device** (pt-BR); indisponível/permissão negada → SnackBar; só em Android/iOS. Em §2.1 (plataforma): permissões `RECORD_AUDIO` (Android) e `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` (iOS).
  - `10`: nota/wireframe do microfone no campo.

- [ ] **Step 2: Doc 12 e 16**
  - `12 §2`: `RF-26 | Adicionar item por voz (reconhecimento on-device, pt-BR, preenche o campo) | 05 §6.3 | F30 | ...`; §6: rastreabilidade `RF-26 | US-01 | F30 | F30-T01, F30-T02 | Unit fake + widgets (plugin real: smoke em device)`.
  - `16`: Onda A linha A6 → `concluído (F30-T01…T03)`.

- [ ] **Step 3: Doc 14 (Fase 30 + progresso)**
  - Antes de `## Progresso por fase`, adicionar a Fase 30 com F30-T01…T03 `[x]` e CPs.
  - Na tabela, após `| F29 Quantidades em fração | 3 | 3 |`, adicionar `| F30 Adicionar por voz | 3 | 3 |` e atualizar o total para `| **Total** | **164** | **162** |`.

- [ ] **Step 4: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F30-T03: docs donos e fechamento da Fase 30 (RF-26)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 dependência/plataforma → Task 1; §4 abstração → Task 1; §5 UI → Task 2; §6 testes → Tasks 1–2; §7 docs → Task 3.
- **Placeholders:** nenhum "TBD"; todo o código novo está completo. O teste de widget reusa/parametriza o harness real.
- **Consistência de tipos:** `EstadoVoz`, `ReconhecimentoVoz.iniciar({onTexto,onIndisponivel,onEstado})`, `ReconhecimentoVozPlugin`, `reconhecimentoVozProvider`, `plataformaComVoz()`, strings `ditarItem`/`vozIndisponivel`; progresso 164/162 — idênticos entre tarefas.
- **Limitação registrada:** o reconhecimento real é device-dependente e não roda no CI (smoke manual), como o deep link físico.
- **YAGNI:** sem voz no mercado/importação, sem adicionar direto, sem rede.
