# Spec — Publicação Web (Fase 19)

> Navegação: [← 00 Visão geral](../../00-visao-geral.md) · [06 Entregas](../../06-mvp-entregas.md) · [07 Qualidade/CI](../../07-qualidade-ci.md) · [09 Runbook](../../09-runbook-operacoes.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-17 · Status: aprovada

## 1. Objetivo

Publicar o app web em **URL pública com HTTPS** (Firebase Hosting), com **deploy automatizado pelo CI**, **política de privacidade online** e o **Supabase Auth configurado para a URL de produção** — de modo que um usuário externo consiga se cadastrar, verificar o e-mail, criar/usar listas, importar por texto e aceitar convite pelo navegador.

Escopo: **somente Web**. A publicação na Play, os testes de usabilidade (F5-T05) e a política de privacidade como requisito de loja continuam **adiados no gate do dono** (F5-T05/T06) — esta fase **não** os antecipa nem os desbloqueia.

Fase nova: **F19 — Publicação Web**. Decisão de arquitetura: **ADR-013** no [00](../../00-visao-geral.md).

## 2. Contexto

- O app web **já é funcional completo** desde a Fase 18 ([ADR-012](../../00-visao-geral.md)): banco Drift/WASM (OPFS com fallback IndexedDB), auth e convites por URL https, sync e import local. Falta apenas hospedar.
- **Projeto Firebase já existe:** `lista-compras-34f93` (mesmo do App Distribution da F5-T05b, app Android "Lista de Compras"). O site de Hosting também já existe: `https://lista-compras-34f93.web.app`. O site `lista-compras` **não** existe no projeto (nome mais curto: `lista-compras.web.app` — tentar criar; se estiver ocupado por outro projeto, publicar no site atual).
- `firebase-tools 15.29.0` instalado e autenticado na máquina do dev.
- **Nada no código precisa mudar por causa do domínio:** `lib/core/config/links.dart` monta as URLs de auth (`<origem>/login-callback`) e de convite (`<origem>/entrar?token=`) a partir de `Uri.base.origin` em runtime.
- **O banco web exige cross-origin isolation:** `lib/drift/conexao/conexao_web.dart:8` usa `WasmDatabase.open`, que prefere OPFS (`SharedArrayBuffer`) e cai para IndexedDB quando a página não é isolada. Logo a hospedagem precisa enviar `Cross-Origin-Opener-Policy` + `Cross-Origin-Embedder-Policy`.
- `dart_defines_prod.json` existe localmente com `SUPABASE_URL`/`SUPABASE_ANON_KEY` e é **gitignored** (F5-T05b); os mesmos valores entram no CI via secrets.
- `web/version.json` está fixo em `1.2.0+6` (bate com `pubspec.yaml` hoje, mas é manual e pode defasar).
- `web/manifest.json` existe (PWA instalável, F18-T04); `web/index.html` também.
- **Política de privacidade:** texto único em `lib/core/l10n/politica_privacidade.dart`, exibido in-app (sheet em Configurações e checkbox no cadastro). O doc [06 §3.3](../../06-mvp-entregas.md) exige também **página pública no site** — era F5-T06, entra nesta fase.
- **CI atual** ([07 §3](../../07-qualidade-ci.md)): jobs `flutter` (format/analyze/test/build web com defines fictícios), `supabase` (db reset + testes RLS) e `desktop` (builds Linux/Windows). Não há job de publicação.
- **R-01 (Supabase free tier):** a URL pública aumenta o uso; o upgrade para Pro segue com o gatilho de [00 §4](../../00-visao-geral.md) e a revisão de [06 §4](../../06-mvp-entregas.md), não sendo pré-requisito desta fase.

## 3. Decisões (2026-09-17)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Hospedagem | **Firebase Hosting** (ADR-013) | Mesmo projeto/console do App Distribution; CDN + SSL grátis; rewrites, headers por arquivo e histórico de releases nativos |
| URL pública | `https://lista-compras.web.app` se o site puder ser criado; senão `https://lista-compras-34f93.web.app` | Nome curto e legível; o fallback já existe e funciona igual |
| Domínio próprio | Fora de escopo (fica pós-MVP) | Decisão do dono: publicar já com o subdomínio grátis; migrar depois é trocar Site/Redirect URLs, o link da política e o deploy |
| Estrutura do site | Um único site de Hosting, servindo `build/web` | Sem staging separado; o canal de preview do CI cobre a validação por PR |
| URLs do app | **Path URL strategy** já vigente (F18-T02) + rewrite `**` → `/index.html` | Sem `#` nas URLs e sem 404 ao recarregar `/listas` ou `/entrar?token=` |
| Cross-origin isolation | Headers COOP `same-origin` + COEP `require-corp` em todas as respostas | Habilita OPFS/`SharedArrayBuffer` no Drift (performance e durabilidade); sem eles o app funciona, mas cai no IndexedDB |
| Cache | `no-cache` em `/index.html`, `/version.json` e `/flutter_service_worker.js` | Evita o clássico "service worker velho servindo build velho" após um deploy |
| Build de release | `flutter build web --release` com `--dart-define` vindos de **secrets do GitHub** | Nada de chave no repositório (regra do AGENTS) |
| `version.json` | **Gerado no job de deploy** a partir do `pubspec.yaml` + teste-guarda local | Elimina o passo manual e o risco de a versão publicada mentir |
| Gatilho do deploy | Push/merge em `main` publica sozinho (`channelId: live`), **após** `flutter` e `supabase` verdes; PR ganha canal de preview | Publicação contínua com a mesma barreira do merge; preview facilita revisar a UI real |
| Preview vs produção | Previews usam os **mesmos defines de produção** e o canal expira sozinho (7 dias) | Decisão consciente: o Supabase não tem ambiente de staging; risco aceito é o de criar contas de teste no banco de produção a partir de um PR |
| Indexação | `robots.txt` com `Disallow: /` até a F5-T05/lançamento | URL acessível por link, fora do Google enquanto a usabilidade não foi validada |
| Política pública | Página **estática** `web/privacidade.html` em `/privacidade`, sem JS | Legível por qualquer um (revisores de loja, navegador sem JS); arquivo estático tem precedência sobre o rewrite da SPA |
| Paridade do texto | Teste-guarda comparando a página pública com `politicaPrivacidadeTexto` | Impede que app e web divirjam em silêncio |
| Contato na política | Item 6 permanece **genérico** ("canal informado na página do aplicativo") | Decisão do dono em 2026-09-17; o contato do encarregado fica registrado como pendência de lançamento em [06 §4](../../06-mvp-entregas.md) |
| Source maps do Sentry | Fora de escopo (pós-MVP) | YAGNI: o gate de publicação é o Web funcionando; stack trace minificado basta por ora |
| Onde entra o link | Sheet de Configurações ganha ação "ver versão online"; o rótulo do checkbox no cadastro abre a URL | Atende [06 §3.3](../../06-mvp-entregas.md) ("link no cadastro e nas configurações") sem duplicar texto in-app |

## 4. Comportamento

### 4.1 Configuração de hosting (versionada no repo)

- `firebase.json`:
  - `"public": "build/web"` (o `--dart-define-from-file`/secrets alimenta o build antes do deploy);
  - `"cleanUrls": true`;
  - `"rewrites": [{ "source": "**", "destination": "/index.html" }]` (a SPA resolve as rotas);
  - `"headers"`: COOP/COEP globais + `Cache-Control: no-cache` para os três arquivos sensíveis do PWA;
  - `"ignore"` padrão (`firebase.json`, `**/.*`, `**/node_modules/**`).
- `.firebaserc`: projeto `default` = `lista-compras-34f93`.
- `web/robots.txt`: `User-agent: *` + `Disallow: /` (comentário de uma linha apontando a F5-T05).
- `web/privacidade.html`: página estática, mesma estrutura numerada do texto do app (1–6), com `<title>` e `meta description`; o item 6 sai exatamente como no app.
- Headers, por regra:

| `source` | Headers |
| :--- | :--- |
| `**` | `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` |
| `/index.html` | `Cache-Control: no-cache` |
| `/version.json` | `Cache-Control: no-cache` |
| `/flutter_service_worker.js` | `Cache-Control: no-cache` |

`/privacidade` é servido pelo arquivo estático (`cleanUrls`), sem passar pelo rewrite.

### 4.2 Build e deploy

- Build de release: `flutter build web --release --dart-define=SUPABASE_URL=<secret> --dart-define=SUPABASE_ANON_KEY=<secret>`.
- Deploy: `firebase deploy --only hosting --project lista-compras-34f93` (ou a action no CI, §4.3).
- `web/version.json` é reescrito a partir de `pubspec.yaml` (`version: 1.2.0+6` → `{"app_name":…,"version":"1.2.0","build_number":"6",…}`) antes do build; o arquivo versionado continua sendo a referência local e um teste-guarda garante que os dois batem.
- `build/` segue gitignored — nada de artefato no repositório.

### 4.3 CI/CD

- Novos **secrets do repositório**: `FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93` (JSON da conta de serviço com papel *Firebase Hosting Admin*), `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Job `deploy` no mesmo workflow do CI, `needs: [flutter, supabase]` (publica só com a barreira verde):
  - **sem PR** (push em `main`): `channelId: live` → publica na URL pública;
  - **em PR**: canal de preview via `FirebaseExtended/action-hosting-deploy` (comenta a URL do preview no PR, expira em 7 dias);
  - permissões mínimas: `contents: read` + `pull-requests: write`; `concurrency` para não sobrepor deploys.
- O job de deploy **não** faz parte dos checks obrigatórios de branch protection (a exigência continua `flutter` e `supabase`).
- Custo: plano Spark (grátis) cobre o uso esperado.

### 4.4 Supabase Auth

- Dashboard → Authentication → URL Configuration ([09 §2.7](../../09-runbook-operacoes.md)):
  - **Site URL:** `https://<site-publicado>` (o do §3);
  - **Redirect URLs:** manter `http://localhost:<porta>/**`, o scheme nativo `br.com.oliverlucas.listacompras://login-callback` e **acrescentar** `https://<site-publicado>/**`.
- Sem isso, o `redirectTo` do cadastro/recuperação é recusado ("redirect_uri not allowed") e o convite por link cai na Site URL errada (09 §2.7).

### 4.5 Política de privacidade

- A página pública replica o texto de `lib/core/l10n/politica_privacidade.dart` **sem** reescrever conteúdo.
- No app: ação "Ver versão online" no sheet de Configurações (abre a URL no navegador) e o rótulo do checkbox do cadastro passa a abrir a mesma URL; o texto in-app continua existindo.
- A URL pública entra como constante única (`lib/core/config/links.dart`), usada pelos dois pontos da UI.

### 4.6 Operação (rollback e hotfix)

- [09 §4](../../09-runbook-operacoes.md) passa a documentar o web de verdade: `firebase hosting:channel:list`/`hosting:releases:list` para inspecionar, `firebase hosting:rollback` (ou redeploy do commit anterior) para reverter em segundos, e o caminho de hotfix (`hotfix/...` → CI verde → merge em `main` → deploy automático).
- [09 §2.6](../../09-runbook-operacoes.md) ganha a entrada de histórico da publicação (data, site, commit).

### 4.7 Visibilidade

- `robots.txt` bloqueia indexação; sem cookies de marketing, sem banner de consentimento ([06 §3.4](../../06-mvp-entregas.md)).
- A URL é divulgada por link (ninguém a descobre por busca) até a F5-T05 aprovar a usabilidade e a F5-T06 abrir o lançamento.

## 5. Arquivos

**Criar**
- `firebase.json`, `.firebaserc`
- `web/robots.txt`, `web/privacidade.html`
- `test/core/l10n/politica_privacidade_publica_test.dart` (paridade app × página)
- `test/core/config/version_json_test.dart` (paridade `pubspec.yaml` × `web/version.json`)

**Modificar**
- `.github/workflows/ci.yml` (job `deploy` + geração do `version.json`)
- `lib/core/config/links.dart` (URL pública da política)
- `lib/features/configuracoes/ui/configuracoes_screen.dart` (ação "ver versão online")
- `lib/features/auth/ui/registro_screen.dart` (rótulo do checkbox abre a URL)
- `lib/core/l10n/app_strings.dart` (rótulo da ação/nova string)
- `.gitignore` (se algum artefato local do Firebase precisar de guarda)

**Docs**
- `00` (ADR-013, Fase 19 no cronograma), `06` (§1 com o item de publicação dividido em web/Android, §3.3 contato pendente, correção da numeração duplicada — "Política de privacidade" passa a 3.3.2, sem renumerar 3.4 —, §4 nota do gate e do web publicado), `07` (§3: job de deploy, secrets e build com defines reais), `09` (§2.6 histórico, §2.7 URLs de produção, §4 hotfix/rollback do hosting), `12`/`13` (menção de publicação web), `14` (Fase 19 + progresso), `planejamento_lista_compras.md`

## 6. Testes

- **Testes-guarda (VM):** paridade do texto da política com a página pública — o teste normaliza o HTML (remove tags, colapsa espaços em branco) e compara **parágrafo a parágrafo** com `politicaPrivacidadeTexto`, falhando com o trecho divergente; e paridade do `version.json` com o `pubspec.yaml` (versão e build number). Ambos falham o CI quando alguém edita só um lado.
- **Suíte existente:** intacta; os dois widget tests que tocam a política (Configurações e cadastro) são ajustados ao novo comportamento de abrir a URL.
- **Configuração validada por comando (manual, no CP):** `curl -sI https://<site>/` confere COOP/COEP e `no-cache`; no console do navegador, `crossOriginIsolated === true`; `/privacidade` e `/robots.txt` respondem 200 sem JS; recarregar `/listas` e `/entrar?token=…` não dá 404 (rewrite).
- **Smoke funcional na URL pública:** cadastro → verificação por e-mail → login; criar lista, adicionar/marcar/editar/remover item; import por texto; recarregar a página e manter sessão/dados (OPFS); convite gerado no app e aberto em outro navegador; offline no DevTools → escrita → reconectar → sync.
- **CI:** `flutter build web` continua sem segredos nos jobs existentes; o job de deploy usa os secrets reais e só publica com `flutter`/`supabase` verdes.

## 7. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **00** | **ADR-013** (Firebase Hosting como canal de publicação web); Fase 19 no cronograma/escopo |
| **06** | §1: item "Publicado" desdobrado (web x Android) com o web marcado; §3.3 nota do contato genérico; §4 hospedagem do web definida e gate do dono preservado |
| **07** | §3: job `deploy`, secrets, geração do `version.json`, preview por PR |
| **09** | §2.6/§2.7/§4: histórico da publicação, URLs de produção do Auth, deploy/rollback/hotfix do web |
| **12/13** | Menção de publicação web (sem novos requisitos) |
| **14** | Fase 19 (F19-T00…T04) + tabela de progresso |
| **README/planejamento** | Links e menção da URL pública |

## 8. Fora de escopo

- F5-T05 (usabilidade) e F5-T06 (Play Console, AAB, declaração de dados) — continuam no gate do dono.
- Domínio próprio e migração de URL (tarefa futura, se e quando o dono quiser).
- Publicação de builds desktop; universal links; e-mail transacional de convite; iOS.
- Source maps do Sentry no web; analytics; banner de cookies.
- Upgrade do Supabase para Pro (R-01, gatilho próprio) e ambiente de staging separado.

## 9. Critério de pronto

- `https://<site-publicado>` responde 200 servindo o app, com HTTPS, COOP/COEP e `crossOriginIsolated === true` no console.
- Rewrite de SPA funcionando (`/listas` e `/entrar?token=…` sobrevivem ao recarregar) e `/privacidade` + `/robots.txt` servidos como estáticos.
- Smoke funcional completo na URL pública (cadastro/verificação, login, CRUD, import, convite, sync, persistência OPFS).
- Deploy automático em `main` (após CI verde) e canal de preview em PR; rollback exercitado pelo menos uma vez.
- `dart format` + `flutter analyze` + `flutter test` verdes; CI verde.
- Docs donos sincronizados; Fase 19 marcada em `docs/14`; tabela de progresso atualizada.

## 10. Operacional (requer o dono)

- Criar a **conta de serviço** no console do Firebase (Configurações do projeto → Contas de serviço → gerar chave privada), com papel *Firebase Hosting Admin*, e cadastrá-la como secret `FIREBASE_SERVICE_ACCOUNT_LISTA_COMPRAS_34F93` no GitHub; cadastrar também `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
- Confirmar/executar a configuração do **Supabase Auth** (§4.4) no dashboard.
- Tentar criar o site `lista-compras` (`firebase hosting:sites:create`) e confirmar qual URL vale; se o nome estiver ocupado, seguir com `lista-compras-34f93.web.app`.
- Rodar `supabase db push --dry-run` — esta fase **não** aplica migration alguma (é só distribuição), então o esperado é diff vazio.

## 11. Breakdown proposto (Fase 19)

- [ ] **F19-T00** — Spec + planejamento: ADR-013 no `00`, Fase 19 no `14`, item de publicação do `06 §1` desdobrado, menções em `12/13` — sem tocar código.
- [ ] **F19-T01** — Artefatos de hosting: `firebase.json`, `.firebaserc`, `web/robots.txt`, `web/privacidade.html`, testes-guarda de paridade; primeiro deploy manual e URL pública com headers, rewrite e página estática.
- [ ] **F19-T02** — Supabase Auth (Site URL/Redirect URLs) + smoke funcional completo na URL pública; `09 §2.6/§2.7`.
- [ ] **F19-T03** — CI/CD: secrets, job `deploy` (preview em PR, `live` em `main`), geração do `version.json`, rollback documentado; `07 §3` e `09 §4`.
- [ ] **F19-T04** — Política no app (link "ver versão online" e no cadastro) + docs donos e fechamento (progresso no `14`, critério de pronto de §9).
