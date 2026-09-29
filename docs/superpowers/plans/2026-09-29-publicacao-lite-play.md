# Publicação do Lite ("Minhas Listas") na Google Play — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar o flavor `lite` ("Minhas Listas") "100% local de verdade" e publicá-lo em produção na Google Play com AAB assinado, política de privacidade pública e ficha de loja.

**Architecture:** Endurecer o Lite por **capacidades** (`AppCapacidades`): Sentry desligado, Firebase/permissões de rede removidos por manifest do variant `liteRelease`, Auto Backup desativado e trava de build no release. O app colaborativo (`prod`) não muda. O CI passa a validar o AAB release do Lite e o manifest mergeado.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Riverpod, Gradle (flavors `prod`/`lite`, AGP 9, Kotlin 2.3.20), Android SDK 36, GitHub Actions; Play Console.

**Spec:** `docs/superpowers/specs/2026-09-29-publicacao-lite-play-design.md` · **Relatório:** `docs/relatorio-revisao-lite-play.md`

## Global Constraints

- **Offline-first:** nenhuma escrita do Lite toca rede; outbox desligada (`AppCapacidades.lite.nuvem == false`).
- **Sem segredo em código/commit/log.** `dart_defines_prod.json` e `android/key.properties` ficam fora do git.
- **Nunca** usar `service_role` no cliente; RLS intocada (esta fase não toca `supabase/`).
- **`prod` inalterado:** todas as mudanças de comportamento são gated por `AppCapacidades` ou por source set `liteRelease`.
- **Build do Lite sempre com `-t lib/main_lite.dart`** (o flavor sozinho não seleciona o modo — F41/F42).
- **Build do Lite não usa `--dart-define`** (não precisa de Supabase nem DSN).
- **`targetSdk = 36` / `minSdk = 24`** (requisito da Play desde 31/08/2026).
- **Enum de unidades fechado** e demais invariantes do projeto permanecem.
- **pt-BR** em docs, strings e commits; commits no padrão `F47-Tnn: resumo (RF-32)`.
- **CI verde** obrigatório (`dart format .`, `flutter analyze`, `flutter test`).
- **Contato da política** = e-mail da conta de desenvolvedor, preenchido pelo dono em `contatoPrivacidadeEmail` (valor fornecido no momento do PR; não é segredo).

---

### Task 1: Planejamento — RF-32, Fase 47 e docs de roadmap

**Files:**
- Modify: `docs/12-prd.md` (tabela de requisitos §2 e matriz §6)
- Modify: `docs/14-tarefas.md` (nova seção Fase 47 + tabela de progresso)
- Modify: `docs/16-roadmap-pos-mvp.md` (Onda E / gate do dono)
- Modify: `docs/superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md` (corrigir drift L-17)

**Interfaces:**
- Consumes: nada.
- Produces: RF-32 e Fase 47 referenciados por todas as tasks seguintes.

- [ ] **Step 1: RF-32 no doc 12 §2 (tabela de requisitos)**

Depois da linha do RF-31 (`docs/12-prd.md:54`), adicionar:

```markdown
| RF-32 | Publicação do Lite ("Minhas Listas") na Google Play em produção: app 100% local (sem rede/push/Firebase), AAB assinado, política de privacidade pública e Declaração de Dados | 06 §4 + 09 §2.9 + 05 §2.3 | F47 | [06 §4](06-mvp-entregas.md) |
```

- [ ] **Step 2: RF-32 na rastreabilidade do doc 12 §6**

Depois da linha do RF-31 (`docs/12-prd.md:158`), adicionar:

```markdown
| RF-32 | US-01 | F47 | F47-T01…F47-T08 | Widget/unit + build AAB + teste de manifest + smoke em device |
```

- [ ] **Step 3: Seção da Fase 47 no doc 14**

Logo após a nota de fechamento da Fase 46 (`docs/14-tarefas.md:989`), adicionar:

```markdown
## Fase 47 — Publicação do Lite na Play (RF-32)

Spec: [superpowers/specs/2026-09-29-publicacao-lite-play-design.md](superpowers/specs/2026-09-29-publicacao-lite-play-design.md) · Plano: [superpowers/plans/2026-09-29-publicacao-lite-play.md](superpowers/plans/2026-09-29-publicacao-lite-play.md) · Relatório: [relatorio-revisao-lite-play.md](relatorio-revisao-lite-play.md) · Requisito: RF-32 (Lite publicável na Play, produção). · Docs donos: 06, 09, 12, 14, 05, 07.

- [ ] **F47-T01** — Planejamento: RF-32, Fase 47 e docs de roadmap
- [ ] **F47-T02** — Sentry desligado no Lite por capacidades
- [ ] **F47-T03** — Trava flavor×modo também no release (tela bloqueante)
- [ ] **F47-T04** — Política de privacidade por capacidades + contato
- [ ] **F47-T05** — Manifest `liteRelease`: sem rede/push/Firebase + Auto Backup off
- [ ] **F47-T06** — CI: AAB release do Lite + verificação do manifest mergeado
- [ ] **F47-T07** — Página pública da política + GitHub Pages
- [ ] **F47-T08** — Runbook de publicação, checklist do Lite e ficha da loja
```

