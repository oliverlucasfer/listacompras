# Suporte a Web e Desktop — Implementation Plan (Fase 18)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o app rodar no **Web** (funcionalidade completa: banco, auth por link, convites, sync, import) e no **Desktop** (Windows/Linux/macOS), sem regressão em Android/iOS.

**Architecture:** Fábrica de conexão do Drift com import condicional (`WasmDatabase` no web, `NativeDatabase` no nativo) + helpers plataforma-agnósticos de rede e links; `go_router` com path URL strategy no web; pastas de desktop geradas por `flutter create`; CI validando `build web` e builds desktop.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Riverpod, Drift 2.34.4 (wasm + native), sqlite3 3.5.2, go_router, Supabase.

**Spec:** `docs/superpowers/specs/2026-09-17-suporte-web-desktop-design.md`

## Global Constraints

- **Sem dependências novas** para o banco: o web usa `WasmDatabase` do próprio Drift 2.34.4 (não adotar `drift_flutter`). Adicionar apenas `flutter_web_plugins` (SDK) para a URL strategy; `sqlite3_flutter_libs` só se algum SO desktop falhar.
- Assets web **versionados**: `web/drift_worker.js` e `web/sqlite3.wasm` da release `drift-2.34.4` (`https://github.com/simolus3/drift/releases/download/drift-2.34.4/{drift_worker.js,sqlite3.wasm}`).
- Persistência web: escolhida pelo Drift (`WasmDatabase.open` prefere OPFS; IndexedDB como fallback). Não forçar storage.
- `AppDatabase([QueryExecutor? executor])`, `schemaVersion = 3`, migrations e `options` **não mudam**; os 17 testes que injetam `NativeDatabase.memory()` seguem intactos.
- Origem base: web = `Uri.base.origin` em runtime; nativo = `--dart-define=APP_WEB_URL` (default `http://localhost:8080`).
- Scheme nativo preservado: `br.com.oliverlucas.listacompras://` (Android/iOS).
- `dart format` + `flutter analyze` + `flutter test` verdes antes de cada commit de código.
- Commits pt-BR no padrão `F18-Tnn: ...`.
- Docs donos atualizados no mesmo PR (AGENTS.md).
- Publicação/hospedagem fica **fora** (F5-T06, gate do dono).

---

### Task 0 (F18-T00): Planejamento (ADR-012, Fase 18)

**Files:**
- Modify: `docs/00-visao-geral.md`, `docs/14-tarefas.md`, `docs/12-prd.md`, `docs/13-premodelo-tecnico.md`

**Interfaces:**
- Consumes: spec `docs/superpowers/specs/2026-09-17-suporte-web-desktop-design.md`
- Produces: IDs `F18-T00…T05` e o ADR-012 que as tarefas seguintes citam.

- [ ] **Step 1: `docs/00-visao-geral.md` — plataformas e ADR-012**

Na seção de escopo (L13) e no diagrama (L31), onde diz “MVP: Android, iOS e Web (SPA). Desktop … em fase posterior (Fase 6)”, acrescentar que **Web passa a ter funcionalidade completa** (não só SPA/leitura) e que **Desktop (Windows/Linux/macOS) é suportado** na Fase 18. Adicionar ao final da lista de ADRs:
```markdown
- **ADR-012 — Suporte a Web e Desktop (Fase 18):** o banco local passa a ser aberto por uma fábrica com import condicional — `WasmDatabase` (Drift, persistência OPFS/IndexedDB) no web e `NativeDatabase` (arquivo) no nativo/desktop; auth e convites usam URL https no web (`Uri.base.origin`) e scheme custom no nativo; CI valida `flutter build web` e builds desktop. Hospedagem pública permanece na F5-T06.
```
No cronograma (L137-139), adicionar a Fase 18 após a Fase 17.

- [ ] **Step 2: `docs/14-tarefas.md` — Fase 18**

