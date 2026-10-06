# 07 — Qualidade, Testes e CI

> Navegação: [← 06 MVP & Entregas](06-mvp-entregas.md) · [← Índice](../planejamento_lista_compras.md)

**Este documento é o dono da estratégia de qualidade.** Princípio: **cobertura por risco, não por percentual** — os componentes mais arriscados (repositórios/Drift, parser local e fluxos críticos) recebem os testes mais pesados. O app é **único e local**, sem Supabase/RLS/Realtime/Sentry (F48).

---

## 1. Estratégia de testes (pirâmide adaptada)

| Camada | Ferramenta | O quê | Prioridade |
| :--- | :--- | :--- | :--- |
| **Repositórios** (unit) | `flutter_test` + Drift in-memory | CRUD local, dedup, arquivo, orçamento, histórico de preços | **Máxima** (RF-03) |
| **Parser local** (unit) | `flutter_test` | Casos da [04 §3](04-importacao-lista.md) (vírgula decimal, frações, glifos, limites) | **Máxima** (RF-16) |
| **Widgets** | `flutter_test` + `golden_toolkit` (opcional) | Telas críticas: painel, lista, importação, editor, modo mercado, configurações | Alta (RF-02…RF-05, RF-16) |
| **Fluxos críticos** (E2E no widget) | `flutter_test` + router real + Drift in-memory | Caminhos criar/adicionar/marcar/limpar, importar e backup — roda no CI | Alta (RNF-08) |
| **Voz** (unit) | `flutter_test` | `ReconhecimentoVoz` com fake; plugin real é smoke em device | Média (RF-26) |
| **E2E** (integração app) | `integration_test` (opcional, pós-MVP) | Fluxo completo do app | Baixa |

**Convenções:**
* Nomes: `deve_<resultado>_quando_<condição>` (ex.: `deve_somar_quantidade_quando_item_duplicado_mesma_unidade`).
* Repositórios testados com Drift in-memory (determinístico, sem rede).
* **Fluxos críticos (E2E no widget):** rodam no CI via `flutter test` — o harness `test/fluxos/fluxo_harness.dart` monta o app real (router + Drift in-memory) e cobre criar/adicionar/marcar/limpar/desfazer, importar por texto e backup.

**Adiados (não rodam no CI atual):** **goldens** são sensíveis à plataforma — o dev gera no Windows e o CI roda Linux; revisitar quando houver runner Linux dedicado. **`integration_test` (device/emulador)** exige device; é validado por smoke manual. Nenhum dos dois bloqueia o merge.

## 2. O que é testado vs. aceito sem teste

| Testado | Aceito sem teste (MVP) |
| :--- | :--- |
| Repositórios, parser local, widgets críticos, fluxos críticos | UI de detalhe (animações), theming visual, performance fino. A **localização pt/en/es** tem guardas (`arb_paridade_test`, `localizacao_test`, `idioma_test`) |

**Voz (RF-26):** a abstração `ReconhecimentoVoz` é testada com fake; o **reconhecimento real no device** é smoke manual, não roda no CI.

---

## 3. CI — GitHub Actions

Pipeline único `.github/workflows/ci.yml`, disparado em PR e push em `main`:

```
┌────────────────────────────────────────────────┐
│ job: flutter                                   │
│  1. dart format --set-exit-if-changed .        │
│  2. flutter analyze                            │
│  3. flutter test (unit + widget)               │
│  4. flutter build web --release                │
│  5. flutter build apk --debug                  │
│  6. flutter build appbundle --release          │
│  7. manifest release: sem INTERNET/Firebase    │
├────────────────────────────────────────────────┤
│ job: desktop (matriz, paralelo)                │
│  Linux: deps (clang/cmake/ninja/gtk) + build   │
│  Windows: flutter build windows                │
└────────────────────────────────────────────────┘
```