- [ ] **Step 4: Linha da Fase 47 na tabela de progresso do doc 14**

Na tabela (`docs/14-tarefas.md:993`), após a linha da F46, adicionar e ajustar o total:

```markdown
| F47 Publicação do Lite | 8 | 0 |
```

E trocar `| **Total** | **248** | **246** |` por `| **Total** | **256** | **246** |`.

- [ ] **Step 5: Onda E do doc 16**

Em `docs/16-roadmap-pos-mvp.md`, abaixo da linha E4 (linha 70), adicionar:

```markdown
| E5 | Publicação do Lite na Play (produção) | RF-32 | 06, 09 | Alto | M | em execução (F47) — gate F5-T06 (prod) permanece separado |
```

- [ ] **Step 6: Corrigir drift da spec do Lite (L-17)**

Em `docs/superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md:121`, trocar `resValue app_name = "Lista de Compras Lite"` por `resValue app_name = "Minhas Listas"`; em `:133`, trocar `file_picker` por `file_selector`.

- [ ] **Step 7: Commit**

```bash
git add docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md docs/superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md
git commit -m "F47-T01: RF-32, Fase 47 e docs de roadmap (RF-32)"
```

---

### Task 2: Sentry desligado no Lite por capacidades

**Files:**
- Create: `lib/core/observabilidade/sentry_config.dart`
- Modify: `lib/bootstrap.dart`
- Test: `test/core/observabilidade/sentry_config_test.dart`
- Modify docs: `docs/05-app-flutter.md` (§2.3)

**Interfaces:**
- Consumes: `AppCapacidades` (`lib/core/config/app_modo.dart`).
- Produces: `bool sentryDeveIniciar(AppCapacidades cap, String dsn)`.

- [ ] **Step 1: Escrever o teste que falha**

`test/core/observabilidade/sentry_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/observabilidade/sentry_config.dart';

void main() {
  test('deve_iniciar_sentry_quando_colaborativo_com_dsn', () {
    expect(sentryDeveIniciar(AppCapacidades.colaborativo, 'https://dsn'), isTrue);
  });

  test('nao_deve_iniciar_sentry_quando_lite_mesmo_com_dsn', () {
    expect(sentryDeveIniciar(AppCapacidades.lite, 'https://dsn'), isFalse);
  });

  test('nao_deve_iniciar_sentry_quando_sem_dsn', () {
    expect(sentryDeveIniciar(AppCapacidades.colaborativo, ''), isFalse);
  });
}
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `flutter test test/core/observabilidade/sentry_config_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lista_compras/core/observabilidade/sentry_config.dart'`.

- [ ] **Step 3: Implementar o predicado**

`lib/core/observabilidade/sentry_config.dart`:

```dart
import '../config/app_modo.dart';

/// Sentry só liga no modo colaborativo **e** com DSN definido (F47/RF-32).
/// No Lite (100% local) nenhum dado de erro sai do aparelho, ainda que o
/// build traga um `SENTRY_DSN`.
bool sentryDeveIniciar(AppCapacidades cap, String dsn) =>
    cap.nuvem && dsn.isNotEmpty;
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `flutter test test/core/observabilidade/sentry_config_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Usar o predicado no bootstrap**

Em `lib/bootstrap.dart`, adicionar o import e trocar o gate do Sentry (`lib/bootstrap.dart:86`):

```dart
import 'core/observabilidade/sentry_config.dart';
```

```dart
  if (!sentryDeveIniciar(cap, sentryDsn)) {
    app();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.sendDefaultPii = false;
      options.beforeSend = limparDadosDoSentry;
    }, appRunner: app);
  }
```

- [ ] **Step 6: Rodar a suíte e o lint**

Run: `flutter test` e `flutter analyze`
Expected: tudo verde.

- [ ] **Step 7: Atualizar o doc dono 05 §2.3**

Em `docs/05-app-flutter.md` §2.3, adicionar a nota: "**Sentry no Lite (F47):** desligado por capacidades (`sentryDeveIniciar`) — nenhum dado de erro sai do aparelho, mesmo com `SENTRY_DSN` no build."

- [ ] **Step 8: Commit**

```bash
git add lib/core/observabilidade/sentry_config.dart lib/bootstrap.dart test/core/observabilidade/sentry_config_test.dart docs/05-app-flutter.md
git commit -m "F47-T02: Sentry desligado no Lite por capacidades (RF-32)"
```

