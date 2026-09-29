# App único "Minhas Listas" (Lite) sem Supabase — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remover todo o Supabase (backend e cliente) e o código de colaboração do app, deixando um único app local "Minhas Listas".

**Architecture:** o app passa a ter um único entrypoint (`main.dart`) e uma única fonte de verdade (Drift). Sessão é uma constante local (`idLocal = 'local'`); não há auth, sync/outbox, convites, push nem observabilidade remota. O backend `supabase/` e o app colaborativo deixam de existir.

**Tech Stack:** Flutter 3.44.5, Riverpod, go_router, Drift/SQLite, pt-BR.

**Spec:** [docs/superpowers/specs/2026-09-29-app-unico-lite-sem-supabase-design.md](../specs/2026-09-29-app-unico-lite-sem-supabase-design.md)

## Global Constraints

- Enum de unidades fechado: `un, kg, g, l, ml, caixa, pacote, pct, pt, dz` — não alterar.
- CI verde obrigatório: `dart format .`, `flutter analyze`, `flutter test` antes de cada commit de fase.
- **Nunca** commitar antes de o usuário pedir; os passos de commit abaixo só são executados sob autorização (marque-os como pendentes até lá).
- Nenhuma chave/segredo em código. Remover `dart_defines_prod.json` no PR (contém URL/anon key).
- Não alterar o formato do backup JSON nem o parser de importação/voz.
- Idioma pt-BR em docs/UI e mensagens de commit.
- **Ajuste de fronteira (vs. spec §10):** no Dart, as fases "corte de recursos" e "corte da costura" são **atômicas** — remover as features órfãs dos tipos `AppModo`/`AppCapacidades` no mesmo passo, senão o código não compila. A Fase 48-A executa esse corte; 48-B é o cutover nativo (flavors/manifest); 48-C é infra/CI/docs.

---

## Fase 48-A — App local-only (Dart)

### Task A1: Constante `idLocal` e desacoplamento do backup da auth

**Files:**
- Create: `lib/core/config/usuario_local.dart`
- Modify: `lib/features/backup/data/backup_repository.dart:1-17,146-148`
- Test: `test/features/backup/backup_import_test.dart` (existente)

**Interfaces:**
- Produces: `const String idLocal = 'local';` (usado por backup, painel de listas e bootstrap).
- Consumes: nada.

- [ ] **Step 1: Criar a constante local**

```dart
// lib/core/config/usuario_local.dart
/// Dono de toda lista no app local (substitui a sessão do Supabase).
const String idLocal = 'local';
```

- [ ] **Step 2: Trocar a dependência da auth no backup**

Em `backup_repository.dart`, remover `import '../../auth/data/auth_local_repository.dart';` e adicionar `import '../../../core/config/usuario_local.dart';`. Trocar `AuthLocalRepository.idLocal` por `idLocal` (linha ~147).

- [ ] **Step 3: Rodar os testes de backup**

Run: `flutter test test/features/backup`
Expected: PASS (comportamento do backup inalterado).

---

### Task A2: Remover o outbox do `ListasRepository`

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (import linha 13; construtor 20-37; chamadas `_outbox.enfileirar` em 174,198,215,237,262,304,444,462,483,509,541,572)
- Modify: `lib/features/listas/providers/listas_providers.dart:3,20-25`
- Test: `test/features/listas/listas_repository_test.dart`

**Interfaces:**
- Produces: `ListasRepository(AppDatabase db, {Uuid? uuid})` — sem `enfileirarMutacoes`/`outbox`.
- Consumes: `appDatabaseProvider` (inalterado).

- [ ] **Step 1: Enxugar o construtor**

Substituir o construtor por:

```dart
  ListasRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;
```

Remover o import `../../sync/data/outbox_mutacoes.dart;` e as linhas `_enfileirarMutacoes`/`_outbox`.

- [ ] **Step 2: Remover as chamadas de enfileiramento**

Apagar cada bloco `await _outbox.enfileirar(...)` (e o comentário imediatamente acima) nos ~12 pontos listados. As escritas no Drift permanecem idênticas.

- [ ] **Step 3: Ajustar o provider**

Em `listas_providers.dart`, trocar o import de `app_modo.dart` (remover) e o provider por:

```dart
final listasRepositoryProvider = Provider<ListasRepository>(
  (ref) => ListasRepository(ref.watch(appDatabaseProvider)),
);
```

