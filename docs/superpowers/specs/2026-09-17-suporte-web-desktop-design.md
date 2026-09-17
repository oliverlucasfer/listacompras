# Spec — Suporte a Web e Desktop (Fase 18)

> Navegação: [← 00 Visão geral](../../00-visao-geral.md) · [05 App Flutter](../../05-app-flutter.md) · [07 Qualidade/CI](../../07-qualidade-ci.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-17 · Status: aprovada

## 1. Objetivo

Fazer o app rodar em **Web** (navegador, funcionalidade completa: banco, auth por link, convites, sync e import) e em **Desktop** (Windows, Linux e macOS), mantendo 100% do comportamento atual em Android/iOS. Sem publicação: hospedagem pública e domínio seguem na **F5-T06** (gate do dono).

Fase nova: **F18 — Suporte a Web e Desktop**. Decisão de arquitetura: **ADR-012** no [00](../../00-visao-geral.md).

## 2. Contexto

- Só existem `android/`, `ios/` e `web/` no repo; `.metadata` não registra desktop.
- **O build web não compila** hoje, por dois motivos:
  - `lib/drift/database.dart:1` importa `dart:io` e abre `NativeDatabase` ([L62-67](../../../lib/drift/database.dart)); `dart:io` e FFI não existem no dart2js.
  - `lib/features/convites/data/convites_repository.dart:2` importa `dart:io show SocketException` ([L51](../../../lib/features/convites/data/convites_repository.dart) e L145).
- Drift 2.34.4 já inclui `package:drift/wasm.dart` (`WasmDatabase.open`) e o `sqlite3` 3.5.2 fornece o `sqlite3.wasm` — **sem upgrade de dependência**.
- **Auth e links são scheme custom** e não funcionam no navegador: `SupabaseAuthRepository.deepLink = br.com.oliverlucas.listacompras://login-callback` ([L13](../../../lib/features/auth/data/supabase_auth_repository.dart)) usado em `signUp`/`resetPasswordForEmail`; e o convite gera `br.com.oliverlucas.listacompras://entrar?token=` ([L155-156](../../../lib/features/convites/data/convites_repository.dart)).
- O `go_router` já tem as rotas `/entrar` ([router.dart:86-90](../../../lib/router.dart)) e trata deep link de convite via `app_links` ([deeplink_convite.dart](../../../lib/core/utils/deeplink_convite.dart)); no web o convite chega como URL normal do navegador.
- Pontos de extensão limpos já existentes: `AppDatabase([QueryExecutor? executor])` ([database.dart:18](../../../lib/drift/database.dart)) e `appDatabaseProvider` ([listas_providers.dart:10-14](../../../lib/features/listas/providers/listas_providers.dart)).
- `web/manifest.json` está travado em `orientation: portrait-primary`; `package_info_plus` no web depende de `version.json`; `share_plus` no web usa a Web Share API (só em contexto seguro).
- `AppShell` já alterna `NavigationRail` por largura ≥ 600 — pronto para telas grandes.
- Riscos de plataforma: `connectivity_plus` no web usa `navigator.onLine` (impreciso); `path_provider` não tem implementação web (o banco web não usa arquivo).

## 3. Decisões (2026-09-17)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Integração do banco web | **Fábrica própria com import condicional** + `WasmDatabase.open` | Sem dependências novas; mantém o caminho nativo intacto; controle explícito |
| `drift_flutter` | **Não adotar** | Adicionaria 2 dependências e mudaria o comportamento nativo (isolate) sem necessidade |
| Persistência web | **Escolhida pelo Drift** (`WasmDatabase.open` prefere OPFS quando disponível, com IndexedDB como fallback) | Sem configurar storage manualmente; usa o melhor mecanismo que o navegador oferecer |
| Assets web | **Versionar** `web/sqlite3.wasm` + `web/drift_worker.js`, baixados da release `drift-2.34.4` | `flutter run -d chrome` e o CI funcionam sem passo extra; versões fixadas e documentadas |
| Erros de rede | Helper `ehSemConexao` com import condicional | `SocketException` não existe no web; mantém os testes atuais verdes |
| Estratégia de URL no web | **Path URL strategy** (`usePathUrlStrategy`) | URLs limpas (`/entrar?token=`) e sem conflito com tokens do Supabase (que vão no fragmento) |
| Origem base | Web: `Uri.base.origin` em runtime; nativo: `--dart-define=APP_WEB_URL` | Funciona já em localhost e troca só o valor ao publicar |
| Redirect de auth | Web: `<origem>/login-callback` (nova rota); nativo: scheme atual | Cobre signup/verificação e recuperação nos dois mundos |
| Link de convite | Web: `https://<origem>/entrar?token=…`; nativo: scheme atual | Link clicável no navegador; no nativo segue o deep link |
| Desktop | Criar `windows/`, `linux/`, `macos/`; CI builda Linux e Windows; macOS local | Cobre os três SOs pedidos sem exigir runner macOS no CI |
| Banco entre plataformas | Armazenamentos **separados** (arquivo no nativo, IndexedDB no web) | Não há migração entre eles; o sync do Supabase reconcilia |
| Publicação | Fora de escopo (permanece F5-T06) | Gate do dono |

## 4. Comportamento

### 4.1 Banco de dados multi-plataforma

- `lib/drift/conexao/conexao.dart` — contrato `QueryExecutor abrirBancoLocal()` e o import condicional:
  `import 'conexao_nativa.dart' if (dart.library.js_interop) 'conexao_web.dart';`
- `conexao_nativa.dart` — o comportamento atual: `path_provider` → `File` → `NativeDatabase(file)` (usado por Android/iOS/desktop).
- `conexao_web.dart` — `WasmDatabase.open(databaseName: 'lista_compras', sqlite3Uri: Uri.parse('sqlite3.wasm'), driftWorkerUri: Uri.parse('drift_worker.js'))`, devolvendo `result.resolvedExecutor` dentro de `LazyDatabase`. A persistência é escolhida pelo Drift (OPFS quando disponível; IndexedDB como fallback).
- `lib/drift/database.dart` deixa de importar `dart:io`/`drift/native.dart`/`path_provider` e passa a delegar à fábrica. `AppDatabase([executor])`, `schemaVersion`, `migration` e `options` **não mudam** (testes injetam `NativeDatabase.memory()` e seguem iguais).
- `web/drift_worker.js` e `web/sqlite3.wasm` — assets pré-compilados, baixados da release oficial `drift-2.34.4` (`https://github.com/simolus3/drift/releases/download/drift-2.34.4/{drift_worker.js,sqlite3.wasm}`), versionados no repo. A regeneração é documentada no [05](../../05-app-flutter.md) e no [07](../../07-qualidade-ci.md).

### 4.2 Erros de rede por plataforma

- `lib/core/rede/erro_rede.dart` — `bool ehSemConexao(Object erro)` com import condicional:
  - nativa: `erro is SocketException || erro is ClientException || erro is TimeoutException`;
  - web: `erro is ClientException || erro is TimeoutException`.
- `convites_repository.dart` deixa de importar `dart:io` e passa a usar `ehSemConexao` nos `catch`. Os testes que lançam `SocketException` (rodam na VM) continuam exercitando o caminho nativo.

### 4.3 Auth e links

- `lib/core/config/links.dart`:
  - `String origemWeb()` → `kIsWeb ? Uri.base.origin : const String.fromEnvironment('APP_WEB_URL', defaultValue: 'http://localhost:8080')`.
  - `String redirectAuth()` → web: `'${Uri.base.origin}/login-callback'`; nativo: `br.com.oliverlucas.listacompras://login-callback` (constante `deepLinkNativo` em `links.dart`, reusada por `SupabaseAuthRepository`).
  - `String linkConvite(String token)` → web: `'${Uri.base.origin}/entrar?token=…'`; nativo: `br.com.oliverlucas.listacompras://entrar?token=…`.
- `SupabaseAuthRepository` passa a usar `redirectAuth()` em `signUp(emailRedirectTo:)` e `resetPasswordForEmail(redirectTo:)`.
- `ConvitesRepository.linkConvite` passa a usar o helper (web https / nativo scheme).
- `router.dart` ganha a rota **`/login-callback`** (pública, com uma tela mínima de carregamento): o `supabase_flutter` processa os tokens da URL e o redirect global leva a `/listas` (sessão) ou `/redefinir-senha` (recuperação).
- **Path URL strategy no web**: inicialização condicional (`lib/core/web/url_strategy.dart` no-op no nativo; `usePathUrlStrategy()` no web) chamada antes de `runApp`.
- `deeplink_convite.dart` passa a ser **apenas nativo** (`!kIsWeb`): no web o navegador entrega `/entrar?token=…` direto ao `go_router`.

### 4.4 Ajustes do app web

- `web/manifest.json`: remover `"orientation": "portrait-primary"`.
- `version.json`: criar `web/version.json` (`app_name`, `version`, `build_number`, `package_name`) para o `package_info_plus` no web.
- `sheet_convidar.dart`: envolver o compartilhamento em `try/catch` — quando a Web Share API não existir (desktop/alguns navegadores), mostrar mensagem orientando usar o botão **Copiar link** (que já existe no sheet).
- Sem mudança visual: `AppShell` já responde por largura (Rail ≥ 600).

### 4.5 Desktop

- `flutter create --platforms=windows,linux,macos .` cria as pastas e registra no `.metadata` (não altera `android/`/`ios/`/`web/`).
- Banco nativo já cobre desktop (o native asset do `sqlite3` 3.5.2 compila por SO); **se** algum SO falhar na implementação, adicionar `sqlite3_flutter_libs` como rede de segurança.
- Ícones de app para desktop via `flutter_launcher_icons` (windows/macos), tamanho mínimo de janela e título já definidos no runner gerado.
- Deep link/universal link no desktop **fora de escopo** (pós-MVP): o app abre e funciona normalmente; o convite por link continua no fluxo do navegador/app mobile.

## 5. Arquivos

**Criar**
- `lib/drift/conexao/conexao.dart`, `conexao_nativa.dart`, `conexao_web.dart`
- `lib/core/rede/erro_rede.dart` (+ variantes condicionais `_nativa`/`_web`)
- `lib/core/config/links.dart`
- `lib/core/web/url_strategy.dart` (+ variantes condicionais)
- `web/drift_worker.js`, `web/sqlite3.wasm` (baixados da release `drift-2.34.4`)
- `web/version.json` (versão para o `package_info_plus` no web)
- `windows/`, `linux/`, `macos/` (gerados por `flutter create`)
- `test/core/config/links_test.dart`, `test/core/rede/erro_rede_test.dart`

**Modificar**
- `lib/drift/database.dart` (delega à fábrica; remove `dart:io`)
- `lib/features/convites/data/convites_repository.dart` (remove `dart:io`; usa `erro_rede` e `links`)
- `lib/features/auth/data/supabase_auth_repository.dart` (usa `redirectAuth()`)
- `lib/router.dart` (rota `/login-callback`)
- `lib/core/utils/deeplink_convite.dart` (só nativo)
- `lib/main.dart` (aplica a URL strategy no web)
- `lib/features/convites/ui/sheet_convidar.dart` (fallback copiar link)
- `web/manifest.json`; `pubspec.yaml` (adicionar `flutter_web_plugins` do SDK e, se algum SO desktop falhar, `sqlite3_flutter_libs`)
- `.github/workflows/ci.yml` (build web + job desktop linux/windows)
- `test/features/convites/convites_repository_test.dart` (ajuste do fake de rede, se necessário)

**Docs**
- `docs/00` (plataformas, ADR-012, cronograma), `docs/05` (banco por plataforma, auth/links, URL strategy, assets), `docs/06` (matriz de distribuição web/desktop), `docs/07` (builds web/desktop e regeneração dos assets), `docs/09` (Site URL/Redirect URLs do Supabase Auth), `docs/12/13` (plataformas), `docs/14` (Fase 18), `README.md`, `planejamento_lista_compras.md`

## 6. Testes

- **Unit:** `links.dart` (origem web vs nativa, montagem do link de convite e do redirect) e `erro_rede.dart` (classificação de `SocketException`/`ClientException`/`TimeoutException`) — rodam na VM.
- **Widget/unit existentes:** suíte atual intacta (17 arquivos usam `NativeDatabase.memory()`).
- **Compilação web como teste:** `.github/workflows/ci.yml` roda `flutter build web --release` com defines de teste (sem segredos) — é a garantia de que o import condicional compila para dart2js.
- **Builds desktop no CI:** `flutter build linux` (ubuntu) e `flutter build windows` (windows-latest).
- **Smoke manual:** `flutter run -d chrome` → login, criar lista, CRUD, sync, import local, convite por link `http://localhost:<porta>/entrar?token=…`; e rodar o app no Windows.

## 7. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **00** | Escopo/plataformas incluem Web completa + Desktop; **ADR-012** (WasmDatabase/IndexedDB no web; banco nativo no desktop); cronograma com a Fase 18 |
| **05** | Banco multi-plataforma (fábrica condicional + assets), auth/links por plataforma, path URL strategy, ajustes do app web |
| **06** | Matriz de distribuição: Web/Desktop como alvos suportados (publicação segue F5-T06) |
| **07** | CI passa a validar `flutter build web` e builds desktop; regeneração dos assets wasm |
| **09** | Operação: *Site URL* e *Redirect URLs* do Supabase Auth (localhost de dev e domínio futuro) |
| **12/13** | Menções de plataforma (MVP Android/iOS/Web + Desktop suportado) |
| **14** | Fase 18 + tarefas e tabela de progresso |

## 8. Fora de escopo

- Hospedagem, domínio público e checklist de publicação (F5-T06, gate do dono).
- Universal links / associação de domínio em nativo e desktop (pós-MVP).
- Build de macOS no CI (exige runner macOS) — macOS fica local.
- Migração de dados entre o banco web e o nativo (armazenamentos distintos; o sync reconcilia).
- Suporte a `flutter test --platform chrome` para o caminho web.

## 9. Critério de pronto

- `flutter build web --release` compila; `flutter run -d chrome` funciona com login, CRUD, sync e import local.
- `flutter build windows` e `flutter build linux` compilam; o app abre no Windows e persiste dados.
- `android/`/`ios/` sem regressão (suíte verde; APK continua buildando).
- `dart format` + `flutter analyze` + `flutter test` verdes; CI (format/analyze/test + build web + builds desktop) verde.
- Docs donos sincronizados; Fase 18 marcada em `docs/14`.

## 10. Operacional (Supabase Auth — requer o dono)

- Em **Authentication → URL Configuration**: definir *Site URL* e *Redirect URLs* para incluir as origens web usadas (ex.: `http://localhost:<porta>/**` em dev) e, quando houver domínio, `https://<domínio>/**`.
- O scheme atual (`br.com.oliverlucas.listacompras://login-callback`) permanece na lista para o nativo.
- Sem essa configuração, o redirect de auth no web é recusado pelo Supabase (o app mostra erro amigável).

## 11. Breakdown proposto (Fase 18)

- [ ] **F18-T00** — Spec + planejamento (ADR-012 no 00, Fase 18 no 14, ajustes 12/13) — sem tocar código.
- [ ] **F18-T01** — Banco multi-plataforma: fábrica condicional + assets (`drift_worker`/`sqlite3.wasm`) + remoção de `dart:io` do `database.dart`.
- [ ] **F18-T02** — Rede plataforma-agnóstica (`erro_rede`) + `links.dart` + auth/convites + rota `/login-callback` + URL strategy.
- [ ] **F18-T03** — Desktop: `flutter create` (windows/linux/macos), ícones, ajustes de runner, smoke no Windows.
- [ ] **F18-T04** — Web app: manifest, `version.json`, fallback de copiar link; smoke no Chrome.
- [ ] **F18-T05** — CI (build web + builds desktop) e docs donos; fechamento e progresso.