---

### Task 3: Trava flavor×modo também no release

**Files:**
- Create: `lib/core/config/compatibilidade_modo_pacote.dart`
- Create: `lib/core/widgets/tela_build_incorreto.dart`
- Modify: `lib/bootstrap.dart`
- Test: `test/core/config/compatibilidade_modo_pacote_test.dart`
- Test: `test/core/widgets/tela_build_incorreto_test.dart`
- Modify docs: `docs/09-runbook-operacoes.md` (§2.9)

**Interfaces:**
- Consumes: `AppModo` (`lib/core/config/app_modo.dart`).
- Produces: `bool modoCompativelComPacote(AppModo modo, String pacote)`; widget `TelaBuildIncorreto`.

- [ ] **Step 1: Escrever o teste que falha (função pura)**

`test/core/config/compatibilidade_modo_pacote_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/config/compatibilidade_modo_pacote.dart';

void main() {
  test('deve_ser_compativel_quando_lite_em_pacote_lite', () {
    expect(
      modoCompativelComPacote(
        AppModo.lite,
        'br.com.oliverlucas.listacompras.lite',
      ),
      isTrue,
    );
  });

  test('nao_deve_ser_compativel_quando_colaborativo_em_pacote_lite', () {
    expect(
      modoCompativelComPacote(
        AppModo.colaborativo,
        'br.com.oliverlucas.listacompras.lite',
      ),
      isFalse,
    );
  });

  test('nao_deve_ser_compativel_quando_lite_em_pacote_prod', () {
    expect(
      modoCompativelComPacote(
        AppModo.lite,
        'br.com.oliverlucas.listacompras',
      ),
      isFalse,
    );
  });

  test('deve_ser_compativel_quando_colaborativo_em_pacote_prod', () {
    expect(
      modoCompativelComPacote(
        AppModo.colaborativo,
        'br.com.oliverlucas.listacompras',
      ),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/config/compatibilidade_modo_pacote_test.dart`
Expected: FAIL — URI não existe.

- [ ] **Step 3: Implementar a função pura**

`lib/core/config/compatibilidade_modo_pacote.dart`:

```dart
import 'app_modo.dart';

/// Compara o modo do entrypoint com o pacote instalado (F42/F47). Com flavors,
/// o pacote `...listacompras.lite` implica modo Lite; os demais, colaborativo.
bool modoCompativelComPacote(AppModo modo, String pacote) {
  final ehPacoteLite = pacote.endsWith('.lite');
  return modo == AppModo.lite ? ehPacoteLite : !ehPacoteLite;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/config/compatibilidade_modo_pacote_test.dart`
Expected: PASS (4 testes).

- [ ] **Step 5: Tela bloqueante + teste de widget**

`lib/core/widgets/tela_build_incorreto.dart`:

```dart
import 'package:flutter/material.dart';

/// Texto exibido quando o pacote instalado não casa com o modo do entrypoint
/// (F47/RF-32). Visível em release — evita subir o app colaborativo sob o
/// pacote `.lite` silenciosamente.
const telaBuildIncorretoTexto =
    'Não foi possível iniciar o aplicativo.\n'
    'Instale a versão correta na loja.';

class TelaBuildIncorreto extends StatelessWidget {
  const TelaBuildIncorreto({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(telaBuildIncorretoTexto, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
```

`test/core/widgets/tela_build_incorreto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/tela_build_incorreto.dart';

void main() {
  testWidgets('deve_mostrar_aviso_quando_build_incorreto', (tester) async {
    await tester.pumpWidget(const TelaBuildIncorreto());
    expect(find.text(telaBuildIncorretoTexto), findsOneWidget);
  });
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/core/widgets/tela_build_incorreto_test.dart`
Expected: PASS.

- [ ] **Step 7: Ligar a trava no bootstrap (debug lança; release mostra a tela)**

Em `lib/bootstrap.dart`, substituir o bloco `if (kDebugMode && _plataformaTemFlavor()) { await _conferirModoDoPacote(modo); }` (`lib/bootstrap.dart:42-44`) por:

```dart
  if (_plataformaTemFlavor() && !await _pacoteCompativel(modo)) {
    if (kDebugMode) {
      throw StateError(
        'Pacote e modo divergem: confira o flavor e o entrypoint '
        '(`-t lib/main_lite.dart` para o Lite).',
      );
    }
    runApp(const TelaBuildIncorreto());
    return;
  }
```

Acrescentar o import `import 'core/config/compatibilidade_modo_pacote.dart';` e `import 'core/widgets/tela_build_incorreto.dart';`, e trocar `_conferirModoDoPacote` (`lib/bootstrap.dart:111-131`) por:

