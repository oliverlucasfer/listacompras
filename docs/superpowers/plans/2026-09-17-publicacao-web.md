# Publicação Web — Implementation Plan (Fase 19)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar o app web em `https://lista-compras-34f93.web.app` com deploy automático pelo GitHub Actions, política de privacidade online e Supabase Auth apontando para a URL pública.

**Architecture:** O build `flutter build web --release` (defines de produção vindos de secrets) vai para `build/web`, servido pelo Firebase Hosting com rewrite de SPA, headers COOP/COEP (Drift/WASM) e `no-cache` nos arquivos de PWA. Uma página estática `/privacidade` reproduz o texto do app, com teste-guarda contra divergência. Dois jobs de CI publicam: `deploy` (`live` na `main`, após `flutter`+`supabase` verdes) e `preview` (canal por PR).

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Drift 2.34.4 (wasm), Supabase, firebase-tools 15.29.0, Firebase Hosting, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-17-publicacao-web-design.md`

## Global Constraints

- **Site único e default:** projeto `lista-compras-34f93`; URL pública `https://lista-compras-34f93.web.app`. Não criar segundo site de Hosting (a action publicaria em todos os targets do `.firebaserc`).
- **Nenhum segredo no repositório.** Localmente o build usa `dart_defines_prod.json` (já gitignored); no CI, secrets do repositório. A `SUPABASE_ANON_KEY`/publishable key **nunca** entra em código, doc ou log.
- **Esta fase não altera schema/RLS/sync:** nenhuma migration, nenhum `supabase db push`. `supabase db push --dry-run` deve continuar vazio.
- **Fora de escopo (gate do dono):** F5-T05 (usabilidade), F5-T06 (Play/AAB/declaração de dados), domínio próprio, source maps do Sentry, analytics, banner de cookies.
- **Dependência nova permitida:** apenas `url_launcher: ^6.3.0` (já estava no `pubspec.lock` como transitiva 6.3.2 — não adiciona pacote novo).
- `dart format` + `flutter analyze` + `flutter test` verdes antes de cada commit de código; CI verde obrigatório.
- Commits em pt-BR no padrão `F19-Tnn: ...`; docs donos atualizados **no mesmo commit/PR**.
- Comandos no Windows/PowerShell: usar `curl.exe` (o alias `curl` é `Invoke-WebRequest` e não aceita `-sI`).
- A fase não pode marcar a F5 como concluída em `docs/14`: as linhas F5-T05/T06 seguem `- [ ]`.

---

### Task 0 (F19-T00): Planejamento (ADR-013, Fase 19)

**Files:**
- Modify: `docs/00-visao-geral.md`, `docs/06-mvp-entregas.md`, `docs/12-prd.md`, `docs/13-premodelo-tecnico.md`, `docs/14-tarefas.md`

**Interfaces:**
- Consumes: spec `docs/superpowers/specs/2026-09-17-publicacao-web-design.md`
- Produces: ID **ADR-013** e as linhas **F19-T00…T04** que as tarefas seguintes citam em `Dep:`/`Docs:`.

- [ ] **Step 1: `docs/00-visao-geral.md` — ADR-013**

