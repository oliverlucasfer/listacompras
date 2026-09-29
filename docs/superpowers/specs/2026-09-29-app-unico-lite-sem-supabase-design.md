# Fase 48 — App único "Minhas Listas" (Lite), remoção do Supabase (design)

> **Status:** aprovado em 29/09/2026 (decisões na Seção 13)
> **Fase:** 48 · **Requisito:** RF-31 passa a ser o **único** requisito de app (o Lite deixa de ser "modo" e vira o produto)
> **Docs donos:** [05](../05-app-flutter.md) (app/rotas), [06](../06-mvp-entregas.md) (LGPD/publicação), [07](../07-qualidade-ci.md) (CI), [09](../09-runbook-operacoes.md) (build/distribuição), [12](../12-prd.md) (requisitos), [14](../14-tarefas.md) (tarefas), [00](../00-visao-geral.md)/[13](../13-premodelo-tecnico.md) (visão/resumo), [10](../10-wireframes-telas.md)/[11](../11-usabilidade-fase5.md)/[15](../15-design-system.md)/[16](../16-roadmap-pos-mvp.md); docs `01`/`02`/`03`/`08` deixam de existir.
> **Origem:** pedido do dono (29/09/2026): "quero remover toda a parte do supabase e deixar apenas o app 'lite'".
> **Relação com fases anteriores:** reverte a decisão de **convivência** da F41 (spec [2026-09-24-flavor-lite-sem-conta-design.md](2026-09-24-flavor-lite-sem-conta-design.md) §8.1/§8.2) e conclui o "Lite 100% local de verdade" da F47 (spec [2026-09-29-publicacao-lite-play-design.md](2026-09-29-publicacao-lite-play-design.md) §3), agora **sem** o app colaborativo.

---

## 1. Motivação

O app nasceu colaborativo (Supabase: auth, sync, Realtime, convites, push) e ganhou, na F41, um flavor `lite` 100% local que **convivia** com ele. O dono decidiu que o produto final é **apenas o Lite** ("Minhas Listas"), publicado na Play: um app local, sem conta, sem nuvem e sem colaboração.

Manter o app colaborativo tem custo real: dependências (Supabase, Firebase, `app_links`, `connectivity_plus`, `http`, Sentry), um backend inteiro (`supabase/`: 26 migrations, Edge Function, testes RLS/Realtime), duas suítes de teste, dois flavors/entrypoints, uma costura de capacidades (`AppModo`/`AppCapacidades`) espalhada pela UI e uma documentação dona de backend (`01`/`02`/`03`/`08`). Com a decisão de ser Lite-only, é tudo **peso morto** — o corte de dependências, antes adiado pela F47 (§2), passa a ser o objetivo.

A base local já está pronta: o Drift é a fonte da verdade e as features de listas/itens/categorias/mercado/preços/backup já funcionam sem rede. A remoção é, portanto, **deletar a camada de nuvem e colapsar a costura**, não reescrever o app.

## 2. Escopo

**Dentro:**
- Remover **todo** o código de nuvem/colaboração do app: auth, sync/outbox, convites/membros/compartilhamento, notificações/push.
- Remover a costura de modos: `AppModo`, `AppCapacidades`, `capacidadesProvider`, `compatibilidade_modo_pacote`, flavors, entrypoint duplo e trava flavor×modo.
- Remover dependências órfãs do `pubspec`: `supabase_flutter`, `firebase_core`, `firebase_messaging`, `app_links`, `http`, `connectivity_plus`, `sentry_flutter`.
- Apagar o backend `supabase/` inteiro e o workflow `backup.yml` (dump do banco) e o job `supabase` do CI.
- App único com identidade **Lite**: pacote `br.com.oliverlucas.listacompras.lite`, nome "Minhas Listas".
- Manter **Web** (agora o Lite), iOS/desktop, backup JSON local, voz, importação por texto, tour e design system.
- Migration Drift: **dropar `mutacao_pendente`**.
- Atualizar/remover docs donos, `AGENTS.md` e `planejamento_lista_compras.md`.