```dart
/// true quando o pacote instalado casa com o modo do entrypoint; sem o plugin
/// (testes/plataformas sem registro) não há o que conferir.
Future<bool> _pacoteCompativel(AppModo modo) async {
  final String pacote;
  try {
    pacote = (await PackageInfo.fromPlatform()).packageName;
  } on Exception {
    return true;
  }
  return modoCompativelComPacote(modo, pacote);
}
```

- [ ] **Step 8: Rodar a suíte, o lint e o format**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 9: Atualizar o doc dono 09 §2.9**

Em `docs/09-runbook-operacoes.md`:162, ajustar o aviso para incluir que "desde a F47 a trava também vale no **release**: pacote/modo divergente exibe uma tela bloqueante (`TelaBuildIncorreto`) em vez de subir o app errado".

- [ ] **Step 10: Commit**

```bash
git add lib/core/config/compatibilidade_modo_pacote.dart lib/core/widgets/tela_build_incorreto.dart lib/bootstrap.dart test/core/config/compatibilidade_modo_pacote_test.dart test/core/widgets/tela_build_incorreto_test.dart docs/09-runbook-operacoes.md
git commit -m "F47-T03: trava flavor x modo no release (RF-32)"
```

---

### Task 4: Política de privacidade por capacidades + contato

**Files:**
- Modify: `lib/core/l10n/politica_privacidade.dart`
- Modify: `lib/core/widgets/app_politica_privacidade.dart`
- Test: `test/core/l10n/politica_privacidade_test.dart`
- Modify docs: `docs/06-mvp-entregas.md` (§3.3.2) e `docs/05-app-flutter.md` (§2.3)

**Interfaces:**
- Consumes: `AppCapacidades` (`lib/core/config/app_modo.dart`).
- Produces: `String politicaPrivacidadePara(AppCapacidades cap)`, `const contatoPrivacidadeEmail`.

- [ ] **Step 1: Escrever o teste que falha**

`test/core/l10n/politica_privacidade_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

void main() {
  test('deve_descrever_lite_quando_sem_nuvem', () {
    final texto = politicaPrivacidadePara(AppCapacidades.lite);
    expect(texto, contains('no seu aparelho'));
    expect(texto, contains('voz'));
    expect(texto, isNot(contains('Supabase')));
  });

  test('deve_descrever_colaborativo_quando_com_nuvem', () {
    final texto = politicaPrivacidadePara(AppCapacidades.colaborativo);
    expect(texto, contains('Supabase'));
  });

  test('deve_ter_o_mesmo_contato_nas_duas_versoes', () {
    expect(
      politicaPrivacidadePara(AppCapacidades.lite),
      contains(contatoPrivacidadeEmail),
    );
    expect(
      politicaPrivacidadePara(AppCapacidades.colaborativo),
      contains(contatoPrivacidadeEmail),
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/l10n/politica_privacidade_test.dart`
Expected: FAIL — `politicaPrivacidadePara`/`contatoPrivacidadeEmail` não definidos.

- [ ] **Step 3: Adicionar o contato, o texto do Lite e o seletor**

Em `lib/core/l10n/politica_privacidade.dart`, adicionar no topo:

```dart
import '../config/app_modo.dart';

/// Canal de contato/encarregado (doc 06 §3.3.2). Preenchido pelo dono com o
/// e-mail da conta de desenvolvedor no momento do PR de publicação.
const contatoPrivacidadeEmail = 'SEU_EMAIL_AQUI';
```

No fim do arquivo:

```dart
const politicaPrivacidadeTextoLite = '''
Política de Privacidade — Minhas Listas

1. Dados que coletamos
O aplicativo funciona inteiramente no seu aparelho.
• Suas listas e itens ficam armazenados apenas no seu dispositivo.
• Não criamos conta, não pedimos e-mail nem senha e não enviamos seus dados para servidores nossos.

2. Voz
• O recurso de adicionar itens por voz usa o reconhecedor de fala do seu aparelho. Conforme o sistema, o áudio pode ser processado pelo serviço de reconhecimento do dispositivo (que pode usar a internet). Não gravamos nem guardamos o áudio.

3. Backup
• Você pode exportar um arquivo de backup e reimportá-lo. O arquivo é criado no seu aparelho e só sai dele por uma ação sua (compartilhar/salvar).

4. Com quem compartilhamos
Não compartilhamos dados com terceiros. Não há publicidade nem rastreamento.

5. Por quanto tempo guardamos
Seus dados ficam no aparelho até você excluí-los no próprio aplicativo (removendo listas ou o app).

6. Seus direitos
Você acessa, corrige e apaga tudo diretamente no aplicativo. O app não é direcionado a menores de 16 anos.

7. Contato
Dúvidas sobre privacidade: contatoPrivacidadeEmail.
''';

/// Texto da política conforme o modo (F47/RF-32): no Lite não há conta/nuvem.
String politicaPrivacidadePara(AppCapacidades cap) =>
    cap.nuvem ? politicaPrivacidadeTexto : politicaPrivacidadeTextoLite;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/l10n/politica_privacidade_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Usar o texto por capacidades na sheet**

`lib/core/widgets/app_politica_privacidade.dart` inteiro:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_modo.dart';
import '../l10n/politica_privacidade.dart';
import 'app_sheet.dart';

/// Abre a Política de Privacidade in-app (doc 06 §3.3.2): o texto do modo
/// atual (Lite × colaborativo), sem versão online embutida.
Future<void> abrirPoliticaPrivacidade(BuildContext context) {
  final cap = ProviderScope.containerOf(context).read(capacidadesProvider);
  return AppSheet.mostrar<void>(
    context,
    child: SingleChildScrollView(child: Text(politicaPrivacidadePara(cap))),
  );
}
```