- [ ] **Step 4: Rodar os testes do repositório**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Remover o teste de outbox do Lite**

Apagar `test/features/listas/outbox_lite_test.dart`.

---

### Task A3: Remover outbox/vínculo de nuvem do `BackupRepository`

**Files:**
- Modify: `lib/features/backup/data/backup_repository.dart` (import linhas 7; construtor 28-47; blocos `_outbox.enfileirar` em 154-167,197-205)
- Modify: `lib/features/backup/providers/backup_providers.dart`
- Test: `test/features/backup/backup_import_enfileirar_test.dart`, `backup_import_test.dart`, `backup_export_test.dart`

**Interfaces:**
- Produces: `BackupRepository(AppDatabase db)` — sem `donoLocal`/`enfileirar`; importação sempre grava dono `idLocal` e nunca enfileira.
- Consumes: `idLocal` (A1).

- [ ] **Step 1: Enxugar o repositório**

Construtor:

```dart
  BackupRepository(this._db);

  final AppDatabase _db;
```

Remover `outbox_mutacoes.dart`/`auth_local_repository.dart` imports, os campos `donoLocal`/`_enfileirar`/`_outbox` e todos os blocos `await _outbox.enfileirar(...)`. Na inserção de lista, usar sempre `donoId: idLocal`.

- [ ] **Step 2: Ajustar o provider**

```dart
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(appDatabaseProvider)),
);
```

- [ ] **Step 3: Ajustar/apagar testes**

Apagar `test/features/backup/backup_import_enfileirar_test.dart`. Nos demais testes de backup, remover qualquer referência a `enfileirar`/`donoLocal` e a assertiva de fila.

- [ ] **Step 4: Rodar**

Run: `flutter test test/features/backup`
Expected: PASS.

---

### Task A4: Remover a feature de convites/colaboração

**Files:**
- Delete: `lib/features/convites/` (inclusive `data/`, `domain/`, `providers/`, `ui/`)
- Delete: `lib/features/listas/ui/compartilhadas_screen.dart`
- Delete: `lib/core/utils/deeplink_convite.dart`
- Modify: `lib/bootstrap.dart` (remover `deeplinkConviteProvider`) — tratado em A9
- Test: apagar `test/features/convites/**`, `test/features/listas/compartilhadas_screen_test.dart`, `test/fluxos/fluxo_entrar_codigo_test.dart`

**Interfaces:**
- Consumes: `idLocal` (papel do dono vira irrelevante; a UI deixa de ler papel).
- Produces: nenhuma API colaborativa.

- [ ] **Step 1: Apagar os diretórios/arquivos**

Apagar as pastas/arquivos listados. Não apagar `lib/features/tour/tour_keys.dart` (usado pelo tour; remover só a chave de convite em A8).

- [ ] **Step 2: Apagar os testes correspondentes**

Apagar `test/features/convites/`, `test/features/listas/compartilhadas_screen_test.dart`, `test/fluxos/fluxo_entrar_codigo_test.dart`.

- [ ] **Step 3: Confirmar que só restam referências a limpar na UI**

Run: `flutter analyze`
Expected: erros apenas em `painel_listas.dart`, `tela_lista_screen.dart`, `mercado_screen.dart`, `router.dart`, `app.dart`, `configuracoes_screen.dart`, `bootstrap.dart`, `test/fluxos/fluxo_harness.dart` (serão resolvidos nas próximas tasks).

---

### Task A5: Remover notificações/push

**Files:**
- Delete: `lib/features/notificacoes/`
- Modify: `lib/app.dart` (remover listener `notificacoesForegroundProvider`)
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (remover bloco de notificações)
- Test: apagar `test/features/notificacoes/**`, `test/features/configuracoes/configuracoes_notificacoes_test.dart` (se existir dentro de `notificacoes/`)

**Interfaces:**
- Produces: nenhuma API de push.

- [ ] **Step 1: Apagar a feature**

Apagar `lib/features/notificacoes/` e os testes `test/features/notificacoes/`.

- [ ] **Step 2: Remover o listener de foreground do `app.dart`**

Remover o import `features/notificacoes/providers/push_navegacao.dart` e o bloco `ref.listen(notificacoesForegroundProvider, ...)` (linhas 23-30). `mostrarSnackBar` continua sendo usado por outras telas? Verificar: se não, manter o import só se ainda referenciado.