* **Branch protection de `main`:** o único status obrigatório é o job **`flutter`** do GitHub Actions (`strict: true`, exige o CI verde do HEAD do PR). O job `desktop` **não** é exigido (é matriz — o check real é `desktop (ubuntu-latest)`/`desktop (windows-latest)`). **Administradores não podem ignorar** (`enforce_admins`), então push direto em `main` é rejeitado: o fluxo é **branch → PR → `flutter` verde → merge**. O check histórico `supabase` foi removido na F48 (não existe mais job).
* **Builds (F18-T05, ADR-012; F48/F49):** o job `flutter` compila o Web (`flutter build web --release`), o **apk Android em debug** e o **AAB release** — **sem `--flavor` e sem `--dart-define`** (o app é único). O `appbundle` roda com o **R8 do AGP 9** e depende de **`android/app/proguard-rules.pro`** (regras do **MLKit OCR**, RF-37/F54 — dívida **L-10**, [09 §2.9](09-runbook-operacoes.md)): sem elas o release aborta com *"Missing class"* dos reconhecedores opcionais de chinês/devanagari/japonês/coreano. Em seguida **verifica o manifest mergeado** (`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`): o passo falha se aparecerem `INTERNET`, `com.google.android.c2dm` ou os nós do **SDK do Firebase** (`FirebaseInitProvider`, `com.google.firebase.components.ComponentDiscoveryService`, `com.google.firebase.messaging`, `com.google.firebase.iid`, `com.google.firebase.installations`, `com.google.firebase.datatransport`, `io.flutter.plugins.firebase.*`, `FlutterFirebaseMessagingInitProvider`), se `allowBackup` não for `false`, se `RECORD_AUDIO` sumir (voz, RF-26) ou se o `MlKitComponentDiscoveryService` sumir (QR, RF-33). **Exceção deliberada (F49):** o `mobile_scanner` (QR) usa o MLKit bundled, que embute o registrar **local** do `firebase-components` — logo o guard proíbe os **nós do SDK/rede**, e não o literal `com.google.firebase` (o MLKit não adiciona `INTERNET`; [09 §2.11](09-runbook-operacoes.md)). O job `desktop` valida `flutter build linux` (ubuntu-24.04, instala `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`) e `flutter build windows` (windows-2025) numa matriz com `fail-fast: false`.
* **Imagens de runner fixadas:** `ubuntu-24.04` (job `flutter` e Linux do `desktop`) e `windows-2025` (Windows do `desktop`) — em vez de `ubuntu-latest`/`windows-latest`. Evita que a migração automática do `ubuntu-latest` para Ubuntu 26 (a partir de 19/10/2026) quebre o build sem aviso e reduz flakiness de alocação de runner. Ao trocar a imagem, o `if: matrix.os == 'ubuntu-24.04'` (deps do Linux) deve acompanhar.
* **Assets WASM do Drift versionados (F18-T01):** `web/drift_worker.js` e `web/sqlite3.wasm` são cópias fiéis da release oficial `drift-2.34.4` (mesma versão pinada em `pubspec.lock`), necessárias ao banco no navegador (`WasmDatabase`/OPFS-IndexedDB, [05 §2.1](05-app-flutter.md), ADR-012). Para regenerar (ex.: subir o Drift), baixar da release correspondente e substituir os dois arquivos:
  ```bash
  curl -L -o web/drift_worker.js https://github.com/simolus3/drift/releases/download/drift-2.34.4/drift_worker.js
  curl -L -o web/sqlite3.wasm    https://github.com/simolus3/drift/releases/download/drift-2.34.4/sqlite3.wasm
  ```
  A versão do Drift em `pubspec.lock` e os assets devem andar juntos; `flutter build web --release` valida a **compilação** — a corretude dos assets WASM é de **runtime**, não de build.
* **Nenhum segredo no CI:** o app não tem backend nem chaves; os builds são reprodutíveis sem `--dart-define`. Arquivos realmente secretos (`android/key.properties`) ficam fora do git.
* Flutter **pinado** à versão usada pelo dev (`flutter-version` no `flutter-action`) — o formatter do Dart muda entre versões (quebraria `dart format --set-exit-if-changed`).
* Tempo alvo do pipeline: < 10 min.