**Fora:**
- Migrar dados de contas `prod` (nuvem) para o aparelho — dados de conta ficam para trás.
- Publicação em loja (gate **F5-T06**), salvo o que já existe da F47.
- Alterar o formato do backup JSON, o parser de importação por texto ou o reconhecimento de voz.
- Suporte a múltiplos usuários/perfis no aparelho.
- Reescrever a camada local (Drift/repositórios permanecem como estão, exceto a remoção do outbox).

## 3. Arquitetura alvo

**Antes:** `main.dart` (colaborativo) e `main_lite.dart` (lite) → `bootstrap(AppModo)` → `AppCapacidades` sobrescrito no container → UI/rotas decidem por capacidades; Supabase/Firebase inicializados por capacidade.

**Depois:** um único `main.dart` → `bootstrap()` sem modo. Não há capacidades: a UI é sempre local.

| Peça | Antes | Depois |
| :--- | :--- | :--- |
| Entrypoints | `main.dart` + `main_lite.dart` | só `main.dart` |
| `bootstrap` | `bootstrap(AppModo)`, inicializa Supabase/Firebase/Sentry, sobrescreve sessão | `bootstrap()` sem modo; sem Supabase/Firebase/Sentry |
| Modos | `AppModo`, `AppCapacidades`, `capacidadesProvider`, `compatibilidade_modo_pacote`, `tela_build_incorreto` | **removidos** |
| Sessão | `AuthRepository` (Supabase ou local) | constante `idLocal = 'local'`; `features/auth/` removida |
| Sync | `SyncEngine`/`OutboxMutacoes`/`sync_status`/`IndicadorSync` | **removidos** |
| Colaboração | `features/convites/`, `CompartilhadasScreen`, rota `/membros`, deep link | **removidos** |
| Push | `features/notificacoes/`, `push_navegacao`, FCM | **removidos** |
| Identidade | derivada de `cap.nuvem` | fixa `IdentidadeVisual.lite` (índigo, "Minhas Listas", `logo_lite.png`) |

**Rotas finais:** `/` → `/listas`; `/listas`, `/configuracoes` (abas), `/lista/:listaId`, `/mercado/:listaId`, `/boas-vindas`, `/categorias`, `/design` (debug). Sem `/login`, `/registro`, `/recuperar-senha`, `/redefinir-senha`, `/login-callback`, `/entrar`, `/compartilhadas`, `/membros/:listaId`. Sem `redirect` global e sem `RouterRefreshStream`.

## 4. Inventário de remoção e permanência

### 4.1 Remover (código)
- **Entry/bootstrap:** `lib/main_lite.dart`; `lib/bootstrap.dart` reescrito; `lib/router.dart` com tabela única.
- **Config/modos:** `core/config/app_modo.dart`, `core/config/compatibilidade_modo_pacote.dart`, `core/config/supabase_config.dart`, `core/config/links.dart`.
- **Auth:** `lib/features/auth/` inteiro; `core/utils/router_refresh_stream.dart`.
- **Convites/colaboração:** `lib/features/convites/` inteiro; `core/utils/deeplink_convite.dart`; `features/listas/ui/compartilhadas_screen.dart`.
- **Notificações/push:** `lib/features/notificacoes/` inteiro.
- **Sync/outbox:** `lib/features/sync/` inteiro (inclui `features/sync/data/outbox_mutacoes.dart`); `drift/tables/mutacao_pendente.dart`.
- **Rede/observabilidade:** `core/rede/` inteiro; `core/observabilidade/` inteiro (Sentry).
- **Widgets/UI:** `core/widgets/tela_build_incorreto.dart`; trechos de conta/push/sync/colaboração em `configuracoes_screen.dart`, `app_shell.dart`, `app.dart`, `painel_listas.dart`, `tela_lista_screen.dart`, `mercado_screen.dart`, `boas_vindas_screen.dart`, `tour_step.dart`, `tour_controller.dart`, `app_politica_privacidade.dart`.
- **Strings:** em `core/l10n/app_strings.dart`, remover as de conta/login/senha/convite/compartilhamento/sync/push e as variantes colaborativas; manter/renomear as do Lite.

