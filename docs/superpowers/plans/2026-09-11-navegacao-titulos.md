# Navegação e títulos das telas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Abrir lista/membros por cima do shell (com voltar correto por origem) e unificar/contextualizar os títulos das telas.

**Architecture:** `/lista/:listaId` e `/membros/:listaId` continuam rotas top-level (fora do shell); o painel passa a abri-las com `context.push` (empilha sobre a aba de origem). Quando não há pilha (deep link/aceite de convite), um helper compartilhado dá seta de voltar e intercepta o botão do sistema, indo para `/listas` (dono) ou `/compartilhadas` (membro).

**Tech Stack:** Flutter 3.44 · go_router 18 · flutter_riverpod 3 · Drift · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-11-navegacao-titulos-design.md`

## Global Constraints

- Comentários no código apenas quando indispensáveis; nomes `camelCase` (Dart); strings pt-BR centralizadas em `lib/core/l10n/app_strings.dart`.
- Testes: nome `deve_<resultado>_quando_<condição>`.
- Não alterar schema/RLS/IA; mudança é só de app + docs.
- Rodar antes de fechar: `dart format .` e `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (segure os commits; a validação fecha a tarefa).

---

### Task 1: Helper de "voltar ao início" + títulos dos estados da lista

**Files:**
- Create: `lib/core/navigation/voltar_para_inicio.dart`
- Modify: `lib/core/l10n/app_strings.dart` (adicionar `lista`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart:150-255`
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces:
  - `String inicioDaLista({required bool ehDono})` → `/listas` ou `/compartilhadas`.
  - `Widget? botaoVoltarInicio(BuildContext context, String inicio)` → `null` quando `context.canPop()`.
  - `class PopScopeVoltarInicio({required String inicio, required Widget child})`.

- [ ] **Step 1: Escrever o teste que falha** (em `tela_lista_screen_test.dart`, antes do fecho de `main`)

```dart
testWidgets(
  'deve_mostrar_titulo_e_voltar_ao_painel_quando_lista_nao_encontrada',
  (tester) async {
    final router = GoRouter(
      initialLocation: '/lista/inexistente',
      routes: [
        GoRoute(
          path: '/lista/:listaId',
          builder: (_, state) =>
              TelaListaScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          donoAtualIdProvider.overrideWithValue('user-a'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.lista), findsOneWidget);
    expect(find.text(AppStrings.listaNaoEncontrada), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.minhasListas), findsOneWidget);

    await fechar(tester);
  },
);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_mostrar_titulo_e_voltar_ao_painel_quando_lista_nao_encontrada`
Expected: FAIL (não encontra `AppStrings.lista` / `Icons.arrow_back`).

- [ ] **Step 3: Adicionar a string**

Em `lib/core/l10n/app_strings.dart`, na seção "Tela da Lista":

```dart
static const lista = 'Lista';
```

- [ ] **Step 4: Criar o helper** — `lib/core/navigation/voltar_para_inicio.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Destino de "voltar" quando não há pilha (deep link/aceite de convite):
/// o dono volta às listas próprias; o membro, às compartilhadas.
String inicioDaLista({required bool ehDono}) =>
    ehDono ? '/listas' : '/compartilhadas';

/// Seta do AppBar: `null` deixa a padrão (pop) quando há pilha; sem pilha,
/// navega para [inicio].
Widget? botaoVoltarInicio(BuildContext context, String inicio) {
  if (context.canPop()) return null;
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.go(inicio),
  );
}

/// Trata o voltar do sistema quando não há pilha, indo para [inicio].
class PopScopeVoltarInicio extends StatelessWidget {
  const PopScopeVoltarInicio({
    super.key,
    required this.inicio,
    required this.child,
  });

  final String inicio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(inicio);
      },
      child: child,
    );
  }
}
```

- [ ] **Step 5: Editar `TelaListaScreen`**

Adicionar import:
```dart
import '../../../core/navigation/voltar_para_inicio.dart';
```

Trocar o `build` (linhas ~149-255) para:

```dart
@override
Widget build(BuildContext context) {
  final listaId = widget.listaId;
  final listaAsync = ref.watch(listaPorIdProvider(listaId));
  return listaAsync.when(
    loading: () => Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.lista),
        leading: botaoVoltarInicio(context, '/listas'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.lista),
        leading: botaoVoltarInicio(context, '/listas'),
      ),
      body: const Center(child: Text(AppStrings.erroGenerico)),
    ),
    data: (lista) {
      if (lista == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.lista),
            leading: botaoVoltarInicio(context, '/listas'),
          ),
          body: const Center(child: Text(AppStrings.listaNaoEncontrada)),
        );
      }
      final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
      final inicio = inicioDaLista(ehDono: ehDono);
      return PopScopeVoltarInicio(
        inicio: inicio,
        child: Scaffold(
          appBar: AppBar(
            leading: botaoVoltarInicio(context, inicio),
            title: Text(lista.titulo),
            actions: [
              // (menu ⋮ inalterado)
            ],
          ),
          body: Column(
            children: [
              const IndicadorSync(),
              if (_papelNaLista(lista.id) == Papel.leitor)
                const _BannerSomenteLeitura(),
              if (_papelNaLista(lista.id) != Papel.leitor)
                _CampoAdicionar(listaId: listaId),
              Expanded(child: _ListaItens(listaId: listaId)),
              if (_papelNaLista(lista.id) != Papel.leitor)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: AppBotao(
                      rotulo: AppStrings.importarLista,
                      variante: AppBotaoVariante.outlined,
                      icone: Icons.smart_toy_outlined,
                      onPressed: () => _importarPorIa(context, ref, listaId),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
```

Manter o conteúdo atual do `actions` (PopupMenuButton) sem alterações.

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (25+ testes).

---

### Task 2: Membros — título contextual, voltar e sair

**Files:**
- Modify: `lib/features/convites/ui/tela_membros_screen.dart:121-168`
- Test: `test/features/convites/tela_membros_screen_test.dart`

**Interfaces:**
- Consumes: helper da Task 1.
- Produces: título `"{AppStrings.membros} · {lista.titulo}"`; sair navega a `/compartilhadas`.

- [ ] **Step 1: Escrever os testes que falham**

No harness `abrir` (linhas 80-93), acrescentar rota:

```dart
GoRoute(
  path: '/compartilhadas',
  builder: (_, _) => const Scaffold(body: Text('painel-compartilhadas')),
),
```

Adicionar testes antes do fim de `main`:

```dart
testWidgets('deve_mostrar_titulo_com_nome_da_lista_quando_existe', (
  tester,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final agora = DateTime.now().toUtc();
  await db.into(db.listaLocal).insert(
    ListaLocalCompanion.insert(
      id: _listaId,
      createdAt: agora,
      updatedAt: agora,
      titulo: 'Feira',
      donoId: 'U1',
    ),
  );
  final servidor = ServidorFake((req) {
    if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
      return (200, _linhasMembros());
    }
    return (500, {'message': 'requisição inesperada: ${req.url.path}'});
  });
  addTearDown(servidor.close);
  await abrir(tester, servidor, usuarioId: 'U1', db: db);

  expect(find.text('${AppStrings.membros} · Feira'), findsOneWidget);

  await fechar(tester);
});

testWidgets('deve_voltar_para_compartilhadas_quando_sem_pilha_e_nao_e_dono', (
  tester,
) async {
  final servidor = ServidorFake((req) {
    if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
      return (200, _linhasMembros());
    }
    return (500, {'message': 'requisição inesperada: ${req.url.path}'});
  });
  addTearDown(servidor.close);
  await abrir(tester, servidor, usuarioId: 'U3');

  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  expect(find.text('painel-compartilhadas'), findsOneWidget);

  await fechar(tester);
});
```

Ajustar o teste existente `deve_sair_da_lista_quando_seleciona_e_confirma` (rota `/listas` → acrescentar `/compartilhadas` e mudar a asserção final):

```dart
GoRoute(
  path: '/compartilhadas',
  builder: (_, _) => const Scaffold(body: Text('painel-compartilhadas')),
),
```
```dart
expect(find.text('painel-compartilhadas'), findsOneWidget);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: FAIL (título não tem o nome; voltar não existe; sair vai a `/listas`).

- [ ] **Step 3: Implementar** — em `tela_membros_screen.dart`

Adicionar import:
```dart
import '../../../core/navigation/voltar_para_inicio.dart';
```

Trocar `build` (linha ~152):

```dart
@override
Widget build(BuildContext context) {
  final usuarioId = ref.watch(donoAtualIdProvider);
  final membrosAsync = ref.watch(membrosDaListaProvider(listaId));
  final lista = ref.watch(listaPorIdProvider(listaId)).value;
  final inicio = inicioDaLista(ehDono: lista?.donoId == usuarioId);
  final titulo = lista == null
      ? AppStrings.membros
      : '${AppStrings.membros} · ${lista.titulo}';
  return PopScopeVoltarInicio(
    inicio: inicio,
    child: Scaffold(
      appBar: AppBar(
        leading: botaoVoltarInicio(context, inicio),
        title: Text(titulo),
        actions: [
          if (membrosAsync.hasValue && !_eDono(membrosAsync, usuarioId))
            TextButton(
              onPressed: () => _confirmarSair(context, ref),
              child: const Text(AppStrings.sairDaLista),
            ),
        ],
      ),
      body: membrosAsync.when(/* inalterado */),
    ),
  );
}
```

Trocar em `_confirmarSair` (linha ~138):
```dart
if (context.mounted) context.go('/compartilhadas');
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: PASS (9 testes).

---

### Task 3: Painel abre lista por `push` (empilha e volta)

**Files:**
- Modify: `lib/features/listas/ui/painel_listas.dart:135`
- Test: `test/features/listas/minhas_listas_screen_test.dart`
- Test: `test/features/listas/compartilhadas_screen_test.dart`

- [ ] **Step 1: Escrever os testes que falham**

`minhas_listas_screen_test.dart`: no stub `/lista/:id` (linhas 37-41), adicionar AppBar:
```dart
GoRoute(
  path: '/lista/:id',
  builder: (_, state) => Scaffold(
    appBar: AppBar(),
    body: Text('lista-${state.pathParameters['id']}'),
  ),
),
```

E adicionar teste:
```dart
testWidgets('deve_empilhar_e_voltar_ao_painel_quando_abrir_lista', (
  tester,
) async {
  final repo = ListasRepository(db);
  await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
  await abrirTela(tester);

  await tester.tap(find.text('Compras'));
  await tester.pumpAndSettle();
  expect(find.byType(BackButton), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text('Compras'), findsOneWidget);
  expect(find.byType(BackButton), findsNothing);

  await fechar(tester);
});
```

`compartilhadas_screen_test.dart`: idem no stub `/lista/:id` (linhas 67-71) e teste:
```dart
testWidgets('deve_empilhar_e_voltar_ao_painel_quando_abrir_compartilhada', (
  tester,
) async {
  final repo = ListasRepository(db);
  await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-a');
  await abrirTela(tester);

  await tester.tap(find.text('Do parceiro'));
  await tester.pumpAndSettle();
  expect(find.byType(BackButton), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text('Do parceiro'), findsOneWidget);

  await fechar(tester);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: FAIL (`go` substitui a pilha → sem `BackButton`).

- [ ] **Step 3: Implementar** — `painel_listas.dart:135`

```dart
onTap: () => context.push('/lista/${lista.id}'),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: PASS.

---

### Task 4: Aba "Configurações" + voltar por origem no shell

**Files:**
- Modify: `lib/core/navigation/app_shell.dart:20-24`
- Modify: `lib/core/l10n/app_strings.dart:198`
- Test: `test/core/navigation/app_shell_test.dart`

- [ ] **Step 1: Escrever o teste que falha**

Em `app_shell_test.dart`, trocar linhas 79 e 81:
```dart
expect(find.text(AppStrings.configuracoes), findsOneWidget);
```
```dart
await tester.tap(find.text(AppStrings.configuracoes));
```

Trocar o helper `montar` (linhas 40-64) para aceitar seed e neutralizar o sync:
```dart
Future<void> montar(
  WidgetTester tester, {
  required Size tamanho,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seed != null) await seed(db);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_AuthAutenticado()),
      appDatabaseProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith(
        (ref) => Stream<SyncStatus>.value(const Sincronizado()),
      ),
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
}
```

Imports novos:
```dart
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
```

Adicionar teste:
```dart
testWidgets('deve_voltar_para_aba_de_origem_quando_abrir_lista', (
  tester,
) async {
  await montar(
    tester,
    tamanho: const Size(500, 800),
    seed: (db) async {
      final repo = ListasRepository(db);
      await repo.criarLista(titulo: 'Minha lista', donoId: 'user-a');
      await repo.criarLista(titulo: 'Do outro', donoId: 'user-b');
    },
  );

  await tester.tap(find.text('Minha lista'));
  await tester.pumpAndSettle();
  expect(find.byType(BackButton), findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.abaMinhas), findsOneWidget);

  await tester.tap(find.text(AppStrings.compartilhadas));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Do outro'));
  await tester.pumpAndSettle();
  expect(find.byType(BackButton), findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.compartilhadas), findsWidgets);

  await fechar(tester);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: FAIL (`abaAjustes` ainda referenciado / sem `BackButton`).

- [ ] **Step 3: Implementar**

`app_shell.dart:20-24`:
```dart
static const _rotulos = [
  AppStrings.abaMinhas,
  AppStrings.compartilhadas,
  AppStrings.configuracoes,
];
```

`app_strings.dart`: remover `static const abaAjustes = 'Ajustes';`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: PASS (3 testes).

---

### Task 5: Docs donos + tarefa + validação final

**Files:**
- Modify: `docs/05-app-flutter.md` (§4 rotas/fluxo)
- Modify: `docs/10-wireframes-telas.md` (§2/§3 nota de navegação/título)
- Modify: `docs/superpowers/specs/2026-09-11-revisao-visual-ux-etapa3-design.md` (nota)
- Modify: `docs/14-tarefas.md` (F10-T06 + progresso)

- [ ] **Step 1: Atualizar doc 05 §4/§5** — listar as rotas reais (`/listas`, `/compartilhadas`, `/configuracoes`, `/lista/:listaId`, `/membros/:listaId`) e registrar: abrir lista/membros é `push` sobre o shell (voltar retorna à aba de origem); sem pilha (deep link/aceite) o voltar vai a `/listas`/`/compartilhadas` conforme o papel.

- [ ] **Step 2: Atualizar doc 10 §2/§3** — nota de que a tela da lista é tela cheia sobre a barra, com seta de voltar; título de Membros é `Membros · {título}`.

- [ ] **Step 3: Nota no spec etapa 3** — registrar a mudança de decisão: de "fora do shell (go)" para "push sobre o shell com fallback", com link para o novo spec.

- [ ] **Step 4: doc 14** — adicionar F10-T06 (mesmo formato das demais) e atualizar a linha da F10 e o total na tabela de progresso.

- [ ] **Step 5: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações, analyze "No issues found!", todos os testes verdes.

- [ ] **Step 6: Commit (somente com confirmação do usuário)**

```bash
git add lib docs test
git commit -m "F10-T06: push sobre o shell, voltar por origem e títulos das telas (RF-02, RF-13)"
```

## Self-Review

- **Spec coverage:** navegação push/fallback (Tasks 1,3,4); título membros (Task 2); estados da lista (Task 1); "Configurações" (Task 4); docs/14 (Task 5). ✔
- **Placeholders:** nenhum "TBD"; passos com código real. ✔
- **Type consistency:** `inicioDaLista`/`botaoVoltarInicio`/`PopScopeVoltarInicio` definidos na Task 1 e consumidos nas Tasks 2/4 com a mesma assinatura. ✔
- **Risco:** a Task 4 renderiza `TelaListaScreen` no router real; se o sync/realtime causar instabilidade, manter o override de `syncStatusProvider` já previsto e, em último caso, restringir o teste à origem "Minhas".