- [ ] **Step 6: Rodar a suíte, o lint e o format**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 7: Atualizar docs donos**

- `docs/06-mvp-entregas.md` §3.3.2: registrar que a política é **por modo** (Lite × colaborativo), com contato `contatoPrivacidadeEmail` e URL pública (ver Task 7).
- `docs/05-app-flutter.md` §2.3: nota de que a política exibida segue as capacidades.

- [ ] **Step 8: Commit**

```bash
git add lib/core/l10n/politica_privacidade.dart lib/core/widgets/app_politica_privacidade.dart test/core/l10n/politica_privacidade_test.dart docs/06-mvp-entregas.md docs/05-app-flutter.md
git commit -m "F47-T04: politica de privacidade por capacidades (RF-32)"
```

---

### Task 5: Manifest `liteRelease` — sem rede/push/Firebase + Auto Backup off

**Files:**
- Create: `android/app/src/liteRelease/AndroidManifest.xml`
- Create: `android/app/src/liteRelease/res/xml/data_extraction_rules.xml`
- Modify docs: `docs/05-app-flutter.md` (§2.3) e `docs/09-runbook-operacoes.md` (§2.9)

**Interfaces:**
- Consumes: nada (artefato Gradle).
- Produces: manifest mergeado do `liteRelease` sem `INTERNET`/Firebase e com backup desligado — verificado na Task 6.

- [ ] **Step 1: Criar as regras de extração de dados**

`android/app/src/liteRelease/res/xml/data_extraction_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Lite é 100% local: nada sai do aparelho no backup do Google (F47/RF-32). -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="file" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="file" path="." />
    </device-transfer>
</data-extraction-rules>
```

- [ ] **Step 2: Criar o manifest do variant release do Lite**

`android/app/src/liteRelease/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Lite é 100% local: sem rede, sem push e sem Firebase (F47/RF-32).
         As libs continuam empacotadas, porém inertes. RECORD_AUDIO é mantido
         para o recurso de voz. -->

    <uses-permission android:name="android.permission.INTERNET" tools:node="remove" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" tools:node="remove" />
    <uses-permission android:name="com.google.android.c2dm.permission.RECEIVE" tools:node="remove" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove" />
    <uses-permission android:name="android.permission.WAKE_LOCK" tools:node="remove" />

    <application
        android:allowBackup="false"
        android:dataExtractionRules="@xml/data_extraction_rules">

        <service android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService" tools:node="remove" />
        <service android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService" tools:node="remove" />
        <service android:name="com.google.firebase.components.ComponentDiscoveryService" tools:node="remove" />
        <service android:name="com.google.firebase.messaging.FirebaseMessagingService" tools:node="remove" />

        <receiver android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver" tools:node="remove" />
        <receiver android:name="com.google.firebase.iid.FirebaseInstanceIdReceiver" tools:node="remove" />

        <provider android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingInitProvider" tools:node="remove" />
        <provider android:name="com.google.firebase.provider.FirebaseInitProvider" tools:node="remove" />
    </application>
</manifest>
```

- [ ] **Step 3: Gerar o manifest mergeado do Lite release e conferir a remoção**

Run:

```bash
flutter build apk --release --flavor lite -t lib/main_lite.dart
```

Depois, inspecionar o mergeado:

```bash
find build/app/intermediates/merged_manifests/liteRelease -name AndroidManifest.xml -exec cat {} \;
```

Expected: **sem** `android.permission.INTERNET`, **sem** `POST_NOTIFICATIONS`/`c2dm`/`ACCESS_NETWORK_STATE`/`WAKE_LOCK`, **sem** `com.google.firebase.*`; **com** `RECORD_AUDIO` e `android:allowBackup="false"`.

