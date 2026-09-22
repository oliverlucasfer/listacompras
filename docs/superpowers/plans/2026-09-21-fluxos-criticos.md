# Fase 33 — Fluxos Críticos (E2E no widget) (RNF-08): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar testes de **fluxo** ponta a ponta na camada UI+Drift (router real, fakes determinísticos) para os caminhos críticos, rodando no CI (`flutter test`). Goldens e `integration_test` ficam adiados (documentados).

**Architecture:** Um harness `test/fluxos/fluxo_harness.dart` (extraído do `app_shell_test`) monta o app real com Drift in-memory, sessão autenticada fake e sync controlável; cada fluxo encadeia telas reais. Sem alterar produção.

**Tech Stack:** `flutter_test` · Riverpod · go_router · Drift (in-memory) · `ServidorFake`.

**Spec:** `docs/superpowers/specs/2026-09-21-fluxos-criticos-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes.
- Uma tarefa = um commit, mensagem `F33-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `lib/`** (só testes e docs); **nenhuma mudança em `supabase/migrations/`, `docs/01/02/03`**.
- **Sem goldens** e **sem `integration_test`** nesta rodada (adiados — documentados no doc 07).
- Teste nome `deve_<resultado>_quando_<condição>`; determinístico (sem rede/relógio real).
- Docs donos atualizados no mesmo PR.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Harness de fluxo

**Files:**
- Create: `test/fluxos/fluxo_harness.dart`

**Interfaces:**
- Consumes: `routerProvider` (`lib/router.dart`), `authRepositoryProvider`, `appDatabaseProvider`, `syncStatusProvider`, `meusConvitesPendentesProvider`, `convitesRepositoryProvider`; `SupabaseAuthRepository`; `AppDatabase`; `ServidorFake`.
- Produces: `montarApp(tester, {seed, sync, convites, convitesRepo}) -> Future<FluxoApp>`; `FluxoApp { AppDatabase db; ProviderContainer container; }`.

- [ ] **Step 1: Escrever o harness**

`test/fluxos/fluxo_harness.dart` (padrão do `test/core/navigation/app_shell_test.dart`):

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/domain/convite_pendente.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/convites_pendentes_secao.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sessão autenticada fake (padrão do `app_shell_test`): o app abre no painel.
class AuthAutenticado extends SupabaseAuthRepository {
  AuthAutenticado() : super(Supabase.instance.client);

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();

  @override
  Session? get sessaoAtual => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    refreshToken: 'refresh',
    expiresIn: 3600,
    user: User(
      id: 'user-a',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

class FluxoApp {
  FluxoApp(this.db, this.container);
  final AppDatabase db;
  final ProviderContainer container;
}

/// Monta o app real (router) com Drift in-memory e sessão autenticada fake.
/// [convitesRepo] permite injetar um repositório com `ServidorFake` (ex.: para
/// o fluxo de "entrar com código").
Future<FluxoApp> montarApp(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  SyncStatus sync = const Sincronizado(),
  Future<List<ConvitePendente>> Function()? convites,
  ConvitesRepository? convitesRepo,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seed != null) await seed(db);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(AuthAutenticado()),
      appDatabaseProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(sync)),
      meusConvitesPendentesProvider.overrideWith(
        (ref) async =>
            convites == null ? const <ConvitePendente>[] : await convites(),
      ),
      if (convitesRepo != null)
        convitesRepositoryProvider.overrideWithValue(convitesRepo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return FluxoApp(db, container);
}

Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
```

- [ ] **Step 2: Compilar o harness**

Run: `flutter test test/fluxos/fluxo_harness.dart`
Expected: compila (nenhum teste) — `No tests ran`/exit 0; `flutter analyze` sem issues.

- [ ] **Step 3: Commit**

```bash
git add test/fluxos/fluxo_harness.dart
git commit -m "F33-T01: harness de fluxo (router real + drift in-memory) (RNF-08)"
```

---

### Task 2: Os quatro fluxos críticos

**Files:**
- Create: `test/fluxos/fluxo_lista_test.dart`
- Create: `test/fluxos/fluxo_importar_test.dart`
- Create: `test/fluxos/fluxo_entrar_codigo_test.dart`
- Create: `test/fluxos/fluxo_offline_test.dart`

**Interfaces:**
- Consumes: `montarApp`/`fechar` (Task 1); `ListasRepository`; `AppStrings`; `ServidorFake`; `ConvitesRepository`.

- [ ] **Step 1: Fluxo lista (criar → adicionar → marcar → limpar → desfazer)**

`test/fluxos/fluxo_lista_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_criar_lista_adicionar_marcar_e_limpar_quando_fluxo_completo', (
    tester,
  ) async {
    await montarApp(tester);

    // Criar lista
    await tester.tap(
      find.widgetWithText(FloatingActionButton, AppStrings.novaLista),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Compras',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.criarLista));
    await tester.pumpAndSettle();
    expect(find.text('Compras'), findsOneWidget);

    // Abrir a lista e adicionar item
    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Arroz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);

    // Marcar (vai para concluídos)
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // Limpar concluídos (menu ⋮) e desfazer
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsNothing);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });
}
```

- [ ] **Step 2: Fluxo importar (colar → extrair → confirmar)**

`test/fluxos/fluxo_importar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_importar_quando_cola_texto_e_confirma', (tester) async {
    await montarApp(
      tester,
      seed: (db) async {
        await ListasRepository(db).criarLista(titulo: 'Compras', donoId: 'user-a');
      },
    );

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.importarLista),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '1kg de arroz, 2 leites',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.importConfirmeItens), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importAdicionarN(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);

    await fechar(tester);
  });
}
```

> Se a pré-visualização não vier com todos selecionados por padrão, selecione os itens (checkboxes) antes de confirmar; o rótulo `importAdicionarN(n)` reflete a contagem selecionada.

- [ ] **Step 3: Fluxo entrar com código (token → RPC → navega)**

`test/fluxos/fluxo_entrar_codigo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/fakes.dart';
import '../features/convites/servidor_fake.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_entrar_com_codigo_quando_token_valido', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('aceitar_convite')) {
        return (200, 'lista-x');
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);

    await montarApp(
      tester,
      convitesRepo: ConvitesRepository(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-key',
          httpClient: servidor,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
    );

    // Aba Compartilhadas → "Entrar com código"
    await tester.tap(find.text(AppStrings.compartilhadas));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.conviteComCodigo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.conviteCampoCodigo),
      'token-cru',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    // Saiu do painel para a rota da lista (id inexistente → estado "não encontrada")
    expect(find.text(AppStrings.listaNaoEncontrada), findsOneWidget);

    await fechar(tester);
  });
}
```

> O seletor da aba Compartilhadas (`AppStrings.compartilhadas`) pode estar no `NavigationBar`; ajuste para `find.text(...)`/`find.byIcon(...)` conforme o shell real.

- [ ] **Step 4: Fluxo offline (item local + fila)**

`test/fluxos/fluxo_offline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';