Inserir, antes de `## Progresso por fase (atualize ao concluir)`:
```markdown
## Fase 18 — Suporte a Web e Desktop

Spec: [superpowers/specs/2026-09-17-suporte-web-desktop-design.md](superpowers/specs/2026-09-17-suporte-web-desktop-design.md) · ADR-012 · Docs donos: 00, 05, 06, 07, 09.

- [ ] **F18-T00** — ADR-012 + planejamento (00, 12, 13, 14)
  Dep: — · Docs: [00](00-visao-geral.md), [14](14-tarefas.md)
  CP: ADR-012 no 00; Fase 18 no 14; menções de plataforma no 12/13 coerentes; sem tocar código.
- [ ] **F18-T01** — Banco multi-plataforma (fábrica condicional + assets wasm)
  Dep: F18-T00 · Docs: [05](05-app-flutter.md)
  CP: `database.dart` sem `dart:io`; `conexao_nativa`/`conexao_web`; assets `drift_worker.js`/`sqlite3.wasm` versionados; `analyze`/`test` verdes.
- [ ] **F18-T02** — Rede, links, auth e URL strategy (web compila)
  Dep: F18-T01 · Docs: [05](05-app-flutter.md), [09](09-runbook-operacoes.md), [12](12-prd.md)
  CP: `erro_rede` sem `dart:io`; `links.dart` (origem/scheme); `/login-callback`; `usePathUrlStrategy`; `flutter build web` compila.
- [ ] **F18-T03** — Desktop (Windows/Linux/macOS)
  Dep: F18-T02 · Docs: [05](05-app-flutter.md), [06](06-mvp-entregas.md)
  CP: pastas `windows/`/`linux/`/`macos/`; `flutter build windows` e `flutter build linux`; app abre e persiste no Windows.
- [ ] **F18-T04** — Ajustes do app web
  Dep: F18-T02 · Docs: [06](06-mvp-entregas.md)
  CP: manifest sem portrait fixo; `web/version.json`; compartilhar com fallback; smoke no Chrome.
- [ ] **F18-T05** — CI (build web + desktop) e docs donos; fechamento
  Dep: F18-T03, F18-T04 · Docs: [07](07-qualidade-ci.md), [09](09-runbook-operacoes.md)
  CP: CI verde com `build web` + builds desktop; 05/06/07/09 sincronizados; Fase 18 marcada.
```
Na tabela de progresso, inserir `| F18 Web e Desktop | 6 | 0 |` antes de `| **Total** |` e ajustar o Total para `| **Total** | **108** | **100** |` enquanto a F18 não concluir.

- [ ] **Step 3: `docs/12-prd.md` e `docs/13-premodelo-tecnico.md`**

- `12` §7 (fora de escopo, L137): trocar `desktop (F6)` por nota de que Desktop é suportado na Fase 18 (fora de escopo permanece “publicação de desktop”).
- `13` L84 (ADR 001): atualizar para “MVP = Android/iOS/Web; **Desktop suportado (F18)**”.

- [ ] **Step 4: Commit**

```bash
git add docs/00-visao-geral.md docs/14-tarefas.md docs/12-prd.md docs/13-premodelo-tecnico.md
git commit -m "F18-T00: ADR-012 e planejamento do suporte Web/Desktop"
```

---

### Task 1 (F18-T01): Banco multi-plataforma

**Files:**
- Create: `lib/drift/conexao/conexao.dart`, `conexao_nativa.dart`, `conexao_web.dart`
- Modify: `lib/drift/database.dart`
- Create: `web/drift_worker.js`, `web/sqlite3.wasm` (download)

**Interfaces:**
- Consumes: `AppDatabase([QueryExecutor? executor])` (inalterado), providers existentes.
- Produces: `QueryExecutor abrirBancoLocal()` resolvido por plataforma; `database.dart` sem `dart:io`.