- [ ] **Step 4: Confirmar que o `prod` não mudou**

Run:

```bash
flutter build apk --release --flavor prod --dart-define-from-file=dart_defines_prod.json
find build/app/intermediates/merged_manifests/prodRelease -name AndroidManifest.xml -exec cat {} \;
```

Expected: `prod` continua com `INTERNET`, `POST_NOTIFICATIONS`, Firebase e (se aplicável) os deep links. Nenhum arquivo de `src/liteRelease` aparece nele.

> Se `dart_defines_prod.json` não existir nesta máquina, use `--dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste` só para validar o manifest.

- [ ] **Step 5: Atualizar docs donos**

- `docs/05-app-flutter.md` §2.3: documentar que o Lite **release** remove `INTERNET`/push/Firebase e desliga o Auto Backup; `RECORD_AUDIO` permanece.
- `docs/09-runbook-operacoes.md` §2.9: nota curta sobre o source set `liteRelease`.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/liteRelease/AndroidManifest.xml android/app/src/liteRelease/res/xml/data_extraction_rules.xml docs/05-app-flutter.md docs/09-runbook-operacoes.md
git commit -m "F47-T05: manifest liteRelease sem rede/push/Firebase e backup off (RF-32)"
```

---

### Task 6: CI — AAB release do Lite + verificação do manifest mergeado

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify docs: `docs/07-qualidade-ci.md` (§3)

**Interfaces:**
- Consumes: o manifest produzido na Task 5.
- Produces: job que falha se `INTERNET`/Firebase voltarem ao Lite, ou se o AAB release não compilar.

- [ ] **Step 1: Adicionar os passos ao job `flutter`**

Em `.github/workflows/ci.yml`, logo após o passo do APK debug do Lite (`ci.yml:29`), adicionar:

```yaml
      # F47/RF-32: valida o artefato de publicação do Lite (R8/empacotamento).
      - name: Build AAB release do Lite
        run: flutter build appbundle --release --flavor lite -t lib/main_lite.dart
      # F47/RF-32: o Lite publicado não pode herdar rede nem Firebase.
      - name: Manifest do Lite sem INTERNET nem Firebase
        run: |
          MANIFEST=build/app/intermediates/merged_manifests/liteRelease/processLiteReleaseManifest/AndroidManifest.xml
          test -f "$MANIFEST" || { echo "manifest mergeado do Lite não encontrado"; exit 1; }
          falhou=0
          grep -q 'android.permission.INTERNET' "$MANIFEST" && { echo "INTERNET vazou no Lite"; falhou=1; }
          grep -q 'com.google.firebase' "$MANIFEST" && { echo "Firebase vazou no Lite"; falhou=1; }
          grep -q 'com.google.android.c2dm' "$MANIFEST" && { echo "c2dm vazou no Lite"; falhou=1; }
          grep -q 'android:allowBackup="false"' "$MANIFEST" || { echo "allowBackup não desligado no Lite"; falhou=1; }
          grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST" || { echo "RECORD_AUDIO sumiu do Lite"; falhou=1; }
          exit $falhou
```

- [ ] **Step 2: Rodar o pipeline localmente (aproximação)**

Run (na raiz):

```bash
flutter build appbundle --release --flavor lite -t lib/main_lite.dart
```

Depois copiar o passo de verificação acima para um shell local e rodar.
Expected: mensagem final sem falhas; o AAB é gerado em `build/app/outputs/bundle/liteRelease/app-lite-release.aab`.

- [ ] **Step 3: Atualizar o doc dono 07 §3**

Em `docs/07-qualidade-ci.md` §3, acrescentar o novo passo ("build AAB release do Lite + verificação do manifest: sem INTERNET/Firebase, com allowBackup=false e RECORD_AUDIO") à descrição do job `flutter` e ao diagrama.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F47-T06: CI valida AAB e manifest do Lite (RF-32)"
```

---

### Task 7: Página pública da política + GitHub Pages

**Files:**
- Create: `site/privacidade.html`
- Create: `.github/workflows/pages.yml`
- Test: `test/site/privacidade_html_test.dart`
- Modify docs: `docs/06-mvp-entregas.md` (§3.3.2)

**Interfaces:**
- Consumes: `contatoPrivacidadeEmail` e o texto do Lite (Task 4).
- Produces: URL pública `https://<usuario>.github.io/ListaCompras/privacidade.html`.

- [ ] **Step 1: Escrever o teste que falha (paridade de frases-chave)**

`test/site/privacidade_html_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

void main() {
  test('deve_conter_frases_chave_do_lite_na_pagina_publica', () {
    final html = File('site/privacidade.html').readAsStringSync();
    expect(html, contains('no seu aparelho'));
    expect(html, contains('voz'));
    expect(html, contains(contatoPrivacidadeEmail));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/site/privacidade_html_test.dart`