- [ ] **Step 3: Rodar analyze parcial**

Run: `flutter analyze lib/app.dart`
Expected: sem erros de import.

---

### Task A6: Remover sync/outbox e o indicador de sincronização

**Files:**
- Delete: `lib/features/sync/` (inclui `data/outbox_mutacoes.dart`, `data/supabase_bootstrap.dart`, `data/supabase_sync_remoto.dart`, `data/sync_engine.dart`, `data/aplicador_remoto.dart`, `data/mutacao_sync.dart`, `data/sync_remoto.dart`, `domain/sync_status.dart`, `providers/sync_providers.dart`, `ui/indicador_sync.dart`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart:439`, `lib/features/listas/ui/mercado_screen.dart:153`, `lib/features/listas/ui/painel_listas.dart:144` (remover `IndicadorSync`)
- Test: apagar `test/features/sync/**`

**Interfaces:**
- Produces: nenhuma API de sync.

- [ ] **Step 1: Apagar a feature e os testes**

Apagar `lib/features/sync/` e `test/features/sync/`.

- [ ] **Step 2: Remover os usos de `IndicadorSync`**

Em `tela_lista_screen.dart`, `mercado_screen.dart` e `painel_listas.dart`, apagar a linha que monta `IndicadorSync()` e o import. (A limpeza de `capacidadesProvider` nessas telas é feita em A8.)

---

### Task A7: Remover Sentry e `core/rede`

**Files:**
- Delete: `lib/core/observabilidade/` (`sentry_config.dart`, `sentry_privacidade.dart`)
- Delete: `lib/core/rede/` (`erro_rede.dart`, `erro_rede_nativa.dart`, `erro_rede_web.dart`)
- Modify: `lib/bootstrap.dart` (remover init do Sentry) — tratado em A9
- Test: apagar `test/core/observabilidade/**`, `test/core/rede/**`

- [ ] **Step 1: Apagar os diretórios e testes**

Apagar `lib/core/observabilidade/`, `lib/core/rede/`, `test/core/observabilidade/`, `test/core/rede/`.

---

### Task A8: Colapsar UI, rotas, tema e strings para local-only

**Files:**
- Modify: `lib/router.dart` (reescrever)
- Modify: `lib/core/navigation/app_shell.dart` (2 abas)
- Modify: `lib/core/theme/identidade_visual.dart` (só Lite)
- Modify: `lib/core/l10n/politica_privacidade.dart` (só Lite)
- Modify: `lib/core/widgets/app_politica_privacidade.dart` (sem capacidades)
- Modify: `lib/features/onboarding/ui/boas_vindas_screen.dart` (sem capacidades)
- Modify: `lib/features/tour/tour_step.dart` (remover `elegivel`)
- Modify: `lib/features/tour/tour_controller.dart` (sem capacidades)
- Modify: `lib/features/tour/tour_roteiro.dart` (sem `elegivel`/passo de convite)
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (sem conta/push)
- Modify: `lib/features/listas/ui/painel_listas.dart`, `tela_lista_screen.dart`, `mercado_screen.dart` (sem papel/colaboração/capacidades)
- Modify: `lib/core/l10n/app_strings.dart` (remover strings órfãs; `appNome = 'Minhas Listas'`)
- Test: `test/core/navigation/app_shell_test.dart`, `test/core/l10n/app_strings_test.dart`, `test/core/l10n/politica_privacidade_test.dart`, `test/features/tour/**`, `test/features/listas/lite_ui_test.dart`, `test/widget_test.dart`

**Interfaces:**
- Produces: `routerProvider` sem redirect/refresh; `AppShell` com 2 abas; `IdentidadeVisual.lite`; `politicaPrivacidadeTextoLite`; `TourStep` sem `elegivel`.
- Consumes: `idLocal`.

- [ ] **Step 1: Reescrever o router**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_shell.dart';
import 'features/configuracoes/ui/configuracoes_screen.dart';
import 'features/design_system/ui/design_system_screen.dart';
import 'features/listas/ui/mercado_screen.dart';
import 'features/listas/ui/minhas_listas_screen.dart';
import 'features/listas/ui/tela_lista_screen.dart';
import 'features/listas/ui/tela_ordenar_categorias.dart';
import 'features/onboarding/ui/boas_vindas_screen.dart';

/// Rotas do app local (RF-31): sem conta, sem compartilhamento, sem sync.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/listas',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/listas'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listas',
                builder: (context, state) => const MinhasListasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/configuracoes',
                builder: (context, state) => const ConfiguracoesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/lista/:listaId',
        builder: (context, state) =>
            TelaListaScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/mercado/:listaId',
        builder: (context, state) =>
            MercadoScreen(listaId: state.pathParameters['listaId']!),
      ),
      GoRoute(
        path: '/boas-vindas',
        builder: (context, state) => const BoasVindasScreen(),
      ),
      GoRoute(
        path: '/categorias',
        builder: (context, state) => const TelaOrdenarCategorias(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignSystemScreen(),
        ),
    ],
  );
});
```

- [ ] **Step 2: `app_shell.dart` com 2 abas**

Remover o import de `app_modo.dart` e a condicional `colaboracao`; fixar:

```dart
    final icones = [
      (normal: Icons.checklist_outlined, selecionado: Icons.checklist),
      (normal: Icons.settings_outlined, selecionado: Icons.settings),
    ];
    final rotulos = [AppStrings.abaMinhas, AppStrings.configuracoes];
```

- [ ] **Step 3: `identidade_visual.dart` só Lite**

Remover `import '../config/app_modo.dart'`, o construtor `colaborativo` e o provider dependente de capacidades. Manter:

```dart
final identidadeVisualProvider = Provider<IdentidadeVisual>(
  (ref) => IdentidadeVisual.lite,
);
```

- [ ] **Step 4: Política e sheet**

Em `politica_privacidade.dart`: remover o import de `app_modo.dart` e a função `politicaPrivacidadePara`; manter apenas `politicaPrivacidadeTextoLite`. Em `app_politica_privacidade.dart`: usar `politicaPrivacidadeTextoLite` direto e remover o `ProviderScope.containerOf`.

- [ ] **Step 5: Boas-vindas sem capacidades**

Em `boas_vindas_screen.dart`: remover `capacidadesProvider`/`colaborativo`; usar sempre os textos/`_Destaque` do Lite (título, subtítulo, offline e backup).

- [ ] **Step 6: Tour sem capacidades**

`tour_step.dart`: remover o campo `elegivel` e o import `app_modo.dart`. `tour_roteiro.dart`: remover `elegivel:` de todos os passos e apagar o passo `recursos.convite`. `tour_controller.dart`: remover `final cap = ref.read(capacidadesProvider);` e o `.where((p) => p.elegivel(cap))`. Se `TourKeys.acaoConvite` ficar órfão, removê-lo de `tour_keys.dart`.

- [ ] **Step 7: Configurações sem conta/push**

Em `configuracoes_screen.dart`: remover o import do Supabase, `emailUsuarioProvider`, `notificacoesServiceProvider`, `notificacoesAtivasProvider`, `plataformaComPush`, `AppDialog`/exclusão de conta, métodos `_confirmarSair`/`_confirmarExclusao`/`_excluirConta` e a classe `_DialogoSenhaExclusao`. Mantém: Aparência, Ordenar categorias, Sobre (política, versão, tour), Backup.

- [ ] **Step 8: Painel/tela/mercado local-only**

- `painel_listas.dart`: `usuario` vira `idLocal`; `ehDono` sempre `true`; remover FAB/estado "compartilhadas", `ConvitesPendentesSecao`, `convitesRepositoryProvider`, `papelRepositoryProvider`/`atualizar`, `notificacoesService.talvezPedirPermissao`.
- `tela_lista_screen.dart`: remover `papelEfetivoProvider`, `papelRepositoryProvider`, `membrosDaListaProvider`, itens de menu convidar/membros e guardas `colaboracao`.
- `mercado_screen.dart`: remover `papelEfetivoProvider`/`ehDono`/`Papel.leitor` (pode editar sempre).
- Remover imports de `response` não usados.

- [ ] **Step 9: String central**

Em `app_strings.dart`: `static const appNome = 'Minhas Listas';` e apagar `appNomeLite`. Remover os blocos: auth/login/senha (~linhas 10-56), compartilhamento/convite (~249-309), sync (~350-357), notificações (~362-364), conta/exclusão (~376-395) e as variantes colaborativas das boas-vindas (usar as Lite como base). Apagar `sair`/`entrar` se ficarem órfãs.

- [ ] **Step 10: Ajustar/apagar testes de UI**

Apagar `test/features/listas/lite_ui_test.dart` (conceito de modo não existe mais). Atualizar `app_shell_test.dart` (2 abas, sem `_AuthAutenticado`), `app_strings_test.dart`, `politica_privacidade_test.dart` (sem variante Supabase), `test/features/tour/tour_*`, `test/widget_test.dart` (abre em `/listas`, sem Supabase).

- [ ] **Step 11: Rodar**

Run: `flutter test test/core/navigation test/core/l10n test/features/tour test/features/listas/tela_lista_screen_test.dart test/widget_test.dart`
Expected: PASS.

---

### Task A9: Remover auth; bootstrap único; apagar a costura de modos

**Files:**
- Delete: `lib/features/auth/`, `lib/core/config/app_modo.dart`, `lib/core/config/compatibilidade_modo_pacote.dart`, `lib/main_lite.dart`, `lib/core/widgets/tela_build_incorreto.dart`
- Rewrite: `lib/bootstrap.dart`, `lib/main.dart`
- Test: apagar `test/bootstrap_lite_test.dart`, `test/router_lite_test.dart`, `test/core/config/app_modo_test.dart`, `test/core/config/compatibilidade_modo_pacote_test.dart`, `test/features/auth/**`, `test/core/widgets/tela_build_incorreto_test.dart`
- Modify: `test/fluxos/fluxo_harness.dart` (sem auth/sync/convites)

**Interfaces:**
- Produces: `Future<void> bootstrap()`; `main()` chama `bootstrap()`.
- Consumes: `ListaComprasApp`, `usarPathUrlStrategy`.

- [ ] **Step 1: Apagar a auth e a costura**

Apagar os arquivos/pastas listados.

- [ ] **Step 2: Reescrever `bootstrap.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/web/url_strategy.dart';

/// Arranque do app local (RF-31): sem Supabase, Firebase, push ou Sentry.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  usarPathUrlStrategy();
  runApp(const ProviderScope(child: ListaComprasApp()));
}
```

- [ ] **Step 3: `main.dart`**

```dart
import 'bootstrap.dart';

Future<void> main() => bootstrap();
```

- [ ] **Step 4: Ajustar o harness de fluxo**

Em `test/fluxos/fluxo_harness.dart`: remover imports de auth/sync/convites/Supabase; remover `authRepositoryProvider`, `syncStatusProvider`, `meusConvitesPendentesProvider`, `convitesRepositoryProvider` dos overrides (mantém `appDatabaseProvider`). O app abre direto em `/listas`.

- [ ] **Step 5: Apagar os testes obsoletos e rodar**

Apagar os testes listados. Rodar:

Run: `flutter test`
Expected: falhas restantes apenas em testes que ainda referenciam features removidas (corrigidos na Task A10).

---

### Task A10: Limpar a suíte de testes restante

**Files:**
- Modify: `test/features/listas/{tela_lista_screen_test,tela_lista_orcamento_test,minhas_listas_screen_test,mercado_screen_test,editar_item_historico_test}.dart`
- Modify: `test/features/configuracoes/configuracoes_screen_test.dart` (remover casos de conta/exclusão), apagar `test/features/configuracoes/exclusao_conta_test.dart`
- Modify: `test/fluxos/{fluxo_lista_test,fluxo_importar_test,fluxo_offline_test}.dart`
- Modify: `test/core/navigation/app_shell_test.dart` (se ainda usar `SupabaseAuthRepository`)
- Test: suíte completa

- [ ] **Step 1: Substituir fakes de Supabase por estado local**

Onde os testes montavam `Supabase.initialize`/`FakeAuthRepository`/`AuthAutenticado`, remover essa preparação. Como não há mais login, o app já abre autenticado (local). Ajustar overrides para conter apenas `appDatabaseProvider`.

- [ ] **Step 2: Remover asserções de colaboração/sync/push**

Remover testes/asserções sobre compartilhadas, convites, membros, indicador de sync e notificações.

- [ ] **Step 3: Rodar a suíte**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Formatar e analisar**

Run: `dart format . ; flutter analyze`
Expected: sem erros.

- [ ] **Step 5: Commit (somente sob autorização do usuário)**

```bash
git add -A
git commit -m "F48-A: app local-only, remove auth/sync/convites/push (RF-31)"
```

---

### Task A11: Migration Drift v11 — dropar `mutacao_pendente`

**Files:**
- Delete: `lib/drift/tables/mutacao_pendente.dart`
- Modify: `lib/drift/database.dart` (tables; `schemaVersion`; `_dedupItensAtivos`; `onUpgrade`)
- Regenerate: `lib/drift/database.g.dart`
- Test: `test/drift/database_test.dart`

**Interfaces:**
- Produces: banco sem tabela `mutacao_pendente`; `schemaVersion == 11`.
- Consumes: nada.

- [ ] **Step 1: Escrever o teste de migration**

Adicionar em `test/drift/database_test.dart`:

```dart
  test('deve_remover_mutacao_pendente_quando_upgrade_para_v11', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP TABLE IF EXISTS mutacao_pendente');
    expect(db.schemaVersion, 11);
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(rows.map((r) => r.data['name']), isNot(contains('mutacao_pendente')));
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/drift/database_test.dart`
Expected: FAIL (schemaVersion ainda 10 / tabela ainda declarada).

- [ ] **Step 3: Ajustar `database.dart`**

- Remover o import e a entrada `MutacaoPendente` de `@DriftDatabase(tables: [...])`.
- `schemaVersion => 11`.
- Em `_dedupItensAtivos`, remover a subconsulta de `mutacao_pendente` (ordenar só por `updated_at DESC, rowid DESC`) e o `DELETE FROM mutacao_pendente ...`.
- Em `onUpgrade`, adicionar ao final:

```dart
      if (de < 11) {
        // v10 → v11: sem sync não há fila de mutações (F48/RF-31).
        await m.deleteTable('mutacao_pendente');
      }
```

- [ ] **Step 4: Regenerar o código**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` sem referências a `MutacaoPendente`.

- [ ] **Step 5: Rodar**

Run: `flutter test test/drift/database_test.dart`
Expected: PASS.

---

### Task A12: Remover dependências órfãs do `pubspec`

**Files:**
- Modify: `pubspec.yaml:40-58`
- Test: build/analyze

**Interfaces:**
- Produces: `pubspec` sem libs de nuvem.

- [ ] **Step 1: Remover as dependências**

Apagar de `dependencies`: `supabase_flutter`, `app_links`, `connectivity_plus`, `http`, `firebase_core`, `firebase_messaging`, `sentry_flutter`.

- [ ] **Step 2: Reinstalar e analisar**

Run: `flutter pub get ; flutter analyze`
Expected: sem erros de import.

- [ ] **Step 3: Rodar a suíte**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Commit (somente sob autorização)**

```bash
git add -A
git commit -m "F48-A: remove outbox, migration v11 e deps de nuvem (RF-31)"
```

---

## Fase 48-B — Cutover nativo (Android/flavors)

### Task B1: Android sem flavors e sem Firebase

**Files:**
- Modify: `android/app/build.gradle.kts`
- Delete: `android/app/google-services.json`, `android/app/src/prod/AndroidManifest.xml`
- Modify/rename: `android/app/src/liteRelease/AndroidManifest.xml` → `android/app/src/release/AndroidManifest.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` (comentário do INTERNET)
- Test: build Android

**Interfaces:**
- Produces: app Android único `br.com.oliverlucas.listacompras.lite`, "Minhas Listas".

- [ ] **Step 1: Remover o plugin Google Services**

Em `build.gradle.kts`, apagar `id("com.google.gms.google-services")`.

- [ ] **Step 2: Remover flavors e fixar a identidade**

Remover o bloco `flavorDimensions`/`productFlavors` e, em `defaultConfig`, fixar:

```kotlin
    defaultConfig {
        applicationId = "br.com.oliverlucas.listacompras.lite"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Minhas Listas")
    }
```

Manter `buildFeatures { resValues = true }` e a assinatura como está.

- [ ] **Step 3: Mover o endurecimento para o release único**

Renomear `src/liteRelease/AndroidManifest.xml` para `src/release/AndroidManifest.xml`. Ajustar o comentário ("Lite" → app único). Manter as remoções de INTERNET/Firebase e `allowBackup="false"`/`dataExtractionRules`. Apagar `src/prod/AndroidManifest.xml` e `google-services.json`.

- [ ] **Step 4: Ajustar o manifest principal**

Em `main/AndroidManifest.xml`, atualizar o comentário do `INTERNET` (não é mais "Supabase"). Como as libs não existem mais, o release manifest remove o INTERNET que algum plugin possa adicionar; manter `RECORD_AUDIO`.

- [ ] **Step 5: Compilar**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL, pacote `.lite`.

- [ ] **Step 6: Commit (somente sob autorização)**

```bash
git add -A
git commit -m "F48-B: Android sem flavors/Firebase, pacote do Lite (RF-31)"
```

---

### Task B2: Web e versão do app

**Files:**
- Modify: `web/version.json`
- Modify: `web/index.html`
- Test: `test/core/config/version_json_test.dart`

**Interfaces:**
- Produces: web do app local "Minhas Listas".

- [ ] **Step 1: Atualizar `version.json`**

```json
{"app_name":"Minhas Listas","version":"1.5.0","build_number":"14","package_name":"lista_compras"}
```

- [ ] **Step 2: Atualizar `index.html`**

Trocar `<title>`, `apple-mobile-web-app-title` e a `meta description` para "Minhas Listas" / "Lista de compras simples, que funciona no seu aparelho.".

- [ ] **Step 3: Rodar**

Run: `flutter test test/core/config/version_json_test.dart`
Expected: PASS (ajustar o teste se ele afirmar o nome antigo).

- [ ] **Step 4: Build web**

Run: `flutter build web --release`
Expected: BUILD SUCCESSFUL.

---

## Fase 48-C — Infra, CI, docs

### Task C1: Apagar backend, workflow de backup e defines

**Files:**
- Delete: `supabase/` inteiro
- Delete: `.github/workflows/backup.yml`
- Delete: `dart_defines_prod.json`

- [ ] **Step 1: Apagar**

Apagar os três alvos. (`supabase/tests/node_modules` também vai junto.)

- [ ] **Step 2: Confirmar que nada em `lib/`/`.github/` referencia `supabase/`**

Run: `flutter analyze`
Expected: sem erros.

---

### Task C2: CI sem Supabase, builds sem flavor/defines

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: job `flutter` (sem job `supabase`) com web/apk/aab/desktop sem flavor.

- [ ] **Step 1: Apagar o job `supabase`**

Remover todo o bloco `supabase:` de `ci.yml`.

- [ ] **Step 2: Ajustar os builds do job `flutter`**

Substituir os passos de build por:

```yaml
      - run: flutter build web --release
      - run: flutter build apk --debug
      - run: flutter build appbundle --release
      - name: Manifest release sem INTERNET nem Firebase
        run: |
          MANIFEST=build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
          test -f "$MANIFEST" || { echo "manifest mergeado não encontrado"; exit 1; }
          falhou=0
          grep -q 'android.permission.INTERNET' "$MANIFEST" && { echo "INTERNET vazou"; falhou=1; }
          grep -q 'com.google.firebase' "$MANIFEST" && { echo "Firebase vazou"; falhou=1; }
          grep -q 'com.google.android.c2dm' "$MANIFEST" && { echo "c2dm vazou"; falhou=1; }
          grep -q 'io.flutter.plugins.firebase' "$MANIFEST" && { echo "Firebase vazou"; falhou=1; }
          grep -q 'android:allowBackup="false"' "$MANIFEST" || { echo "allowBackup não desligado"; falhou=1; }
          grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST" || { echo "RECORD_AUDIO sumiu"; falhou=1; }
          exit $falhou
```

No job `desktop`, remover `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` dos comandos de build.

- [ ] **Step 3: Validar o caminho do manifest**

Ajustar o caminho `processReleaseManifest` conforme o nome real gerado pelo AGP (o valor da F47 era `liteRelease/processLiteReleaseManifest`). Confirmar após o primeiro build no CI.

- [ ] **Step 4: Commit (somente sob autorização)**

```bash
git add -A
git commit -m "F48-C: remove backend supabase e ajusta CI (RF-31)"
```

---

### Task C3: Documentação dona, AGENTS e tarefas

**Files:**
- Delete: `docs/01-banco-de-dados.md`, `docs/02-seguranca-rls.md`, `docs/03-sincronizacao-offline.md`, `docs/08-compartilhamento-colaborativo.md`
- Modify: `docs/00-visao-geral.md`, `docs/05-app-flutter.md`, `docs/06-mvp-entregas.md`, `docs/07-qualidade-ci.md`, `docs/09-runbook-operacoes.md`, `docs/10-wireframes-telas.md`, `docs/11-usabilidade-fase5.md`, `docs/12-prd.md`, `docs/13-premodelo-tecnico.md`, `docs/14-tarefas.md`, `docs/15-design-system.md`, `docs/16-roadmap-pos-mvp.md`
- Modify: `AGENTS.md`, `planejamento_lista_compras.md`

**Interfaces:**
- Produces: documentação coerente com o app local único.

- [ ] **Step 1: Apagar os docs de backend**

Apagar `01`/`02`/`03`/`08`. Corrigir links quebrados nos demais.

- [ ] **Step 2: Atualizar os docs donos**

- `00`: visão de produto local, sem backend/nuvem.
- `05`: remover modos e rotas de conta; rotas finais da §A8; remover sync do fluxo.
- `06`: LGPD local (sem excluir conta/nuvem); publicação do Lite.
- `07`: um único app; remover Supabase/RLS/Realtime/Sentry (RF-12).
- `09`: builds sem flavor/defines; remover Supabase CLI, migrations, backup do banco e app Firebase.
- `10`: remover wireframes de login/registro/senha/compartilhadas/membros/indicador de sync.
- `11`: remover requisitos de online/sync/conta.
- `12`: RF-31 vira o app; remover RF-01/07/08/09/10/11/12/13/14/30; reescrever RF-28/RF-29 sem "sincronizado"; ajustar matriz de rastreabilidade.
- `13`: resumo técnico sem nuvem.
- `14`: adicionar a Fase 48 (tarefas A1…C4) e a linha na tabela de progresso; F41/F42/F47 viram histórico.
- `15`: identidade única (Lite).
- `16`: remover frentes de backend; atualizar a onda do Lite.

- [ ] **Step 3: Atualizar `AGENTS.md`**

Remover regras de RLS/sync/compartilhamento e comandos `supabase` (`db reset`/`db push`); remover `01/02/03/04/08` como docs donos (manter `04`? — verificar: `04-importacao-lista.md` continua válido como dono da importação local); manter enum de unidades, offline-first e CI verde.

- [ ] **Step 4: Atualizar `planejamento_lista_compras.md`**

Ajustar o índice e o resumo para o app único local.

- [ ] **Step 5: Commit (somente sob autorização)**

```bash
git add -A
git commit -m "F48-C: docs donos e AGENTS para o app lite único (RF-31)"
```

---

### Task C4: Verificação final

- [ ] **Step 1: Formatação, lint e testes**

Run: `dart format . ; flutter analyze ; flutter test`
Expected: tudo verde.

- [ ] **Step 2: Builds de validação**

Run: `flutter build web --release ; flutter build apk --debug ; flutter build appbundle --release`
Expected: BUILD SUCCESSFUL nos três.

- [ ] **Step 3: Busca por resíduos**

Run: `Select-String -Path lib\*.dart,lib\**\*.dart -Pattern "supabase|Supabase|firebase|Firebase|AppModo|AppCapacidades|capacidadesProvider|OutboxMutacoes|mutacao_pendente"`
Expected: nenhum resultado em `lib/`.

- [ ] **Step 4: Commit final (somente sob autorização)**

```bash
git add -A
git commit -m "F48: app único Minhas Listas sem Supabase (RF-31)"
```

---

## Self-Review

- **Cobertura do spec:** §3 arquitetura (A8/A9), §4 remoções (A2–A9), §5 sessão/dados/migration (A1/A11), §6 observabilidade (A7/A8), §7 build/CI (B1/B2/C1/C2), §8 docs (C3), §9 testes (A10/A12/B2), §10 fases (A/B/C), §12 fora de escopo (não tocado).
- **Placeholders:** nenhum "TBD/TODO"; passos de deleção em massa têm alvo exato e são guiados por `flutter analyze`.
- **Consistência de tipos:** `idLocal` (A1) consumido por backup (A3) e painel (A8); `bootstrap()` (A9) sem parâmetro; `ListasRepository(AppDatabase)` (A2) e `BackupRepository(AppDatabase)` (A3) alinhados aos providers; `schemaVersion == 11` (A11) igual ao texto do teste.
- **Observação:** o caminho exato do manifest mergeado (`processReleaseManifest`) é confirmado no primeiro build do CI (C2/Step 3).