- [ ] **Step 1: Criar `lib/drift/conexao/conexao_nativa.dart`**

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Banco local em arquivo (Android/iOS/desktop) — doc 05 §2, ADR-012.
QueryExecutor abrirBancoLocal() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'lista_compras.sqlite'));
    return NativeDatabase(file);
  });
}
```

- [ ] **Step 2: Criar `lib/drift/conexao/conexao_web.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Banco local no navegador via Drift/WASM (OPFS quando disponível;
/// IndexedDB como fallback) — doc 05 §2, ADR-012.
QueryExecutor abrirBancoLocal() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'lista_compras',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
```

- [ ] **Step 3: Criar `lib/drift/conexao/conexao.dart`**

```dart
export 'conexao_nativa.dart' if (dart.library.js_interop) 'conexao_web.dart';
```

- [ ] **Step 4: Ajustar `lib/drift/database.dart`**

Trocar o cabeçalho de imports (L1-6) por:
```dart
import 'package:drift/drift.dart';

import 'conexao/conexao.dart';
import 'tables/item_local.dart';
import 'tables/lista_local.dart';
import 'tables/mutacao_pendente.dart';
```
Substituir a função `_openConnection()` (L62-67) por:
```dart
QueryExecutor _openConnection() => abrirBancoLocal();
```
Nada mais muda em `database.dart` (schemaVersion, migrations, options intactos).

- [ ] **Step 5: Baixar os assets WASM do Drift (release 2.34.4)**

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://github.com/simolus3/drift/releases/download/drift-2.34.4/drift_worker.js" -OutFile "web/drift_worker.js"
Invoke-WebRequest -Uri "https://github.com/simolus3/drift/releases/download/drift-2.34.4/sqlite3.wasm" -OutFile "web/sqlite3.wasm"
Get-Item web/drift_worker.js, web/sqlite3.wasm | Select-Object Name, Length
```
Expected: `drift_worker.js` ≈ 355.222 bytes e `sqlite3.wasm` ≈ 748.686 bytes.

- [ ] **Step 6: Verificar que não há `dart:io` no caminho do banco**

Run:
```powershell
Select-String -Path lib/drift/database.dart -Pattern "dart:io|NativeDatabase|path_provider"
```
Expected: sem saída.

- [ ] **Step 7: Rodar a suíte**

Run: `dart format .`
Run: `flutter analyze`
Expected: “No issues found!”
Run: `flutter test`
Expected: todos verdes (os testes injetam `NativeDatabase.memory()`).

- [ ] **Step 8: Commit**

```bash
git add lib/drift web/drift_worker.js web/sqlite3.wasm
git commit -m "F18-T01: banco multi-plataforma com fabrica condicional (ADR-012)"
```

---

### Task 2 (F18-T02): Rede, links, auth e URL strategy

**Files:**
- Create: `lib/core/rede/erro_rede.dart`, `erro_rede_nativa.dart`, `erro_rede_web.dart`
- Create: `lib/core/config/links.dart`
- Create: `lib/core/web/url_strategy.dart`, `url_strategy_nativa.dart`, `url_strategy_web.dart`
- Modify: `lib/features/convites/data/convites_repository.dart`, `lib/features/auth/data/supabase_auth_repository.dart`, `lib/router.dart`, `lib/core/utils/deeplink_convite.dart`, `lib/main.dart`, `pubspec.yaml`
- Test: `test/core/rede/erro_rede_test.dart`, `test/core/config/links_test.dart`

**Interfaces:**
- Consumes: `AppStrings.conviteSemConexao`, `AppStrings.erroSemConexao` (existentes).
- Produces: `bool ehSemConexao(Object erro)`; `origemWeb()`, `redirectAuth()`, `linkConviteDe(String token, {bool web, Uri? base})`, `deepLinkNativo`; `usarPathUrlStrategy()`.

- [ ] **Step 1: Escrever os testes que falham**

`test/core/rede/erro_rede_test.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:lista_compras/core/rede/erro_rede.dart';

void main() {
  test('deve_ser_sem_conexao_quando_socket_exception', () {
    expect(ehSemConexao(const SocketException('off')), isTrue);
  });

  test('deve_ser_sem_conexao_quando_client_exception', () {
    expect(ehSemConexao(ClientException('x')), isTrue);
  });

  test('deve_ser_sem_conexao_quando_timeout', () {
    expect(ehSemConexao(TimeoutException('x')), isTrue);
  });

  test('deve_nao_ser_sem_conexao_quando_outro_erro', () {
    expect(ehSemConexao(const FormatException('x')), isFalse);
  });
}
```

`test/core/config/links_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/links.dart';

void main() {
  final base = Uri.parse('https://app.exemplo.com/algum/caminho');

  test('deve_usar_app_web_url_quando_nativo', () {
    expect(origemWeb(web: false, base: base), appWebUrl);
    expect(
      redirectAuth(web: false, base: base),
      'br.com.oliverlucas.listacompras://login-callback',
    );
  });

  test('deve_usar_origem_atual_quando_web', () {
    expect(origemWeb(web: true, base: base), 'https://app.exemplo.com');
    expect(
      redirectAuth(web: true, base: base),
      'https://app.exemplo.com/login-callback',
    );
  });

  test('deve_montar_link_de_convite_por_plataforma', () {
    expect(
      linkConviteDe('t1', web: false),
      'br.com.oliverlucas.listacompras://entrar?token=t1',
    );
    expect(
      linkConviteDe('t1', web: true, base: base),
      'https://app.exemplo.com/entrar?token=t1',
    );
  });
}
```

- [ ] **Step 2: Rodar os testes para ver falhar**

Run: `flutter test test/core/rede/erro_rede_test.dart test/core/config/links_test.dart`
Expected: FAIL (arquivos inexistentes/`ehSemConexao` não definido).

- [ ] **Step 3: Criar `lib/core/rede/erro_rede_nativa.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

/// Classifica falhas de rede no nativo/desktop (doc 05 §2, ADR-012).
bool ehSemConexao(Object erro) =>
    erro is SocketException ||
    erro is ClientException ||
    erro is TimeoutException;
```

- [ ] **Step 4: Criar `lib/core/rede/erro_rede_web.dart`**

```dart
import 'dart:async';

import 'package:http/http.dart' show ClientException;

/// Classifica falhas de rede no web (sem `dart:io`) — doc 05 §2, ADR-012.
bool ehSemConexao(Object erro) =>
    erro is ClientException || erro is TimeoutException;
```

- [ ] **Step 5: Criar `lib/core/rede/erro_rede.dart`**

```dart
export 'erro_rede_nativa.dart' if (dart.library.js_interop) 'erro_rede_web.dart';
```

- [ ] **Step 6: Criar `lib/core/config/links.dart`**

```dart
import 'package:flutter/foundation.dart';

/// URL pública do app web (usada pelo nativo para montar links compartilháveis).
/// Produção: `--dart-define=APP_WEB_URL=https://<dominio>`.
const appWebUrl = String.fromEnvironment(
  'APP_WEB_URL',
  defaultValue: 'http://localhost:8080',
);

/// Scheme registrado no AndroidManifest/Info.plist (doc 05 §6.1).
const deepLinkNativo = 'br.com.oliverlucas.listacompras://';

/// Origem usada para links: a atual no web; [appWebUrl] no nativo.
String origemWeb({bool web = kIsWeb, Uri? base}) =>
    web ? (base ?? Uri.base).origin : appWebUrl;

/// URL de retorno do fluxo de auth (verificação de e-mail / recuperação).
String redirectAuth({bool web = kIsWeb, Uri? base}) => web
    ? '${(base ?? Uri.base).origin}/login-callback'
    : '${deepLinkNativo}login-callback';

/// Link de convite compartilhável (doc 08 §1.1).
String linkConviteDe(String token, {bool web = kIsWeb, Uri? base}) => web
    ? '${(base ?? Uri.base).origin}/entrar?token=$token'
    : '${deepLinkNativo}entrar?token=$token';
```

- [ ] **Step 7: Rodar os testes para ver passar**

Run: `flutter test test/core/rede/erro_rede_test.dart test/core/config/links_test.dart`
Expected: PASS.

- [ ] **Step 8: Criar a URL strategy condicional**

`lib/core/web/url_strategy_nativa.dart`:
```dart
/// No nativo/desktop não há URL strategy de navegador.
void usarPathUrlStrategy() {}
```
`lib/core/web/url_strategy_web.dart`:
```dart
import 'package:flutter_web_plugins/url_strategy.dart';

/// URLs limpas no web (`/entrar?token=…`) — doc 05 §2, ADR-012.
void usarPathUrlStrategy() => usePathUrlStrategy();
```
`lib/core/web/url_strategy.dart`:
```dart
export 'url_strategy_nativa.dart' if (dart.library.js_interop) 'url_strategy_web.dart';
```

- [ ] **Step 9: Adicionar `flutter_web_plugins` ao `pubspec.yaml`**

Em `dependencies:` (após `flutter:`):
```yaml
  flutter_web_plugins:
    sdk: flutter
```
Run: `flutter pub get`
Expected: resolve sem erro.

- [ ] **Step 10: Aplicar a URL strategy no `lib/main.dart`**

Após `WidgetsFlutterBinding.ensureInitialized();` (L21), adicionar:
```dart
  usarPathUrlStrategy();
```
E o import:
```dart
import 'core/web/url_strategy.dart';
```

- [ ] **Step 11: Trocar `dart:io` por `erro_rede` no `convites_repository.dart`**

Remover `import 'dart:io' show SocketException;` (L2) e adicionar:
```dart
import '../../../core/config/links.dart';
import '../../../core/rede/erro_rede.dart';
```
Em `criarLink` (L51-57), trocar os três `on …` por:
```dart
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.conviteSemConexao);
      }
      rethrow;
    }