Expected: FAIL — `site/privacidade.html` não existe.

- [ ] **Step 3: Criar a página estática**

`site/privacidade.html` (conteúdo completo; espelha `politicaPrivacidadeTextoLite`, com o mesmo `contatoPrivacidadeEmail`):

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Política de Privacidade — Minhas Listas</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #1a1a1a; }
    h1 { font-size: 1.5rem; }
    h2 { font-size: 1.1rem; margin-top: 1.5rem; }
    ul { padding-left: 1.2rem; }
  </style>
</head>
<body>
  <h1>Política de Privacidade — Minhas Listas</h1>
  <h2>1. Dados que coletamos</h2>
  <p>O aplicativo funciona inteiramente no seu aparelho.</p>
  <ul>
    <li>Suas listas e itens ficam armazenados apenas no seu dispositivo.</li>
    <li>Não criamos conta, não pedimos e-mail nem senha e não enviamos seus dados para servidores nossos.</li>
  </ul>
  <h2>2. Voz</h2>
  <ul>
    <li>O recurso de adicionar itens por voz usa o reconhecedor de fala do seu aparelho. Conforme o sistema, o áudio pode ser processado pelo serviço de reconhecimento do dispositivo (que pode usar a internet). Não gravamos nem guardamos o áudio.</li>
  </ul>
  <h2>3. Backup</h2>
  <ul>
    <li>Você pode exportar um arquivo de backup e reimportá-lo. O arquivo é criado no seu aparelho e só sai dele por uma ação sua (compartilhar/salvar).</li>
  </ul>
  <h2>4. Com quem compartilhamos</h2>
  <p>Não compartilhamos dados com terceiros. Não há publicidade nem rastreamento.</p>
  <h2>5. Por quanto tempo guardamos</h2>
  <p>Seus dados ficam no aparelho até você excluí-los no próprio aplicativo (removendo listas ou o app).</p>
  <h2>6. Seus direitos</h2>
  <p>Você acessa, corrige e apaga tudo diretamente no aplicativo. O app não é direcionado a menores de 16 anos.</p>
  <h2>7. Contato</h2>
  <p>Dúvidas sobre privacidade: SEU_EMAIL_AQUI.</p>
</body>
</html>
```

> Substituir `SEU_EMAIL_AQUI` pelo mesmo valor de `contatoPrivacidadeEmail` (Task 4).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/site/privacidade_html_test.dart`
Expected: PASS.

- [ ] **Step 5: Criar o workflow de Pages**

`.github/workflows/pages.yml`:

```yaml
name: pages
on:
  push:
    branches: [main]
    paths: ['site/**']
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  publicar:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - uses: actions/checkout@v7
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: site
      - id: deploy
        uses: actions/deploy-pages@v4
```

> **Requisito externo:** habilitar Pages em *Settings → Pages → Source: GitHub Actions*. Em repo privado no plano free, Pages não está disponível — publicar de um repositório público dedicado (o texto continua versionado aqui).

- [ ] **Step 6: Atualizar o doc dono 06 §3.3.2**

Registrar a URL pública da política (ex.: `https://<usuario>.github.io/ListaCompras/privacidade.html`) e que ela é gerada de `site/`, com o contato `contatoPrivacidadeEmail`.

- [ ] **Step 7: Commit**

```bash
git add site/privacidade.html .github/workflows/pages.yml test/site/privacidade_html_test.dart docs/06-mvp-entregas.md
git commit -m "F47-T07: pagina publica da politica e GitHub Pages (RF-32)"
```

---

### Task 8: Runbook de publicação, checklist do Lite e ficha da loja

**Files:**
- Modify: `docs/09-runbook-operacoes.md` (§2.9 e §4)
- Modify: `docs/06-mvp-entregas.md` (§4: tabela, checklist do Lite)
- Modify: `docs/12-prd.md` (se preciso, link do doc dono)
- Create: `store/ficha-lite.md` (textos da ficha)
- Modify docs: `docs/14-tarefas.md` (marcar F47 e progresso)

**Interfaces:**
- Consumes: os artefatos das Tasks 1–7.
- Produces: runbook fechado e artefatos de loja versionados.

- [ ] **Step 1: AAB de publicação no runbook (§2.9)**

Substituir, no bloco de comandos do Lite (`docs/09-runbook-operacoes.md:168`), o comando APK por:

```bash
# AAB de publicação do Lite — SEM dart-defines (sem Supabase, sem Sentry)
flutter build appbundle --release --flavor lite -t lib/main_lite.dart
# → build/app/outputs/bundle/liteRelease/app-lite-release.aab
```