### 4.2 Manter
Listas/itens/histórico de preços, categorias e sugestão, mercado, ordem de categorias, duplicar, arquivar, busca, importação por texto (parser local), voz, boas-vindas/onboarding, tour, tema, design system, **backup JSON local**, política de privacidade (versão Lite), Configurações (aparência, categorias, sobre, tour, backup), Drift local e conexões nativa/web.

### 4.3 Dependências
- **Remover do `pubspec`:** `supabase_flutter`, `firebase_core`, `firebase_messaging`, `app_links`, `http`, `connectivity_plus`, `sentry_flutter`.
- **Permanecer:** `flutter_riverpod`, `go_router`, `drift`, `uuid`, `path_provider`, `path`, `sqlite3`, `shared_preferences`, `package_info_plus`, `share_plus`, `speech_to_text`, `file_selector`, `flutter_launcher_icons`, `flutter_native_splash`.

## 5. Sessão, dono e dados

- **Sessão/identidade:** não há conta. O dono de toda lista é a constante `'local'`. `donoAtualIdProvider` e equivalentes são substituídos por `idLocal`; `emailUsuarioProvider` deixa de existir.
- **Sem outbox:** `ListasRepository` perde o parâmetro `_enfileirarMutacoes`/`OutboxMutacoes`; escritas só no Drift.
- **Backup:** `BackupRepository(donoLocal: true, enfileirar: false)` fixo.
- **Drift — migration v10 → v11:** remover `MutacaoPendente` da lista de `@DriftDatabase`, apagar a tabela (`m.deleteTable('mutacao_pendente')`) e ajustar `_dedupItensAtivos` para não referenciar a fila (ordenação passa a ser só `updated_at DESC, rowid DESC`; sem `DELETE FROM mutacao_pendente`). Os passos históricos `de < 2 … de < 10` permanecem para quem vem de versões antigas. Regenerar `database.g.dart` (`build_runner`).

## 6. Observabilidade e privacidade

- **Sentry removido** (dependência, `sentry_config.dart`, `sentry_privacidade.dart` e seu uso no `bootstrap`). Coerente com o Lite "nada sai do aparelho" e com a política vigente do Lite.
- **Política de privacidade:** manter só a variante Lite (`politicaPrivacidadeTextoLite`), sem a função `politicaPrivacidadePara(AppCapacidades)`; atualizar `site/privacidade.html` para o mesmo texto.
- **`erro_rede`/`ErroConvite`:** removidos com os convites.

## 7. Build, identidade, CI e distribuição

### 7.1 Nativo Android (`android/app/build.gradle.kts`)
- Remover `flavorDimensions`/`productFlavors`, o plugin `com.google.gms.google-services` e `android/app/google-services.json`.
- Único `applicationId = "br.com.oliverlucas.listacompras.lite"`, `resValue app_name = "Minhas Listas"`.
- Source sets: remover `src/prod/AndroidManifest.xml`; consolidar o endurecimento da F47 (`allowBackup="false"`, `dataExtractionRules`, `tools:node="remove"`) em um manifest **release** único (ex.: `src/release/AndroidManifest.xml`); manter `RECORD_AUDIO` (voz).
- Assinatura: `key.properties`/upload key como hoje; fallback debug só para CI local.

### 7.2 Web/desktop/iOS
- Web passa a ser o Lite: `web/index.html` (título/descrição "Minhas Listas", sem "colaborativa") e `web/version.json` (`app_name: "Minhas Listas"`, `package_name` alinhado).
- Desktop: builds sem `--dart-define`.
- iOS: sem flavors; bundle id/nome alinhados à identidade Lite quando o iOS entrar na distribuição (segue adiado).