```
Em `aceitar` (L145-151), trocar os três `on …` por:
```dart
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.erroSemConexao);
      }
      rethrow;
    }
```
Trocar o corpo de `linkConvite` (L154-156) por:
```dart
  /// Link compartilhável do convite (web: https; nativo: scheme) — doc 08 §1.1.
  String linkConvite(String token) => linkConviteDe(token);
```

- [ ] **Step 12: Usar `redirectAuth()` no `supabase_auth_repository.dart`**

Adicionar `import '../../../core/config/links.dart';`. Substituir a constante L10-13 por uma remissão ao helper (remover `static const deepLink`):
```dart
  /// URL de retorno do fluxo de auth (doc 05 §6.1, ADR-012): https no web,
  /// scheme custom no nativo.
  String get redirectUrl => redirectAuth();
```
E usar `redirectUrl` em `signUp(emailRedirectTo: redirectUrl)` (L25) e `resetPasswordForEmail(email, redirectTo: redirectUrl)` (L34).

- [ ] **Step 13: Rota `/login-callback` no `router.dart`**

Adicionar `/login-callback` à lista `publica` (L37-43) e a rota antes do `StatefulShellRoute`:
```dart
      GoRoute(
        path: '/login-callback',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
```
(O `supabase_flutter` processa os tokens da URL; o redirect global leva a `/listas` ou `/redefinir-senha`.)

- [ ] **Step 14: `deeplink_convite.dart` só no nativo**

Adicionar `import 'package:flutter/foundation.dart' show kIsWeb;` e, logo após obter `router`, inserir:
```dart
  if (kIsWeb) {
    // No web a URL do convite chega direto ao go_router (/entrar?token=…).
    final sub = const Stream<Uri>.empty().listen((_) {});
    ref.onDispose(sub.cancel);
    return sub;
  }
```

- [ ] **Step 15: Verificar o web compilando**

Run: `dart format .`
Run: `flutter analyze`
Expected: “No issues found!”
Run: `flutter test`
Expected: todos verdes.
Run: `flutter build web --release --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste`
Expected: `✓ Built build/web`.

- [ ] **Step 16: Commit**

```bash
git add lib pubspec.yaml pubspec.lock test
git commit -m "F18-T02: rede e links por plataforma, auth web e URL strategy"
```

---

### Task 3 (F18-T03): Desktop (Windows/Linux/macOS)

**Files:**
- Create: `windows/`, `linux/`, `macos/` (gerados)
- Modify: `.metadata`, `pubspec.yaml` (ícones), `windows/runner/main.cpp`, `linux/runner/my_application.cc`

**Interfaces:**
- Consumes: `abrirBancoLocal()` nativo (Task 1) e a árvore já compilável para web (Task 2).
- Produces: runners de desktop buildáveis.

- [ ] **Step 1: Gerar as pastas de desktop**

Run: `flutter create --platforms=windows,linux,macos --org br.com.oliverlucas .`
Expected: cria `windows/`, `linux/`, `macos/` e registra em `.metadata`.

- [ ] **Step 2: Conferir que nada existente foi sobrescrito**

Run: `git status --short`
Expected: apenas `windows/`, `linux/`, `macos/`, `.metadata` (e possivelmente `pubspec.yaml` sem mudança útil). Se `android/`, `ios/`, `web/`, `lib/` ou `test/` aparecerem modificados, reverter com `git checkout -- <caminho>`.

- [ ] **Step 3: Ícones de desktop no `pubspec.yaml`**

No bloco `flutter_launcher_icons:` (após `web:`), adicionar:
```yaml
  windows:
    generate: true
    image_path: assets/branding/logo.png
    icon_size: 256
  macos:
    generate: true
    image_path: assets/branding/logo.png
```
Run: `dart run flutter_launcher_icons`
Expected: gera os ícones de Windows/macOS sem erro.

- [ ] **Step 4: Título e tamanho de janela no Windows**

Em `windows/runner/main.cpp`, garantir `window.Create(L"Lista de Compras", origin, size)` com `size` mínimo de `Size(420, 720)`.

- [ ] **Step 5: Título no Linux**

Em `linux/runner/my_application.cc`, garantir `gtk_header_bar_set_title(header_bar, "Lista de Compras")` e `gtk_window_set_default_size(window, 420, 720)`.

- [ ] **Step 6: Buildar Windows**

Run: `flutter build windows --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste`
Expected: `✓ Built build\windows\x64\runner\Release`.
(Se falhar por biblioteca nativa do sqlite3, adicionar `sqlite3_flutter_libs: ^0.5.0` em `dependencies:` e repetir.)

- [ ] **Step 7: Smoke no Windows**

Run: `flutter run -d windows --dart-define-from-file=dart_defines_prod.json`
Expected: o app abre; criar uma lista, adicionar item e reabrir mantendo os dados (persistência em arquivo).

- [ ] **Step 8: Commit**

```bash
git add windows linux macos .metadata pubspec.yaml pubspec.lock
git commit -m "F18-T03: suporte desktop (windows, linux, macos)"
```

---

### Task 4 (F18-T04): Ajustes do app web

**Files:**
- Create: `web/version.json`
- Modify: `web/manifest.json`, `lib/core/l10n/app_strings.dart`, `lib/features/convites/ui/sheet_convidar.dart`

**Interfaces:**
- Consumes: web já compilando (Task 2); `AppStrings` existentes.
- Produces: PWA sem orientação fixa; versão visível no web; compartilhar tolerante à ausência da Web Share API.

- [ ] **Step 1: Remover a orientação fixa do manifest**

Em `web/manifest.json`, remover a linha `"orientation": "portrait-primary",` (ajustar a vírgula anterior).

- [ ] **Step 2: Criar `web/version.json`**

```json
{"app_name":"Lista de Compras","version":"1.2.0","build_number":"6","package_name":"lista_compras"}
```
(Manter em sincronia com `pubspec.yaml` `version:` ao subir a versão.)

- [ ] **Step 3: Nova string para o fallback de compartilhar**

Em `lib/core/l10n/app_strings.dart`, logo após `linkCompartilhado` (L209), adicionar:
```dart
  static const compartilharIndisponivel =
      'Compartilhamento indisponível aqui. Use "Copiar link".';
```

- [ ] **Step 4: Fallback do compartilhamento no `sheet_convidar.dart`**

Substituir o corpo de `_compartilhar` (L84-91) por:
```dart
  Future<void> _compartilhar(Convite convite) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: ref.read(convitesRepositoryProvider).linkConvite(convite.token),
        ),
      );
      if (mounted) mostrarSnackBar(context, AppStrings.linkCompartilhado);
    } catch (_) {
      // Web Share API indisponível (desktop/alguns navegadores): orienta a
      // usar o botão "Copiar link" que já existe no sheet.
      if (mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    }
  }