E registrar: "se `android/key.properties` não existir, o AAB sai assinado com a debug key e **não** deve ser enviado à Play".

- [ ] **Step 2: Seção de publicação na Play no runbook**

Adicionar em `docs/09-runbook-operacoes.md` uma subseção `### 2.10. Publicação do Lite na Play (RF-32, F47)` com:

1. Conta pessoal nova → verificação de identidade e de aparelho.
2. Criar o app `br.com.oliverlucas.listacompras.lite`; habilitar Play App Signing; guardar a upload key.
3. Internal testing (smoke) → closed testing com **≥12 testadores opt-in por 14 dias contínuos**.
4. Aplicar para produção → revisão → rollout **10% → 50% → 100%**.
5. Declaração de Dados: **nenhum dado**, exceto **Áudio** (voz). Content rating e público **16+**; anúncios: não.
6. Ficha: título "Minhas Listas", descrições, ícone 512×512, feature graphic 1024×500, screenshots.

- [ ] **Step 3: Checklist de publicação do Lite no doc 06 §4**

Adicionar, em `docs/06-mvp-entregas.md` §4, um checklist próprio do Lite:

```markdown
### 4.1. Checklist de publicação do Lite (RF-32, F47)

- [ ] AAB release assinado com a upload key (não debug key)
- [ ] Manifest do Lite sem `INTERNET`/push/Firebase; Auto Backup desligado
- [ ] Política de privacidade com URL pública (site/privacidade.html)
- [ ] Declaração de Dados preenchida (nenhum dado, exceto Áudio)
- [ ] Ficha da loja completa (ícone 512, feature graphic, screenshots, descrições)
- [ ] Closed test com 12 testadores por 14 dias
- [ ] Smoke em device release (identidade, offline, backup, voz)
```

- [ ] **Step 4: Ficha da loja versionada**

Criar `store/ficha-lite.md` com: título `Minhas Listas`, descrição curta (≤80 caracteres), descrição completa (pt-BR), categoria sugerida, e especificação dos artefatos:

```markdown
# Ficha da loja — Minhas Listas (Lite)

- **Título (≤30):** Minhas Listas
- **Descrição curta (≤80):** Lista de compras simples, sem conta e 100% no seu aparelho.
- **Descrição completa:** ... (texto pt-BR)
- **Categoria:** Compras
- **Ícone da loja:** `store/icone-512.png` (512×512, gerado de `assets/branding/logo_lite.png`)
- **Feature graphic:** `store/feature-graphic-1024x500.png`
- **Screenshots:** `store/screenshots/` (mínimo 2, telefone)
```

Gerar `store/icone-512.png` e `store/feature-graphic-1024x500.png` a partir de `assets/branding/logo_lite.png` (mesmo processo Playwright da F44) e capturar as screenshots em um device/emulador com o app Lite release.

- [ ] **Step 5: Fechar a Fase 47 no doc 14**

Marcar `F47-T01…F47-T08` como `- [x]` em `docs/14-tarefas.md` e atualizar a tabela de progresso: `| F47 Publicação do Lite | 8 | 8 |` e total `| **Total** | **256** | **254** |`.

- [ ] **Step 6: Verificação final**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 7: Commit**

```bash
git add docs/09-runbook-operacoes.md docs/06-mvp-entregas.md docs/14-tarefas.md store/
git commit -m "F47-T08: runbook, checklist e ficha da loja do Lite (RF-32)"
```

---

## Execução externa (não é código — acompanhar no runbook)

Estas etapas são **ações do dono** no Play Console e não têm tarefa de código:

1. Criar a conta pessoal, verificação de identidade e de aparelho.
2. Criar o app `.lite`, Play App Signing e upload key.
3. Publicar AAB no teste interno; convidar ≥12 testadores; manter 14 dias.
4. Aplicar para produção; revisão; rollout 10%→50%→100%.
5. Preencher Declaração de Dados, classificação e ficha.

## Self-Review (feito ao escrever)

- **Cobertura da spec:** Seção 3 (Tasks 2, 3, 4, 5), Seção 4 (Tasks 5, 6), Seção 5 (Tasks 4, 7, 8), Seção 6 (Task 8), Seção 7 (Tasks 1, 8), Seção 8 (testes em cada task + smoke na Task 8).
- **Sem placeholders:** os únicos valores a preencher pelo dono são `contatoPrivacidadeEmail` (dado externo, não código) e os binários da ficha (passo manual descrito).
- **Consistência de tipos:** `sentryDeveIniciar(AppCapacidades, String)`, `modoCompativelComPacote(AppModo, String)`, `politicaPrivacidadePara(AppCapacidades)`, `contatoPrivacidadeEmail`, `TelaBuildIncorreto`/`telaBuildIncorretoTexto` — usados com os mesmos nomes nas tasks seguintes.