### 7.3 CI (`.github/workflows/`)
- **Apagar o job `supabase`** inteiro.
- **Apagar `backup.yml`** (dump do banco de produção).
- `pages.yml`: permanece (publica `site/`); conteúdo da política atualizado.
- `ci.yml`:
  - Web: `flutter build web --release` **sem** `--dart-define`.
  - Android: `flutter build apk --debug` e `flutter build appbundle --release` **sem** `--flavor`/`-t`.
  - Manifest: validar o manifest release único — falhar se `android.permission.INTERNET`, componentes Firebase/`c2dm` ou `FirebaseInitProvider` aparecerem; exigir `allowBackup="false"` e `RECORD_AUDIO`.
  - Desktop: build linux/windows sem `--dart-define`.

### 7.4 Repositório
- Apagar a pasta `supabase/` inteira e `dart_defines_prod.json`.

## 8. Documentação

- **Apagar:** `docs/01-banco-de-dados.md`, `docs/02-seguranca-rls.md`, `docs/03-sincronizacao-offline.md`, `docs/08-compartilhamento-colaborativo.md`.
- **Atualizar (dono + remoção das referências a nuvem):**
  - `00-visao-geral.md` — produto único local; remove backend/nuvem.
  - `05-app-flutter.md` — remove modos/rotas de conta; tabela de rotas única; remove sync/auth dos fluxos.
  - `06-mvp-entregas.md` — LGPD local (sem excluir conta/nuvem); publicação do Lite.
  - `07-qualidade-ci.md` — um único app; remove job Supabase/RLS/Realtime; remove Sentry (RF-12).
  - `09-runbook-operacoes.md` — builds sem flavor/defines; remove Supabase CLI, migrations, backup do banco e app Firebase.
  - `10-wireframes-telas.md` — remove telas de login/registro/senha/compartilhadas/membros/indicador de sync.
  - `11-usabilidade-fase5.md` — remove requisitos de online/sync/conta.
  - `12-prd.md` — RF-31 vira o app inteiro; remover RF-01, RF-07, RF-08, RF-09, RF-10 (LWW de sync), RF-11, RF-12, RF-13, RF-14, RF-30; reescrever RF-28/RF-29 sem "sincronizado"; ajustar matriz de rastreabilidade.
  - `13-premodelo-tecnico.md` — resumo técnico sem nuvem.
  - `14-tarefas.md` — nova Fase 48, marcar progresso; F41/F42/F47 viram histórico.
  - `15-design-system.md` — identidade única (Lite).
  - `16-roadmap-pos-mvp.md` — remove frentes de backend; atualiza onda do Lite.
- **Atualizar:** `AGENTS.md` (remove regras RLS/sync/compartilhamento e comandos `supabase`, remove exigência de doc `01/02/03/04/08` como donos; mantém enum de unidades, offline-first e CI verde) e `planejamento_lista_compras.md`.
- **Histórico:** specs/plans em `docs/superpowers/` permanecem como registro (não são reescritos).

## 9. Testes

- **Remover:** `test/features/auth/**`, `test/features/convites/**`, `test/features/sync/**`, `test/features/notificacoes/**`, `test/features/listas/compartilhadas_screen_test.dart`, `test/fluxos/fluxo_entrar_codigo_test.dart`, `test/bootstrap_lite_test.dart`, `test/router_lite_test.dart`, `test/core/config/app_modo_test.dart`, `test/core/config/compatibilidade_modo_pacote_test.dart`, `test/core/rede/**`, testes de conta/exclusão em `configuracoes`, testes de Sentry e a variante Supabase da política.
- **Atualizar:** `test/fluxos/**` (harness sem `SupabaseAuthRepository`), `test/features/listas/{tela_lista, mercado_screen, listas_repository, lite_ui, outbox_lite}` (sem colaboração/outbox), `test/features/backup/**` (dono/enfileirar fixos), `test/core/navigation/app_shell_test.dart` (2 abas), `test/widget_test.dart` (sem Supabase).
- **Adicionar/ajustar:**
  - App único abre em `/listas` e não expõe rotas de conta (`/login` etc. ausentes).
  - `ListasRepository`/backup não gravam `mutacao_pendente` e a tabela não existe após a migration.
  - Teste do manifest release único sem INTERNET/Firebase (script do CI).