```

- [ ] **Step 5: Rodar a suíte**

Run: `dart format .`
Run: `flutter analyze`
Expected: “No issues found!”
Run: `flutter test`
Expected: todos verdes.

- [ ] **Step 6: Smoke no Chrome**

Run: `flutter run -d chrome --dart-define-from-file=dart_defines_prod.json`
Expected: login, criar lista, adicionar/editar item, recarregar a página mantendo os dados (persistência wasm), import local e convite por link `http://localhost:<porta>/entrar?token=…`.

- [ ] **Step 7: Commit**

```bash
git add web/manifest.json web/version.json lib/core/l10n/app_strings.dart lib/features/convites/ui/sheet_convidar.dart
git commit -m "F18-T04: ajustes do app web (manifest, version.json, compartilhar)"
```

---

### Task 5 (F18-T05): CI e docs donos

**Files:**
- Modify: `.github/workflows/ci.yml`, `docs/05-app-flutter.md`, `docs/06-mvp-entregas.md`, `docs/07-qualidade-ci.md`, `docs/08-compartilhamento-colaborativo.md`, `docs/09-runbook-operacoes.md`, `docs/14-tarefas.md`

**Interfaces:**
- Consumes: builds web/desktop da Task 3-4.
- Produces: CI validando as plataformas; docs donos sincronizados.