import '../features/auth/fakes.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_manter_item_quando_adiciona_offline', (tester) async {
    final app = await montarApp(
      tester,
      sync: const Offline(),
      seed: (db) async {
        await ListasRepository(db).criarLista(titulo: 'Compras', donoId: 'user-a');
      },
    );

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Arroz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    final mutacoes = await app.db.select(app.db.mutacaoPendente).get();
    expect(
      mutacoes.where((m) => m.tabela == 'itens_lista' && m.operacao == 'INSERT'),
      isNotEmpty,
    );

    await fechar(tester);
  });
}
```

> Confirme o nome do estado de sync offline (`const Offline()`) em `lib/features/sync/domain/sync_status.dart` e ajuste se for outro.

- [ ] **Step 5: Rodar os fluxos**

Run: `flutter test test/fluxos/`
Expected: PASS (4 fluxos). Ajuste seletores que não baterem (o harness/telas reais podem diferir em detalhes).

- [ ] **Step 6: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add test/fluxos/fluxo_lista_test.dart test/fluxos/fluxo_importar_test.dart test/fluxos/fluxo_entrar_codigo_test.dart test/fluxos/fluxo_offline_test.dart
git commit -m "F33-T02: fluxos criticos (lista, importar, entrar, offline) (RNF-08)"
```

---

### Task 3: Docs donos e fechamento da Fase 33

**Files:**
- Modify: `docs/07-qualidade-ci.md`
- Modify: `docs/14-tarefas.md`
- Modify: `docs/16-roadmap-pos-mvp.md`

- [ ] **Step 1: Doc 07 — estratégia e o que fica adiado**
  - Na §1 (estratégia de testes), acrescentar uma linha **"Fluxos críticos (E2E no widget)"** na tabela: `flutter_test` + router real + Drift in-memory; caminhos criar/adicionar/marcar/limpar, importar, entrar por código, offline; prioridade Alta (RNF-08); roda no CI.
  - Acrescentar um parágrafo registrando as **decisões adiadas**: **goldens** (sensíveis à plataforma — dev gera no Windows, CI roda Linux; gerar quando houver runner Linux dedicado) e **`integration_test` (device/emulador)** (exige device; smoke manual, como o deep link físico) — nenhum roda no CI atual.

- [ ] **Step 2: Doc 16 e 14**
  - `16`: Onda C linha C2 → `fluxos críticos concluídos (F33); goldens e integration_test adiados`.
  - `14`: Fase 33 com F33-T01…T03 `[x]` + CPs; tabela `| F33 Fluxos críticos | 3 | 3 |` e total `| **Total** | **174** | **172** |`.

- [ ] **Step 3: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/07-qualidade-ci.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F33-T03: docs donos e fechamento da Fase 33 (RNF-08)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 harness → Task 1; §4 fluxos → Task 2; §6 docs → Task 3; §2 adiados (goldens/integration_test) → Task 3 (07).
- **Placeholders:** nenhum "TBD"; o código dos fluxos está completo, com notas onde o seletor real pode divergir (o implementador ajusta).
- **Consistência de tipos:** `montarApp({seed,sync,convites,convitesRepo}) -> Future<FluxoApp>`, `FluxoApp{db,container}`, `fechar`; progresso 174/172 — idênticos entre tarefas.
- **Sem produção:** só `test/` e `docs/`; nenhum `lib/` alterado.