## 10. Entrega em fases

Cada fase fecha com **CI verde** (formatação, analyze, testes, builds) e seu critério de pronto.

1. **Fase 48-A — Corte de recursos.** Remover auth, convites/colaboração, notificações/push, sync/outbox e Sentry; fixar sessão `'local'` e backup local; ajustar rotas/UI/strings; remover dependências órfãs do app.
2. **Fase 48-B — Corte da costura.** Remover `AppModo`/`AppCapacidades`/`capacidadesProvider`/`compatibilidade_modo_pacote`/flavors/entrypoint duplo/tela de build incorreto; `bootstrap()` único.
3. **Fase 48-C — Corte de infraestrutura.** Apagar `supabase/`, `backup.yml`, job `supabase` do CI, `dart_defines_prod.json`; ajustar `pubspec` final, Android (flavors/Firebase/google-services), web e site; atualizar docs donos e `AGENTS.md`.

## 11. Riscos e mitigações

| Risco | Mitigação |
| :--- | :--- |
| Remover auth/colaboração quebrar providers lidos antes da UI (ex.: papel da lista) | Remover o código de vez (não só esconder) e ajustar as telas; testes de widget cobrem |
| Migration Drift de quem já tem dados | `onUpgrade` aditivo: passos antigos preservados + `deleteTable('mutacao_pendente')`; testar upgrade v10→v11 |
| `dart format`/analyze pegarem imports órfãos | Rodar `dart format .` e `flutter analyze` por fase (exigência do CI) |
| Perda do histórico de erro (Sentry) | Decisão do dono; política Lite não prevê envio de dados |
| Manifest release ainda herdar permissões de plugins | CI valida o manifest mergeado (INTERNET/Firebase) |
| Docs donos ficarem inconsistentes | Atualizar dono no mesmo PR (regra do `AGENTS.md`) |

## 12. Fora de escopo (registro)
Migração de dados da nuvem; publicação em loja (gate F5-T06); mudar formato de backup/importação/voz; iOS na distribuição.

## 13. Decisões registradas (29/09/2026)

1. **Remoção total** (dono): apagar Supabase (backend + cliente) e ficar só com o Lite.
2. **Push/Firebase também saem** (dono) — a feature já não existia no Lite.
3. **Identidade do Lite** (dono): pacote `br.com.oliverlucas.listacompras.lite`, nome "Minhas Listas"; sem flavors.
4. **Manter Web como Lite** (dono).
5. **Limpar e atualizar docs** (dono): `01/02/03/08` saem; demais donos atualizados.
6. **Sentry removido** (dono) — coerente com o Lite local.
7. **Dropar `mutacao_pendente`** (dono) via migration Drift.
8. **Entrega faseada em 3 partes** (dono), com CI verde entre fases.

## 14. Documentos relacionados
- [2026-09-24-flavor-lite-sem-conta-design.md](2026-09-24-flavor-lite-sem-conta-design.md) — origem do flavor Lite (convivência, agora revertida)
- [2026-09-29-publicacao-lite-play-design.md](2026-09-29-publicacao-lite-play-design.md) — endurecimento do Lite (F47)
- [05 App Flutter](../05-app-flutter.md) · [12 PRD](../12-prd.md) · [07 Qualidade & CI](../07-qualidade-ci.md) · [09 Runbook](../09-runbook-operacoes.md) · [14 Tarefas](../14-tarefas.md)