Logo após a linha `| ADR-012 | 17/09/2026 | Suporte a **Web completo** ...` (hoje L114), adicionar:
```markdown
| ADR-013 | 17/09/2026 | Publicação do **Web via Firebase Hosting** (Fase 19): deploy automático no GitHub Actions (canal de preview por PR e `live` na `main`), rewrite da SPA, headers COOP/COEP para o Drift/WASM e `/privacidade` estática; URL pública `https://lista-compras-34f93.web.app` | Supabase Storage como static host; Cloudflare Pages/Netlify/Vercel; deploy manual por CLI; segundo site de Hosting | Mesmo projeto/console já usado pelo Firebase App Distribution (F5-T05b); CDN e SSL gratuitos; headers, rewrites e histórico de releases nativos; Android/Play segue no gate (F5-T06) |
```

- [ ] **Step 2: `docs/00-visao-geral.md` — Fase 19 no cronograma**

Logo após a linha da `| **Fase 18** | **Suporte a Web e Desktop** ...` (hoje L130), adicionar:
```markdown
| **Fase 19** | **Publicação Web** | Publicar o app web em URL pública (Firebase Hosting) com deploy automático no CI, política de privacidade online e Supabase Auth apontando para a URL. **Web apenas**: testes de usabilidade (F5-T05) e Play (F5-T06) seguem no gate do dono. | URL pública com o app funcionando (auth, CRUD, import, convite, sync), headers de isolamento e rollback documentado; CI verde — spec em [`superpowers/specs/2026-09-17-publicacao-web-design.md`](superpowers/specs/2026-09-17-publicacao-web-design.md) |
```

- [ ] **Step 3: `docs/13-premodelo-tecnico.md` — ADR e plataformas**

Na tabela do §6 (L82-95), trocar a linha do ADR 001 por:
```markdown
| 001 | MVP = Android/iOS/Web; **Desktop suportado (F18)**; **Web publicado (F19)** |
```
E adicionar, depois da linha do 012 (L95):
```markdown
| 013 | Publicação do Web: Firebase Hosting (deploy no CI; F19) |
```

- [ ] **Step 4: `docs/12-prd.md` — fora de escopo**

No §7 "Fora de escopo (MVP)", na linha que começa com `Receitas/menus, ...`, trocar o trecho `publicação de desktop (o suporte a Desktop - Windows/Linux/macOS - entra na Fase 18)` por:
```markdown
publicação de desktop (o suporte a Desktop — Windows/Linux/macOS — entra na Fase 18; a **publicação Web** entra na **Fase 19**)
```

- [ ] **Step 5: `docs/06-mvp-entregas.md` — item de publicação desdobrado**

No §1 (L21), trocar:
```markdown
- [ ] Publicado: Web acessível por URL + APK/AAB disponível para teste interno.
```
por (os dois itens começam desmarcados; o primeiro é marcado pela F19-T04):
```markdown
- [ ] Publicado: **Web acessível por URL pública** (`https://lista-compras-34f93.web.app`, Fase 19 — ADR-013).
- [ ] Publicado: **APK/AAB disponível para teste interno** na Play Console (F5-T06, gate do dono).
```

- [ ] **Step 6: `docs/06-mvp-entregas.md` — numeração e notas de política/publicação**

Trocar o heading duplicado `### 3.3. Política de privacidade` (L78) por `### 3.3.2. Política de privacidade`. Nessa seção, trocar a linha `* **Onde:** página pública no site do app (Web já publicado na Fase 5) + link no cadastro e nas configurações do app.` por:
```markdown
* **Onde:** página pública em `https://lista-compras-34f93.web.app/privacidade` (Fase 19, ADR-013) + link no cadastro e nas configurações do app.
* **Contato do encarregado:** por decisão do dono (17/09/2026) o texto permanece genérico ("canal informado na página do aplicativo"); preencher com um e-mail dedicado é pendência do lançamento público (F5-T06).
```
No §4 (L94), trocar a linha da tabela do canal **Web (Fase 5)** por:
```markdown
| Web (Fase 19) | Build `flutter build web` + Firebase Hosting ([ADR-013](00-visao-geral.md)) | Publicado em `https://lista-compras-34f93.web.app` pela F19 (deploy automático no CI); domínio próprio fica pós-MVP |
```
E, na nota do dono (L102), trocar `a publicação Web + Play (teste interno) está **adiada**` por `a publicação na Play (teste interno) está **adiada** — o Web foi publicado na Fase 19`.

- [ ] **Step 7: `docs/14-tarefas.md` — Fase 19 e progresso**

Inserir, imediatamente antes de `## Progresso por fase (atualize ao concluir)`:
```markdown
## Fase 19 — Publicação Web

Spec: [superpowers/specs/2026-09-17-publicacao-web-design.md](superpowers/specs/2026-09-17-publicacao-web-design.md) · ADR-013 · Docs donos: 00, 06, 07, 09.

- [ ] **F19-T00** — ADR-013 + planejamento (00, 06, 12, 13, 14)
  Dep: — · Docs: [00](00-visao-geral.md), [06](06-mvp-entregas.md), [14](14-tarefas.md)
  CP: ADR-013 no 00; Fase 19 no 14; item de publicação do 06 §1 desdobrado; sem tocar código.
- [ ] **F19-T01** — Artefatos de hosting, política estática e primeiro deploy
  Dep: F19-T00 · Docs: [06 §3.3.2](06-mvp-entregas.md), [09](09-runbook-operacoes.md)
  CP: `firebase.json`/`.firebaserc`/`robots.txt`/`privacidade.html`; testes-guarda de paridade verdes; URL pública com COOP/COEP, rewrite e `/privacidade`.
- [ ] **F19-T02** — Supabase Auth e smoke funcional na URL pública
  Dep: F19-T01 · Docs: [09 §2.6/§2.7](09-runbook-operacoes.md)
  CP: Site URL e Redirect URLs de produção no Supabase; cadastro/verificação, login, CRUD, import, convite e sync validados na URL pública.
- [ ] **F19-T03** — Deploy no CI (preview por PR, live na main) e rollback
  Dep: F19-T02 · Docs: [07 §3](07-qualidade-ci.md), [09 §4](09-runbook-operacoes.md)
  CP: secrets no GitHub; jobs `deploy`/`preview` verdes; publicação automática na `main`; rollback exercitado e documentado.
- [ ] **F19-T04** — Política no app e fechamento
  Dep: F19-T03 · Docs: [06 §1/§3.3.2](06-mvp-entregas.md), [14](14-tarefas.md)
  CP: link "ver versão online" no sheet e no cadastro; `format`/`analyze`/`test` verdes; 06 §1 (web) marcado; Fase 19 marcada.
```
E, na tabela de progresso, adicionar antes da linha `| **Total** |`:
```markdown
| F19 Publicação Web | 5 | 0 |
```
atualizando o total de `| **Total** | **108** | **106** |` para `| **Total** | **113** | **106** |`.

- [ ] **Step 8: Validar e commitar**

```bash
dart format . ; flutter analyze ; flutter test
git add docs/00-visao-geral.md docs/06-mvp-entregas.md docs/12-prd.md docs/13-premodelo-tecnico.md docs/14-tarefas.md
git commit -m "F19-T00: ADR-013 e Fase 19 nos docs de planejamento"
```
Esperado: nenhum arquivo Dart tocado (`git status` limpo fora dos docs), `analyze`/`test` verdes como antes.

---

### Task 1 (F19-T01): Artefatos de hosting, política estática e primeiro deploy

