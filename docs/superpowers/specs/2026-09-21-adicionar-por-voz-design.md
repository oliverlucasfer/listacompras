# Frente — Adicionar Item por Voz (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 30 · **Requisito:** RF-26 (adicionar item por voz, offline)
> **Docs donos:** [05](../05-app-flutter.md) (UI + plataforma), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

No corredor, digitar é o atrito: uma mão no carrinho, pressa. Falar "meio quilo de queijo" e ver o item pronto é o caminho natural — e casa com a persona **P1 (Comprador solo)**.

A fala é só uma **entrada alternativa** para o campo "Adicionar item": o texto reconhecido **preenche o campo**, o usuário confirma e o parser local ([RF-16](../04-importacao-lista.md)/[RF-25](../12-prd.md)) cuida de quantidade/unidade/fração. Reconhecimento **no dispositivo** (offline-first), sem serviço de nuvem e sem chave.

## 2. Escopo

**Dentro:**
- Botão de microfone no campo "Adicionar item" (dono/editor) que **preenche o campo** com o texto reconhecido **on-device** (pt-BR).
- Abstração testável do reconhecimento + implementação real sobre `speech_to_text` + fake para testes.
- Permissões/config de plataforma (Android/iOS).

**Fora:** adicionar direto sem confirmar, voz no modo mercado/importação, reconhecimento por rede, outros idiomas.

## 3. Dependência e plataforma

- `pubspec.yaml`: adicionar `speech_to_text` (versão estável compatível com o SDK; fixada no `pubspec.lock`).
- **Android** (`android/app/src/main/AndroidManifest.xml`): `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`. (O plugin cuida do resto; `INTERNET` já existe no app.)
- **iOS** (`ios/Runner/Info.plist`): `NSMicrophoneUsageDescription` e `NSSpeechRecognitionUsageDescription` (texto pt-BR explicando o uso).
- **Web/Desktop:** o microfone **não aparece** (reconhecimento on-device não é garantido); comportamento documentado. Nada de código específico além de esconder o botão.
- **On-device — limite conhecido:** o app **pede** reconhecimento no dispositivo (`onDevice: true`, pt-BR) e nunca inicia uma chamada de rede por conta própria. Porém o `speech_to_text` **não** expõe forma de verificar/forçar on-device (`SpeechToTextPlatform.hasOnDeviceSupport` não tem handler nativo em 7.5.0). No Android, quando não há modelo on-device para o idioma, o **próprio SO** pode usar o reconhecedor de rede. É limitação do plugin/SO, documentada; não há como impedir esse fallback.

## 4. Abstração testável

`lib/features/voz/domain/reconhecimento_voz.dart`:

```dart
/// Estado do reconhecimento para a UI.
enum EstadoVoz { parado, ouvindo, indisponivel }

/// Contrato do reconhecimento de voz (on-device). A UI depende desta interface
/// — a implementação real usa `speech_to_text`; os testes usam um fake.
abstract interface class ReconhecimentoVoz {
  /// Inicializa e começa a ouvir (on-device, pt-BR). Devolve `false` se o
  /// reconhecimento não estiver disponível (sem modelo/permissão negada).
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  });

  Future<void> parar();
  Future<void> cancelar();
}
```

- Implementação real `ReconhecimentoVozPlugin` (`lib/features/voz/data/reconhecimento_voz_plugin.dart`) sobre `SpeechToText`: `initialize(onError:, onStatus:)` → `listen(onDevice: true, localeId: 'pt_BR', onResult:)`; em erro, volta a `parado` e só chama `onIndisponivel` quando o erro é permanente (ex.: modelo ausente, permissão negada).
- **Fake** `FakeReconhecimentoVoz` (em `test/`) que emite texto/estado sob comando do teste.
- Provider `reconhecimentoVozProvider` (Riverpod), sobrescrito nos testes.

## 5. UI

- No `_CampoAdicionar` (`tela_lista_screen.dart`), um `IconButton` de microfone **à direita do campo** (ao lado do seletor de unidade):
  - visível só a **dono/editor** e só em **Android/iOS** (`Platform`/`defaultTargetPlatform`; Web/Desktop ocultam);
  - toque → `iniciar(...)`; enquanto `ouvindo`, o ícone indica o estado (`Icons.mic` ativo / `Icons.mic_none`), com `tooltip` "Ditar item";
  - toque de novo → `parar()`.
- **Preenchimento:** a cada resultado (parcial ou final) o campo recebe o texto reconhecido (parcial atualiza; final fixa). Ao final, o reconhecimento para e o foco volta ao campo — o usuário confirma (Enter), caindo no fluxo atual.
- **Feedback:** indisponível/permissão negada → SnackBar `AppStrings.vozIndisponivel` ("Reconhecimento de voz indisponível neste aparelho."). Ouvindo → SnackBar/semântica opcional; acessibilidade: `Semantics` de ação no botão (RNF-06).
- Não cria item sozinho; nada muda no parser.

## 6. Testes

**Unit — fake/abstração:** o `FakeReconhecimentoVoz` respeita o contrato (estados/texto). (O plugin real é smoke em device — documentado.)

**Widget (com o fake):**
- `deve_preencher_campo_quando_reconhece` — toque no microfone, fake emite "meio quilo de queijo", o campo fica com esse texto.
- `deve_mostrar_snackbar_quando_indisponivel` — fake devolve indisponível → `AppStrings.vozIndisponivel`.
- `nao_deve_mostrar_microfone_para_leitor` — leitor não vê o botão.
- `deve_parar_quando_toca_de_novo` — segundo toque chama `parar()`.
- `deve_confirmar_item_quando_enter_apos_ditar` — o texto ditado vira item pelo parser (fluxo atual).

**Limitação registrada:** o reconhecimento real depende de device/permissão e **não roda no CI** (como o deep link físico) — smoke manual no aparelho.

## 7. Documentos donos no mesmo PR
- `05` (§6.3 + §2.1 de plataforma): microfone no campo, `onDevice`, config Android/iOS, oculto em Web/Desktop.
- `10` (wireframe/nota do microfone no campo).
- `12` (RF-26 + rastreabilidade), `14` (Fase 30 + progresso), `16` (A6).

## 8. Decisões registradas (21/09/2026)

1. A voz **preenche o campo** (o usuário confirma); não adiciona direto.
2. **On-device solicitado** (`onDevice: true`, pt-BR): o app pede reconhecimento no dispositivo e nunca inicia chamada de rede própria; no Android o SO pode usar o reconhecedor de rede quando não há modelo on-device — limitação do plugin/SO, documentada (não há API para verificar/forçar em `speech_to_text` 7.5.0). Indisponível → aviso amigável.
3. Plugin **`speech_to_text`** (sem segredo/serviço de nuvem); microfone **só em Android/iOS**.
4. Abstração `ReconhecimentoVoz` + fake para testes; plugin real é smoke em device.
5. Sem schema/RLS/sync; **sem ADR novo**. Fase **30**, requisito **RF-26**.

## 9. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — UI e plataforma
- [10 Wireframes](../10-wireframes-telas.md) — microfone no campo
- [12 PRD](../12-prd.md) — RF-26
- [14 Tarefas](../14-tarefas.md) — Fase 30
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda A (A6)