- [ ] **Step 1: `flutter build web` no job `flutter` do CI**

Em `.github/workflows/ci.yml`, após o step `flutter test` (L33), adicionar:
```yaml
      - if: steps.check.outputs.flutter == 'enabled'
        run: >-
          flutter build web --release
          --dart-define=SUPABASE_URL=https://exemplo.supabase.co
          --dart-define=SUPABASE_ANON_KEY=teste
```

- [ ] **Step 2: Job `desktop` (Linux + Windows)**

Adicionar ao final de `.github/workflows/ci.yml`:
```yaml
  desktop:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            comando: flutter build linux
          - os: windows-latest
            comando: flutter build windows
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.5
      - if: matrix.os == 'ubuntu-latest'
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
      - run: ${{ matrix.comando }} --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste
```

- [ ] **Step 3: `docs/07-qualidade-ci.md`**

Na seção §3 (workflow), acrescentar ao fluxo os passos de build web e o job desktop; documentar em texto que os assets `web/drift_worker.js` e `web/sqlite3.wasm` são versionados a partir da release `drift-2.34.4` e como regenerar (baixar da release e substituir).

- [ ] **Step 4: `docs/05-app-flutter.md`**

Adicionar subseção “Banco e links por plataforma (ADR-012)” documentando: fábrica `abrirBancoLocal` (native/wasm), persistência OPFS/IndexedDB no web, path URL strategy, `links.dart` (origem https no web / `APP_WEB_URL` no nativo), rota `/login-callback` e os assets wasm requeridos no build web.

