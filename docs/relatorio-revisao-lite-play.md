# Relatório — Revisão de prontidão do app Lite ("Minhas Listas") para a Google Play (2026-09-29)

> Navegação: [14 Tarefas](14-tarefas.md) · [12 PRD](12-prd.md) · [06 MVP/Entregas](06-mvp-entregas.md) · [09 Runbook](09-runbook-operacoes.md) · Fonte dos achados da **Fase 47 — Publicação do Lite na Play**.

Revisão de leitura do código e da configuração nativa no commit `d4b92db` (branch `main`), em 3 frentes independentes (nativa/Play, modo Lite em runtime, docs/CI), com **verificação manual** dos achados por leitura direta do arquivo (`arquivo:linha`) antes de entrarem aqui. Cada achado tem ID (`L-xx`), evidência, **doc dono** e o veredito.

**Escopo combinado com o dono (29/09/2026):** revisão completa do app Lite **e** da prontidão para a Play, meta **produção pública**; estratégia **"Lite 100% local de verdade"** com **voz mantida**; conta de desenvolvedor **pessoal nova**; política de privacidade publicada via **GitHub Pages** com contato pelo e-mail da conta de desenvolvedor.

**Legenda de status:** `confirmado` (arquivo/doc relido) · `suspeita` (leitura, exige teste em runtime) · `latente` (não afeta o app hoje).

**Requisitos externos confirmados (Google Play, 29/09/2026):**
- **API-alvo:** desde 31/08/2026, app novo precisa de `targetSdk ≥ 36` (Android 16) — o Lite já declara **36** (`build.gradle.kts:33` → `flutter.targetSdkVersion`). ✅
- **Conta pessoal nova** (criada após 13/11/2023): exige **closed test com ≥12 testadores por 14 dias contínuos** antes de liberar produção, além de verificação de identidade e de aparelho.
- **Política de privacidade** com **URL pública** exigida na ficha.

---