### Esqueleto de referência

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  flutter:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.44.5 }
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --release
      - run: flutter build apk --debug
      - run: flutter build appbundle --release
      - name: Manifest release sem INTERNET nem SDK Firebase   # F48/F49
        run: |
          MANIFEST=build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
          test -f "$MANIFEST" || { echo "manifest mergeado não encontrado"; exit 1; }
          falhou=0
          grep -q 'android.permission.INTERNET' "$MANIFEST" && { echo "INTERNET no manifest"; falhou=1; }
          grep -q 'com.google.android.c2dm' "$MANIFEST" && { echo "c2dm no manifest"; falhou=1; }
          grep -q 'com.google.firebase.provider.FirebaseInitProvider' "$MANIFEST" && { echo "FirebaseInitProvider no manifest"; falhou=1; }
          grep -q 'com.google.firebase.components.ComponentDiscoveryService' "$MANIFEST" && { echo "ComponentDiscoveryService no manifest"; falhou=1; }
          grep -q 'com.google.firebase.messaging' "$MANIFEST" && { echo "FirebaseMessaging no manifest"; falhou=1; }
          grep -q 'com.google.firebase.iid' "$MANIFEST" && { echo "FirebaseInstanceId no manifest"; falhou=1; }
          grep -q 'com.google.firebase.installations' "$MANIFEST" && { echo "FirebaseInstallations no manifest"; falhou=1; }
          grep -q 'com.google.firebase.datatransport' "$MANIFEST" && { echo "FirebaseDataTransport no manifest"; falhou=1; }
          grep -q 'io.flutter.plugins.firebase' "$MANIFEST" && { echo "io.flutter.plugins.firebase no manifest"; falhou=1; }
          grep -qi 'flutterfirebasemessaginginitprovider' "$MANIFEST" && { echo "FlutterFirebaseMessagingInitProvider no manifest"; falhou=1; }
          grep -q 'android:allowBackup="false"' "$MANIFEST" || { echo "allowBackup não desligado"; falhou=1; }
          grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST" || { echo "RECORD_AUDIO sumiu"; falhou=1; }
          grep -q 'com.google.mlkit.common.internal.MlKitComponentDiscoveryService' "$MANIFEST" || { echo "MLKit sumiu (QR quebra)"; falhou=1; }
          exit $falhou

  desktop:
    strategy:
      fail-fast: false
      matrix:
        include:
          - { os: ubuntu-24.04,  comando: flutter build linux }
          - { os: windows-2025, comando: flutter build windows }
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.44.5 }
      - if: matrix.os == 'ubuntu-24.04'
        run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
      - run: ${{ matrix.comando }}
```

---

## 4. Observabilidade

* **Sem telemetria remota.** Não há Sentry nem envio de erros (decisão do dono, coerente com o app local — RF-31/F48).
* Erros de UI são exibidos in-app (`AppEstadoErro`, SnackBars) e o diagnóstico depende do relato do usuário e de reprodução local.
* Logs de desenvolvimento (`flutter run`) nunca contêm conteúdo de listas em serviços externos — nada sai do aparelho.

---

## 5. Checklist de qualidade por PR (disciplina leve)

- [ ] `dart format` e `flutter analyze` sem queixas.
- [ ] Novo comportamento local (repositório/parser/UI) tem teste correspondente.
- [ ] CI verde antes do merge.
- [ ] Sem segredo/chave em código ou logs.
- [ ] Docs donos atualizados no mesmo PR quando o comportamento mudou.

---

## Documentos relacionados
- [05 App Flutter](05-app-flutter.md) — telas e fluxos testados
- [06 MVP & Entregas](06-mvp-entregas.md) — DoD por fase
- [13 Pré-modelo Técnico](13-premodelo-tecnico.md) — contexto para executar qualquer tarefa