- [ ] **Step 5: `docs/06-mvp-entregas.md` e `docs/09-runbook-operacoes.md`**

- `06`: na matriz de distribuição (L94-97), acrescentar os alvos **Desktop (Windows/Linux/macOS)** e registrar que o Web é funcional completo; publicação segue F5-T06.
- `08`: na seção do link de convite (doc 08 §1.1/§2), registrar que o link compartilhável é **https no web** (`https://<origem>/entrar?token=…`) e **scheme custom no nativo** (`br.com.oliverlucas.listacompras://entrar?token=…`), citando ADR-012.
- `09`: em §2/secrets ou na seção de auth, documentar a configuração de **Authentication → URL Configuration** do Supabase: *Site URL* + *Redirect URLs* com `http://localhost:<porta>/**` (dev) e `https://<domínio>/**` (produção), mantendo o scheme nativo.

- [ ] **Step 6: Fechar a Fase 18 em `docs/14-tarefas.md`**

Marcar `- [x]` em `F18-T00`…`F18-T05`; linha `| F18 Web e Desktop | 6 | 6 |` e Total de volta a `| **Total** | **108** | **106** |`.

- [ ] **Step 7: Verificação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Run: `flutter build web --release --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste`
Run: `flutter build windows --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste`
Expected: tudo verde/compilado.

- [ ] **Step 8: Commit**

```bash
git add .github/workflows/ci.yml docs
git commit -m "F18-T05: CI de builds web/desktop e docs donos (ADR-012)"
```

---

## Checklist manual (dono)

- [ ] Supabase → **Authentication → URL Configuration**: incluir `http://localhost:<porta>/**` e (quando houver) `https://<domínio>/**` em *Redirect URLs*; manter o scheme `br.com.oliverlucas.listacompras://login-callback`.
- [ ] Publicação/hospedagem: segue na **F5-T06** (gate do dono).