**Files:**
- Create: `firebase.json`, `.firebaserc`, `web/robots.txt`, `web/privacidade.html`
- Create: `test/core/l10n/politica_privacidade_publica_test.dart`, `test/core/config/version_json_test.dart`
- Modify: `docs/09-runbook-operacoes.md` (§2.6 histórico — só a entrada da publicação)

**Interfaces:**
- Consumes: ADR-013 (Task 0); `lib/core/l10n/politica_privacidade.dart` (const `politicaPrivacidadeTexto`); `web/version.json`; `pubspec.yaml` (`version: 1.2.0+6`).
- Produces: URL pública `https://lista-compras-34f93.web.app`; arquivo `web/privacidade.html` em `/privacidade`; headers COOP/COEP — usados por T02 (smoke), T03 (CI) e T04 (link no app).

- [ ] **Step 1: Escrever o teste-guarda da política (deve falhar)**

Criar `test/core/l10n/politica_privacidade_publica_test.dart`:
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

List<String> _linhas(String texto) => texto
    .split('\n')
    .map((linha) => linha.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((linha) => linha.isNotEmpty)
    .toList();

/// Normaliza o HTML para o mesmo formato do texto do app: cada bloco
/// (`h1`, `h2`, `p`, `li`) vira uma linha; `<li>` ganha o marcador `• `.
List<String> _linhasDaPagina(String html) {
  final corpo = html.substring(html.indexOf('<body'), html.indexOf('</body>'));
  final comQuebras = corpo
      .replaceAll(RegExp(r'</(h1|h2|p|li)>'), '\n')
      .replaceAll('<li>', '• ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  return _linhas(comQuebras);
}

void main() {
  test('deve_ter_o_mesmo_texto_do_app_quando_a_politica_for_editada', () {
    final pagina = File('web/privacidade.html');
    expect(
      pagina.existsSync(),
      isTrue,
      reason: 'web/privacidade.html é obrigatória (doc 06 §3.3.2, F19-T01)',
    );

    expect(
      _linhasDaPagina(pagina.readAsStringSync()),
      _linhas(politicaPrivacidadeTexto),
      reason:
          'A página pública e o texto in-app precisam dizer exatamente o mesmo '
          '(edite os dois lados juntos)',
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/l10n/politica_privacidade_publica_test.dart`
Expected: FAIL — `web/privacidade.html é obrigatória (doc 06 §3.3.2, F19-T01)`.

- [ ] **Step 3: Criar `web/privacidade.html`**

Conteúdo exato (mesmas seções, mesmos textos, mesma pontuação de `lib/core/l10n/politica_privacidade.dart` — sem usar entidades HTML):
```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Política de Privacidade — Lista de Compras</title>
<style>
  body { margin: 0 auto; max-width: 44rem; padding: 1.5rem; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; line-height: 1.6; color: #1a1c1e; background: #fff; }
  h1 { font-size: 1.75rem; }
  h2 { font-size: 1.125rem; margin-top: 1.75rem; }
  ul { padding-left: 1.25rem; }
  li { margin-bottom: .35rem; }
</style>
</head>
<body>
<h1>Política de Privacidade</h1>
<h2>1. Dados que coletamos</h2>
<ul>
<li>E-mail e uma senha (armazenada apenas como hash) para autenticação.</li>
<li>O conteúdo das listas de compras que você cria (títulos e itens).</li>
<li>Marcadores técnicos de data/hora das alterações, usados pela sincronização.</li>
</ul>
<h2>2. Para que usamos</h2>
<ul>
<li>Permitir que você crie, use e sincronize suas listas de compras entre seus dispositivos.</li>
<li>Detectar e corrigir erros do aplicativo (registros técnicos de falhas, sem o conteúdo das suas listas).</li>
</ul>
<p>Não coletamos dados pessoais sensíveis. Não usamos seus dados para publicidade e não há rastreamento publicitário.</p>
<h2>3. Com quem compartilhamos</h2>
<p>Seus dados ficam hospedados no Supabase (infraestrutura AWS). A importação por texto acontece inteiramente no seu dispositivo (parser local, offline) — nenhum trecho colado é enviado a terceiros. Registros de erro podem ser processados pelo Sentry, sem conteúdo das suas listas. Não vendemos nem compartilhamos seus dados com mais ninguém.</p>
<h2>4. Por quanto tempo guardamos</h2>
<p>Até você excluir sua conta. Ao excluir a conta, todas as suas listas e itens são apagados permanentemente (exclusão física). Registros técnicos de erros podem permanecer pelo período de retenção do serviço de monitoramento.</p>
<h2>5. Seus direitos</h2>
<p>Você pode acessar e corrigir seus dados diretamente no aplicativo (ele é a visão dos seus dados) e excluir tudo pela opção "Excluir minha conta" nas Configurações. O app não é direcionado a menores de 16 anos.</p>
<h2>6. Contato</h2>
<p>Dúvidas sobre privacidade ou exercício de direitos: utilize o canal de contato informado na página do aplicativo.</p>
</body>
</html>
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `flutter test test/core/l10n/politica_privacidade_publica_test.dart`
Expected: PASS. Se falhar, a diferença estará na linha apontada pelo `reason` — corrigir o lado que divergiu (normalmente espaço ou pontuação).

- [ ] **Step 5: Escrever o teste-guarda do `version.json`**

Criar `test/core/config/version_json_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deve_bater_com_o_pubspec_quando_a_versao_mudar', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final bruto = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    final partes = bruto.split('+');

    final json =
        jsonDecode(File('web/version.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(
      json['version'],
      partes.first,
      reason: 'web/version.json alimenta o package_info_plus no web (F18-T04)',
    );
    expect(json['build_number'], partes.length > 1 ? partes[1] : '0');
  });
}
```

- [ ] **Step 6: Rodar o teste**

Run: `flutter test test/core/config/version_json_test.dart`
Expected: PASS (os valores de hoje já batem: `1.2.0` / `6`). É uma guarda preventiva: passa agora e falha quando alguém subir a versão só num lado.

- [ ] **Step 7: Criar `web/robots.txt`**

```
# Fase 19: fora do Google até a F5-T05 (usabilidade) e o lançamento (F5-T06).
User-agent: *
Disallow: /
```

- [ ] **Step 8: Ignorar o cache local do Firebase**

Acrescentar ao fim de `.gitignore`:
```
# Firebase CLI (cache de deploy do hosting — F19-T01)
.firebase/
```
Run: `git status --short` → Expected: `.firebase/` (se já existir) não aparece como não rastreado.

- [ ] **Step 9: Criar `.firebaserc`**

```json
{
  "projects": {
    "default": "lista-compras-34f93"
  }
}
```

- [ ] **Step 10: Criar `firebase.json`**

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
          { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
        ]
      },
      {
        "source": "/index.html",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      },
      {
        "source": "/version.json",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      },
      {
        "source": "/flutter_service_worker.js",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      }
    ]
  }
}
```

- [ ] **Step 11: Build local de produção**

```bash
flutter build web --release --dart-define-from-file=dart_defines_prod.json
```
Expected: `build/web` gerado (com `index.html`, `main.dart.js`, `flutter_service_worker.js`, `sqlite3.wasm`, `drift_worker.js`).

- [ ] **Step 12: Primeiro deploy**

```bash
firebase deploy --only hosting
```
Expected: `Deploy complete!` com `Hosting URL: https://lista-compras-34f93.web.app`.

- [ ] **Step 13: Validar headers, rewrite e estáticos**

```bash
curl.exe -sI https://lista-compras-34f93.web.app/
curl.exe -sI https://lista-compras-34f93.web.app/index.html
curl.exe -sI https://lista-compras-34f93.web.app/version.json
curl.exe -sI https://lista-compras-34f93.web.app/listas
curl.exe -sI https://lista-compras-34f93.web.app/privacidade
curl.exe -s https://lista-compras-34f93.web.app/robots.txt
curl.exe -sI https://lista-compras-34f93.web.app/main.dart.js
```

Expected: raiz `/` com `200`, `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` **e** `Cache-Control: no-cache`; `/index.html` responde `301 → /` (não é 200) e o `no-cache` vem do destino `/`, que carrega a `source: "/"` — é isso que faz o documento de entrada ser `no-cache`; `Cache-Control: no-cache` também em `/version.json` e `/flutter_service_worker.js`; `/listas` devolve o `index.html` (rewrite, sem 404) porém com o `Cache-Control` default `max-age=3600` (os headers seguem o path da requisição, não o destino do rewrite; aceitável pois `/version.json` e o service worker são `no-cache` e o app se atualiza ao carregar); `/privacidade` devolve o HTML estático (200); `robots.txt` com `Disallow: /`; `main.dart.js` continua **cacheável** (não `no-cache`).

- [ ] **Step 14: Registrar no runbook e commitar**

Em `docs/09-runbook-operacoes.md` §2.6, logo após a entrada de 11/09/2026, adicionar:
```markdown
- **Fase 19 — Publicação Web (17/09/2026):** F19-T01 publicou o build web no Firebase Hosting (projeto `lista-compras-34f93`, site default) em `https://lista-compras-34f93.web.app` — rewrite de SPA, headers COOP/COEP (Drift/WASM/OPFS) e `/privacidade` estática. Deploy manual nesta entrada; automatizado no CI pela F19-T03 (ADR-013).
```
```bash
dart format . ; flutter analyze ; flutter test
git add firebase.json .firebaserc .gitignore web/robots.txt web/privacidade.html test/core/l10n/politica_privacidade_publica_test.dart test/core/config/version_json_test.dart docs/09-runbook-operacoes.md
git commit -m "F19-T01: hospedagem (Firebase Hosting), politica publica e testes-guarda"
```

---

### Task 2 (F19-T02): Supabase Auth e smoke funcional na URL pública

**Files:**
- Modify: `docs/09-runbook-operacoes.md` (§2.6 histórico, §2.7 URLs de produção)

**Interfaces:**
- Consumes: URL pública e headers da Task 1.
- Produces: Supabase Auth aceitando `https://lista-compras-34f93.web.app/**` (pré-requisito do smoke de convite/login da Task 3 e do uso real).

- [ ] **Step 1: Configurar o Supabase Auth (dono, no dashboard)**

Authentication → URL Configuration:
- **Site URL:** `https://lista-compras-34f93.web.app`
- **Redirect URLs** (manter as existentes e acrescentar a de produção):
  - `http://localhost:8080/**` (dev web — ajustar a porta se o dev usar outra)
  - `br.com.oliverlucas.listacompras://login-callback` (nativo)
  - `https://lista-compras-34f93.web.app/**`

Expected: nenhum erro ao salvar; o aviso de "redirect_uri not allowed" deixa de aparecer no cadastro web.

- [ ] **Step 2: Smoke de shell e isolamento (Chrome)**

1. Abrir `https://lista-compras-34f93.web.app` → o app carrega na tela de login.
2. DevTools → Console: `crossOriginIsolated` → `true`.
3. Application → Storage: confirmar o banco do Drift (`lista_compras`) criado no OPFS/IndexedDB após o primeiro uso.
4. Recarregar em `/listas` (logado) e abrir `/entrar?token=abc` → sem 404 (rewrite da SPA).

- [ ] **Step 3: Smoke funcional completo**

1. Registrar conta nova com e-mail real → abrir o link de verificação recebido → volta para `/login-callback` e entra no app.
2. Criar lista, adicionar itens (quantidade + unidade), marcar/editar/remover, reordenar.
3. Importar lista por texto livre (modal "Importar lista") com pré-visualização e confirmação.
4. Recarregar a página → sessão e dados preservados (persistência local).
5. DevTools → Network → Offline: criar/editar item; voltar a Online → a fila sincroniza sem duplicar.
6. Em outro navegador (ou anônima), logar com a mesma conta → lista aparece e alterações refletem em < 5s (Realtime).
7. No app Android (build de teste), gerar convite e abrir o link no navegador → `/entrar?token=…` → aceitar → a lista aparece em "Compartilhadas".
8. Recuperar senha → e-mail chega com o link apontando para a URL pública → redefine e loga.

Expected: todos os passos funcionando; qualquer falha de redirect indica Site URL/Redirect URLs incorretos (voltar ao Step 1).

- [ ] **Step 4: Confirmar que nenhuma migration é necessária**

```bash
supabase db push --dry-run
```
Expected: diff vazio (esta fase não altera schema/RLS).

- [ ] **Step 5: Atualizar o runbook**

Em `docs/09-runbook-operacoes.md` §2.7, trocar os valores genéricos da tabela pelos reais:
```markdown
| Campo | Valor |
| :--- | :--- |
| **Site URL** | Produção: `https://lista-compras-34f93.web.app` · Dev: `http://localhost:<porta>` |
| **Redirect URLs** | `http://localhost:<porta>/**` (dev), `br.com.oliverlucas.listacompras://login-callback` (nativo) e `https://lista-compras-34f93.web.app/**` (produção) |
```
E, no §2.6, acrescentar ao final da entrada da Fase 19:
```markdown
  - F19-T02: Auth → URL Configuration com Site URL e Redirect URLs de produção (`https://lista-compras-34f93.web.app/**`); smoke completo na URL pública (cadastro/verificação, login, CRUD, import, offline→sync, Realtime em 2 navegadores e convite aceito pelo navegador) aprovado.
```

- [ ] **Step 6: Commitar**

```bash
git add docs/09-runbook-operacoes.md
git commit -m "F19-T02: Auth do Supabase apontando para a URL publica e smoke aprovado"
```

---

### Task 3 (F19-T03): Deploy no CI (preview por PR, live na main) e rollback

**Files:**
- Modify: `.github/workflows/ci.yml`, `docs/07-qualidade-ci.md` (§3 e esqueleto), `docs/09-runbook-operacoes.md` (§2.6 e §4)

**Interfaces:**
- Consumes: `firebase.json`/`.firebaserc` (Task 1); Auth configurado (Task 2); secrets do repositório.
- Produces: publicação automática na `main` e canais de preview em PR; cita os secrets `FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

- [ ] **Step 1: Criar a conta de serviço e os secrets (dono)**

1. Console do Firebase → Configurações do projeto → **Contas de serviço** → *Gerar nova chave privada* (JSON).
2. No Google Cloud Console (IAM), dar à conta de serviço o papel **Firebase Hosting Admin**.
3. GitHub → Settings → Secrets and variables → Actions → *New repository secret*:
   - `FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93` = conteúdo do JSON
   - `SUPABASE_URL` = `https://smshgctdwxkqbvbdlhud.supabase.co`
   - `SUPABASE_ANON_KEY` = a publishable key do projeto (mesmo valor de `dart_defines_prod.json`, que é gitignored)

Expected: os três secrets aparecem listados no repositório (valores não visíveis após salvar).

- [ ] **Step 2: Validar localmente o comando exato que o CI vai rodar**

```bash
flutter build web --release --dart-define-from-file=dart_defines_prod.json
```
Expected: build gera `build/web` sem erro. É o mesmo comando dos jobs, que trocam o arquivo local (gitignored) pelos secrets `SUPABASE_URL`/`SUPABASE_ANON_KEY` — assim nenhum valor de chave precisa ser digitado à mão aqui.

- [ ] **Step 3: Adicionar os jobs de publicação ao workflow**

Em `.github/workflows/ci.yml`, adicionar ao final do arquivo (após o job `desktop`):
```yaml
  deploy:
    # F19-T03: publica o build web na URL publica apos CI verde (ADR-013).
    if: github.event_name == 'push'
    needs: [flutter, supabase]
    runs-on: ubuntu-latest
    concurrency:
      group: hosting-live
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.5  # pinado ao SDK do dev
      - run: >-
          flutter build web --release
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93 }}
          projectId: lista-compras-34f93
          channelId: live
          firebaseToolsVersion: 15.29.0  # paridade com o CLI do dev

  preview:
    # F19-T03: canal de preview por PR (mesmos defines de producao; expira em 7d).
    if: >-
      github.event_name == 'pull_request' &&
      github.event.pull_request.head.repo.full_name == github.repository
    needs: [flutter, supabase]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    concurrency:
      group: hosting-pr-${{ github.event.pull_request.number }}
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.5  # pinado ao SDK do dev
      - run: >-
          flutter build web --release
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93 }}
          projectId: lista-compras-34f93
          expires: 7d
          firebaseToolsVersion: 15.29.0  # paridade com o CLI do dev
```

- [ ] **Step 4: Conferir o YAML antes de subir**

```powershell
python -c "import yaml,sys;yaml.safe_load(open('.github/workflows/ci.yml',encoding='utf-8'));print('yaml ok')"
```
Expected: `yaml ok`. (Se `python` não estiver disponível, conferir a indentação visualmente: os dois jobs ficam no mesmo nível de `flutter`, `supabase` e `desktop`.)

- [ ] **Step 5: Commitar e abrir PR (valida o preview)**

```bash
git add .github/workflows/ci.yml
git commit -m "F19-T03: deploy do web no CI (preview por PR, live na main)"
git push -u origin HEAD
```
Expected: na aba Actions do PR, o job `preview` roda e conclui com sucesso, o `deploy` fica **skipped** (o `if` só publica em `push`) e o PR recebe o comentário com a URL do canal de preview (`https://lista-compras-34f93--pr-<n>-<hash>.web.app`).

- [ ] **Step 6: Validar o preview**

Abrir a URL do preview do PR e repetir os passos 2–4 do smoke da Task 2 (shell, `crossOriginIsolated === true`, login, criar lista).
Expected: app funcional no canal de preview (aponta para o Supabase de produção — decido e registrado no spec §3).

- [ ] **Step 7: Merge e validar a publicação automática**

1. Merge do PR na `main` (com `flutter`/`supabase` verdes).
2. Na aba Actions, o job `deploy` roda e conclui com sucesso.
3. Conferir:
```bash
firebase hosting:channel:list --project lista-compras-34f93
curl.exe -sI https://lista-compras-34f93.web.app/ | Select-String -Pattern "HTTP|cross-origin"
```
Expected: canal `live` presente e a URL pública respondendo `200` com os headers de isolamento — publicada **pelo CI**, não pela máquina do dev.

- [ ] **Step 8: Exercitar o rollback**

1. Console do Firebase → Hosting → histórico de releases → escolher a release anterior → **Rollback**.
2. Confirmar que a URL voltou ao estado anterior (ex.: `/version.json` com a versão antiga) e então republicar o estado atual:
```bash
git commit --allow-empty -m "F19-T03: republica o estado atual apos teste de rollback"
git push
```
Expected: rollback aplicado em segundos e o deploy seguinte volta à versão correta — procedimento registrado no Step 9.

- [ ] **Step 9: Atualizar os docs donos**

Em `docs/07-qualidade-ci.md` §3, trocar o bloco de diagrama por um que inclua os jobs novos e acrescentar as notas; no §3 (após a nota dos builds de plataforma) inserir:
```markdown
* **Publicação Web (F19-T03, ADR-013):** os jobs `deploy` (push em `main`, `needs: [flutter, supabase]`, `channelId: live`) e `preview` (PR do próprio repositório, canal de preview com `expires: 7d`) montam o web com `--dart-define` vindos dos secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY` e publicam com `FirebaseExtended/action-hosting-deploy@v0` (`projectId: lista-compras-34f93`, `firebaseToolsVersion: 15.29.0`). PRs de fork não publicam (sem acesso a secrets). Publicar **não** é check obrigatório de branch protection: a barreira continua `flutter` e `supabase`.
```
Em `docs/09-runbook-operacoes.md` §4, substituir a seção **Web:** por:
```markdown
**Web (F19, ADR-013):**
1. Merge do hotfix na `main` → o job `deploy` do CI publica sozinho (build com defines de produção).
2. Deploy manual (emergência, sem passar pelo CI): `flutter build web --release --dart-define-from-file=dart_defines_prod.json && firebase deploy --only hosting`.
3. **Rollback:** Console do Firebase → Hosting → histórico de releases → *Rollback* (segundos); ou `git revert <commit>` na `main` (republica o estado anterior com rastro no Git).
4. **Desligar o site (emergência):** `firebase hosting:disable`.
5. Canais de preview dos PRs: `firebase hosting:channel:list` (expiram em 7 dias).
```
E, no §2.6, acrescentar ao final da entrada da Fase 19:
```markdown
  - F19-T03: deploy automatizado no CI (jobs `deploy`/`preview`), secrets no GitHub e rollback exercitado.
```

- [ ] **Step 10: Commitar os docs**

```bash
dart format . ; flutter analyze ; flutter test
git add docs/07-qualidade-ci.md docs/09-runbook-operacoes.md
git commit -m "F19-T03: CI e runbook da publicacao web (deploy, preview e rollback)"
```

---

### Task 4 (F19-T04): Política no app e fechamento

**Files:**
- Modify: `pubspec.yaml`, `lib/core/config/links.dart`, `lib/core/l10n/app_strings.dart`, `lib/features/configuracoes/ui/configuracoes_screen.dart`, `lib/features/auth/ui/registro_screen.dart`, `docs/06-mvp-entregas.md`, `docs/14-tarefas.md`
- Create: `lib/core/utils/abrir_url_externa.dart`
- Test: `test/core/config/links_test.dart`, `test/features/configuracoes/configuracoes_screen_test.dart`, `test/features/auth/registro_screen_test.dart`

**Interfaces:**
- Consumes: URL pública e página `/privacidade` (Task 1); `politicaPrivacidadeTexto` (existente).
- Produces: `const politicaPrivacidadeUrl` e `final abrirUrlExternaProvider` — o padrão de "abrir URL externa" para telas futuras.

- [ ] **Step 1: Promover `url_launcher` a dependência direta**

Em `pubspec.yaml`, na lista de `dependencies` (junto de `share_plus`), adicionar:
```yaml
  url_launcher: ^6.3.0
```
```bash
flutter pub get
```
Expected: `pubspec.lock` marca `url_launcher` como `"direct main"` com a mesma versão resolvida (6.3.2) — nenhum pacote novo é baixado.

- [ ] **Step 2: Escrever o teste do helper de URL (deve falhar)**

Adicionar em `test/core/config/links_test.dart` (criar o arquivo se não existir, importando também o helper):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/links.dart';
import 'package:lista_compras/core/utils/abrir_url_externa.dart';

void main() {
  test('deve_apontar_para_a_pagina_publica_quando_pedir_a_politica', () {
    expect(politicaPrivacidadeUrl, 'https://lista-compras-34f93.web.app/privacidade');
  });

  test('deve_permitir_injetar_o_abridor_de_url_nos_testes', () {
    Future<bool> Function(String) fake = (_) async => true;
    expect(fake(politicaPrivacidadeUrl), completion(isTrue));
  });
}
```
> Se `test/core/config/links_test.dart` já existir (F18-T02), preservar os testes atuais e apenas acrescentar estes dois.

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/core/config/links_test.dart`
Expected: FAIL — `politicaPrivacidadeUrl não é definido` / `abrir_url_externa.dart` não encontrado.

- [ ] **Step 4: Criar `lib/core/utils/abrir_url_externa.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre uma URL no navegador do sistema (doc 06 §3.3.2 — política pública).
Future<bool> abrirUrlExterna(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Injetável nos testes, como os repositórios em `providers`.
final abrirUrlExternaProvider = Provider<Future<bool> Function(String)>(
  (ref) => abrirUrlExterna,
);
```

- [ ] **Step 5: Adicionar a URL pública em `lib/core/config/links.dart`**

No fim do arquivo:
```dart
/// Página pública da Política de Privacidade (doc 06 §3.3.2, Fase 19).
const politicaPrivacidadeUrl =
    'https://lista-compras-34f93.web.app/privacidade';
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/core/config/links_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 7: Escrever o teste do sheet de Configurações (deve falhar)**

Acrescentar em `test/features/configuracoes/configuracoes_screen_test.dart`:
```dart
  testWidgets('deve_abrir_a_politica_online_quando_tocar_em_ver_versao_online', (
    tester,
  ) async {
    final abertas = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
          abrirUrlExternaProvider.overrideWithValue((url) async {
            abertas.add(url);
            return true;
          }),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.politicaPrivacidade));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.verVersaoOnline));
    await tester.pumpAndSettle();

    expect(abertas, [politicaPrivacidadeUrl]);

    await tester.pumpWidget(const SizedBox.shrink());
  });
```
(Importar `package:lista_compras/core/config/links.dart` e `package:lista_compras/core/utils/abrir_url_externa.dart` no topo do teste.)

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: FAIL — `verVersaoOnline` não definido / botão não encontrado.

- [ ] **Step 8: Adicionar as strings**

Em `lib/core/l10n/app_strings.dart`, na seção de Configurações (após `politicaPrivacidade`):
```dart
  static const verVersaoOnline = 'Ver versão online';
```
Na seção do cadastro (junto de `liPoliticaPrivacidade`, L39):
```dart
  static const liPoliticaAntes = 'Li a ';
```

- [ ] **Step 9: Implementar a ação no sheet de Configurações**

Em `lib/features/configuracoes/ui/configuracoes_screen.dart`, trocar o método `_abrirPolitica` por:
```dart
  void _abrirPolitica(BuildContext context, WidgetRef ref) {
    AppSheet.mostrar<void>(
      context,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(politicaPrivacidadeTexto),
            const SizedBox(height: AppSpacing.lg),
            AppBotao(
              rotulo: AppStrings.verVersaoOnline,
              variante: AppBotaoVariante.tonal,
              onPressed: () =>
                  ref.read(abrirUrlExternaProvider)(politicaPrivacidadeUrl),
            ),
          ],
        ),
      ),
    );
  }
```
E a chamada do `ListTile` (L120) passa a ser `onTap: () => _abrirPolitica(context, ref),`. Acrescentar os imports:
```dart
import '../../../core/config/links.dart';
import '../../../core/utils/abrir_url_externa.dart';
```

- [ ] **Step 10: Rodar e ver passar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: PASS — os 5 testes antigos + o novo. (O teste `deve_abrir_politica_privacidade_quando_tocar` continua verde porque o texto in-app permanece no sheet.)

- [ ] **Step 11: Escrever o teste do cadastro (deve falhar)**

Acrescentar em `test/features/auth/registro_screen_test.dart`:
```dart
  testWidgets('deve_abrir_a_politica_online_quando_tocar_no_rotulo', (
    tester,
  ) async {
    final abertas = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          abrirUrlExternaProvider.overrideWithValue((url) async {
            abertas.add(url);
            return true;
          }),
        ],
        child: const MaterialApp(home: RegistroScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapOnText(
      find.textRange.ofSubstring(AppStrings.politicaPrivacidade),
    );
    await tester.pumpAndSettle();

    expect(abertas, [politicaPrivacidadeUrl]);
  });
```
(Importar `package:lista_compras/core/config/links.dart` e `package:lista_compras/core/utils/abrir_url_externa.dart` no topo do teste; `find.textRange` e a sobrecarga `tapOnText` vêm do próprio `flutter_test`.)

Run: `flutter test test/features/auth/registro_screen_test.dart`
Expected: FAIL — o rótulo ainda é `Text` simples; o toque não abre nada e `abertas` fica vazio.

- [ ] **Step 12: Implementar o rótulo tappável no cadastro**

Em `lib/features/auth/ui/registro_screen.dart`, no estado (`_RegistroScreenState`), adicionar o recognizer e descartá-lo:
```dart
  late final TapGestureRecognizer _toquePolitica = TapGestureRecognizer()
    ..onTap = () =>
        ref.read(abrirUrlExternaProvider)(politicaPrivacidadeUrl);

  @override
  void dispose() {
    _toquePolitica.dispose();
    super.dispose();
  }
```
E o `CheckboxListTile` do aceite passa a usar texto rico (mantendo o comportamento atual: tocar no checkbox marca):
```dart
                  CheckboxListTile(
                    value: _aceitouPolitica,
                    onChanged: (v) =>
                        setState(() => _aceitouPolitica = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text.rich(
                      TextSpan(
                        text: AppStrings.liPoliticaAntes,
                        children: [
                          TextSpan(
                            text: AppStrings.politicaPrivacidade,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _toquePolitica,
                          ),
                        ],
                      ),
                    ),
                  ),
```
Imports novos: `package:flutter/gestures.dart`, `../../../core/config/links.dart`, `../../../core/utils/abrir_url_externa.dart`.
> Se `dispose` já existir no estado, apenas acrescentar a linha `_toquePolitica.dispose();` nele.

- [ ] **Step 13: Rodar e ver passar**

Run: `flutter test test/features/auth/registro_screen_test.dart`
Expected: PASS — testes antigos (incluindo `deve_exibir_erro_politica_quando_nao_aceitar`) + o novo.

- [ ] **Step 14: Suíte completa, formatação e análise**

```bash
dart format .
flutter analyze
flutter test
```
Expected: tudo verde (nenhum aviso novo de lint).

- [ ] **Step 15: Fechamento dos docs**

Em `docs/06-mvp-entregas.md` §1, marcar o item do web:
```markdown
- [x] Publicado: **Web acessível por URL pública** (`https://lista-compras-34f93.web.app`, Fase 19 — ADR-013). *(RF-16)*
```
(Manter o item da Play desmarcado.) No §3.3.2, registrar o link in-app:
```markdown
* **No app:** o sheet de Configurações exibe o texto e o botão "Ver versão online", e o rótulo do aceite no cadastro abre a mesma URL (F19-T04).
```
Em `README.md`, adicionar após o bullet de Segurança:
```markdown
- **Web publicado**: [`https://lista-compras-34f93.web.app`](https://lista-compras-34f93.web.app) (Firebase Hosting, Fase 19 — ADR-013)
```
Em `planejamento_lista_compras.md`: no item final da lista de roadmap (hoje item 10, "Suporte a Web e Desktop"), acrescentar o item 11:
```markdown
11. **Publicação Web** (Firebase Hosting com deploy no CI, política de privacidade online e Supabase Auth na URL pública - Fase 19/ADR-013, spec em `docs/superpowers/specs/2026-09-17-publicacao-web-design.md`).
```
E, na tabela de decisões (linha `| MVP = Android/iOS/Web; **Desktop suportado (Fase 18)** e Web completo | ADR-001 / ADR-012 |`), trocar por:
```markdown
| MVP = Android/iOS/Web; **Desktop suportado (Fase 18)**, Web completo e **Web publicado na Fase 19** | ADR-001 / ADR-012 / ADR-013 |
```
Em `docs/14-tarefas.md`, marcar `- [x]` em **F19-T00…F19-T04** e atualizar a tabela de progresso: `| F19 Publicação Web | 5 | 5 |` e `| **Total** | **113** | **111** |`.

- [ ] **Step 16: Commit final**

```bash
git add pubspec.yaml pubspec.lock lib test docs/06-mvp-entregas.md docs/14-tarefas.md README.md planejamento_lista_compras.md
git commit -m "F19-T04: politica de privacidade online no app; Fase 19 concluida"
```

---

## Verificação final (critério de pronto do spec §9)

- [ ] `https://lista-compras-34f93.web.app` responde 200 com HTTPS, COOP/COEP e `crossOriginIsolated === true`.
- [ ] Rewrite da SPA (`/listas`, `/entrar?token=…`), `/privacidade` e `/robots.txt` servidos corretamente.
- [ ] Smoke funcional completo na URL pública (Task 2, Steps 2–3).
- [ ] Deploy automático na `main` e canal de preview em PR funcionando; rollback exercitado (Task 3).
- [ ] `dart format` + `flutter analyze` + `flutter test` verdes; CI verde.
- [ ] Docs donos sincronizados (00, 06, 07, 09, 12, 13, 14) e Fase 19 marcada em `docs/14`.
- [ ] F5-T05/T06 permanecem **desmarcadas** em `docs/14` (gate do dono preservado).