## 1. Bloqueadores (impedem "produção pública" hoje)

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **L-01** | **Nenhum AAB de release é produzido.** O CI só compila APK **debug** dos dois flavors; localmente só há APK release. A Play exige **AAB assinado**. | `.github/workflows/ci.yml:26-29`; ausência de `bundle/` em `build/app/outputs` | [07](07-qualidade-ci.md) · [09](09-runbook-operacoes.md) §2.9 | confirmado |
| **L-02** | **Assinatura de release cai para a debug key** quando `android/key.properties` não existe (a Play rejeita). Não há Play App Signing / gestão de upload key documentados. | `android/app/build.gradle.kts:58-78` | [09](09-runbook-operacoes.md) §2.9 | confirmado |
| **L-03** | **Sentry liga no Lite sem olhar o modo.** O único gate é `sentryDsn.isEmpty`; basta alguém colocar `SENTRY_DSN` no `dart_defines_prod.json` (gitignored, editável) para o Lite enviar erros/sessão. "100% local" fica condicional ao build. | `lib/bootstrap.dart:25,86-97`; spec Lite §3 | [05](05-app-flutter.md) §2.3 · [06](06-mvp-entregas.md) §3.1 | confirmado |
| **L-04** | **Firebase/`google-services` empacotado no Lite**, que não usa push: plugin aplicado em todos os flavors; `google-services.json` traz cliente `.lite`; `FirebaseInitProvider` pode auto-inicializar nativo. Contradiz "sem Firebase". | `build.gradle.kts:12-17`; `android/app/google-services.json:27-45`; merged `liteRelease` (providers/receivers Firebase) | [05](05-app-flutter.md) §2.3 | suspeita (rede nativa exige teste) |
| **L-05** | **Permissões herdadas no Lite:** `INTERNET`, `POST_NOTIFICATIONS`, `com.google.android.c2dm.permission.RECEIVE`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK` (injetadas por Firebase/Messaging) e `RECORD_AUDIO` (do `main`). `INTERNET`/push contradizem "sem rede/notificações"; `RECORD_AUDIO` terá uso (voz). | `android/app/src/main/AndroidManifest.xml:3,5`; merged `liteRelease:11-38` | [05](05-app-flutter.md) §2.3 | confirmado |
| **L-06** | **`allowBackup` não declarado → default `true`**, sem `dataExtractionRules`/`fullBackupContent`: o banco Drift/SQLite e `shared_preferences` do Lite entram no **Auto Backup do Google**, contrariando "só no aparelho". | `android/app/src/main/AndroidManifest.xml:6-9` | [05](05-app-flutter.md) §2.3 | confirmado |
| **L-07** | **Política de privacidade inadequada para a loja.** Não há **URL pública** (o site `/privacidade` foi removido na ADR-013), o texto **não cobre o Lite** (fala de e-mail/senha, Supabase e exclusão de conta) e **não tem e-mail do encarregado** (genérico, decisão de 17/09/2026). | `lib/core/l10n/politica_privacidade.dart:5-30`; `docs/06-mvp-entregas.md:82-85` | [06](06-mvp-entregas.md) §3.3.2 | confirmado |
| **L-08** | **Sem preparação de ficha/Console:** Declaração de Dados ("Segurança de dados"), classificação indicativa, público-alvo, declaração de anúncios, título/descrição, ícone 512, feature graphic e screenshots do Lite não existem em lugar nenhum do repo. | ausência nos docs ([06](06-mvp-entregas.md) §4 só cita o prod) | [06](06-mvp-entregas.md) §4 | confirmado |
| **L-09** | **Gate externo de conta pessoal nova:** closed test com **≥12 testadores / 14 dias contínuos** por app, + verificação de identidade e de aparelho, antes do acesso à produção. | (requisito do Google Play; não é código) | [09](09-runbook-operacoes.md) | confirmado |

## 2. Importantes

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **L-10** | **R8/minify ligado no release sem `proguard-rules.pro`** no repo; nenhum AAB release foi validado. Risco de remoção de classes necessárias que só aparece no artefato de publicação. | `FlutterPlugin.kt:217-218` (SDK); ausência de `android/**/*.pro` | [07](07-qualidade-ci.md) · [09](09-runbook-operacoes.md) §2.9 | suspeita |
| **L-11** | **Trava `flavor × modo` só roda em `kDebugMode`.** Um release Lite montado sem `-t lib/main_lite.dart` empacota o app colaborativo com o pacote `.lite` silenciosamente (incidente real na F41). O CI não cobre o cenário de release. | `lib/bootstrap.dart:42-44`; `docs/09-runbook-operacoes.md:160-162` | [09](09-runbook-operacoes.md) §2.9 | confirmado |
| **L-12** | **Voz pode usar o reconhecedor de rede do sistema** (áudio processado fora do aparelho) mesmo com `onDevice: true`; o app não consegue impedir. Mantida por decisão do dono → exige declarar **Áudio** na Data Safety e cobrir na política. | `lib/features/voz/data/reconhecimento_voz_plugin.dart:6-14,64-68` | [06](06-mvp-entregas.md) §3 · [05](05-app-flutter.md) §6 | confirmado |
| **L-13** | **O CI não inspeciona o manifest mergeado do Lite.** Sem uma checagem, `INTERNET`/Firebase/permissões podem voltar a vazar por merge de plugin sem ninguém notar. | `.github/workflows/ci.yml` (sem passo de manifest) | [07](07-qualidade-ci.md) | confirmado |
| **L-14** | **Doc dono da publicação não cobre o Lite.** O checklist do [06](06-mvp-entregas.md) §1 é do app colaborativo (registro/login/sync/RLS) e a F5-T06 é "teste interno" do prod; o RF-31 não tem cláusula de loja. Não há checklist próprio do Lite. | `docs/06-mvp-entregas.md:13-22,133-139`; `docs/12-prd.md:54,158`; `docs/14-tarefas.md:137-139` | [06](06-mvp-entregas.md) · [12](12-prd.md) · [14](14-tarefas.md) | confirmado |
| **L-15** | **`versionCode`/`versionName` compartilhados** entre flavors vêm do `pubspec` (`1.5.0+14`); não há trilha dedicada do Lite. Como são apps distintos na Play, é aceitável, mas o bump precisa ser lembrado a cada envio. | `pubspec.yaml:19`; `build.gradle.kts:34-35` | [09](09-runbook-operacoes.md) §2.9 | latente |

## 3. Menores e dívidas

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **L-16** | `google-services.json` rastreado com API key real do Firebase (decisão documentada; a restrição da chave no console é ação humana e não verificável no repo). | `android/app/google-services.json`; `docs/09-runbook-operacoes.md:120-124` | confirmado |
| **L-17** | **Drift de docs do Lite:** a spec diz `app_name = "Lista de Compras Lite"` (código usa "Minhas Listas") e `file_picker` (código usa `file_selector`). | spec Lite `:121,133` × `build.gradle.kts:49`; `secao_backup.dart:3` | confirmado |
| **L-18** | Nome de loja **"Minhas Listas"** pode colidir com apps existentes (disponibilidade/trademark) — verificar no Console antes de fixar título/ícone. | (externo) | suspeita |
| **L-19** | Artefatos de build locais **desatualizados** (`liteRelease` versionCode 13, `prodDebug` 12, `liteDebug` 14) contra `1.5.0+14`; não confiar em metadados antigos. | `build/app/intermediates/merged_manifests/**` × `pubspec.yaml:19` | confirmado |
| **L-20** | **Sem automação de publicação** (fastlane/scripts); o hotfix de Play existe só em prosa no runbook. | `docs/09-runbook-operacoes.md:217-223`; ausência de `fastlane/` | confirmado |
| **L-21** | `web/version.json` cobre apenas o `app_name` do prod ("Lista de Compras") — irrelevante para o Lite (não vai para web), mas o paridade-test não distingue flavors. | `web/version.json`; `test/core/config/version_json_test.dart:7-25` | latente |

## 4. Pontos fortes confirmados (não são achados)

- **API-alvo em dia:** `targetSdk 36` / `minSdk 24` (merged `liteRelease:7-9`) — cumpre o requisito de 31/08/2026.
- **Isolamento do Lite por capacidades** (`AppCapacidades.lite`: nuvem/colaboração/notificações `false`): Supabase/Firebase **não** inicializados no Dart; rotas de conta/convite ausentes; `AuthLocalRepository` com dono `'local'`.
- **Outbox realmente desligada no Lite** (`OutboxMutacoes.ativa=false`); nenhuma escrita gera `mutacao_pendente`.
- **Backup local íntegro** (merge por `id`, LWW por `updated_at`, transação, `dono_id` reescrito para `'local'`); sem upload remoto; compartilhamento iniciado pelo usuário.
- **Sem analytics/crash SDK além do Sentry**, sem `dio`, sem uso de `url_launcher` no código (empacotado transitivamente, sem chamadas); `http` só para tipos de exceção.
- **Sem deep link no Lite** (o `src/prod/AndroidManifest.xml` com `intent-filter` não é mesclado no flavor `lite`).

## 5. Documentos relacionados

- [Spec da Fase 47](superpowers/specs/2026-09-29-publicacao-lite-play-design.md)
- [14 Tarefas](14-tarefas.md) — Fase 47
- [12 PRD](12-prd.md) — RF-31 / RF-32
- [06 MVP/Entregas](06-mvp-entregas.md) — publicação e LGPD
- [09 Runbook](09-runbook-operacoes.md) — build/Play
