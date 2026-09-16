# F16 — Busca e filtro — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Busca/filtro local (offline) por **título de lista** no painel e por **nome de item** na tela da lista, com helper puro, lupa na AppBar e estados "sem resultados".

**Architecture:** Filtragem **em memória** sobre os streams locais já existentes (`listasComContagemProvider`, `itensDaListaProvider`), sem provider novo, sem schema/RLS/sync. Um helper puro em `lib/core/texto/busca.dart` reusa `normalizarTexto` (caixa/acento). `PainelListas` vira `ConsumerStatefulWidget` para guardar o termo; `TelaListaScreen` (já stateful) guarda o termo e o repassa ao `_ListaItens`.

**Tech Stack:** Flutter 3.44 · flutter_riverpod 3 · go_router 18 · Drift · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-16-busca-filtro-design.md` (RF-17)

**Tarefa dona:** Fase 16 em `docs/14-tarefas.md` · Docs normativos: [12](../../12-prd.md), [05 §6.2/§6.3](../../05-app-flutter.md), [10 §2/§3](../../10-wireframes-telas.md), [15 §3/§4](../../15-design-system.md)

## Global Constraints

- Comentários no código apenas quando indispensáveis. `camelCase` (Dart); pt-BR strings centralizadas em `lib/core/l10n/app_strings.dart`.
- Testes: nome `deve_<resultado>_quando_<condicao>`.
- **Não alterar schema/RLS/IA/sync nem repositórios; sem provider novo; sem pacote novo.**
- **Semântica da busca:** case/acento-insensitive via `normalizarTexto`; termo vazio = sem filtro (a UI nem chama o helper).
- Regras vinculantes (spec §4): painel filtra por **título**; lista filtra por **nome**, **mantém grupos** de categoria (esconde vazios), concluídos filtrados na seção dobrável, **drag desabilitado** enquanto filtra; ao **adicionar** item, a busca é **limpa**; leitor também pode buscar.
- Rodar antes de fechar: `dart format .`, `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (a validação fecha a tarefa).

---

### Task 1 (F16-T00): RF-17 + docs de planejamento

**Files:**
- Modify: `docs/12-prd.md` (§2 + matriz)
- Modify: `docs/05-app-flutter.md` (§6.2/§6.3)
- Modify: `docs/10-wireframes-telas.md` (§2/§3)
- Modify: `docs/14-tarefas.md` (Fase 16 + progresso)
- Modify: `docs/00-visao-geral.md` (cronograma) e o índice `planejamento_lista_compras.md` se listarem fases

- [ ] **Step 1: 12 PRD §2** — após a linha do RF-16, adicionar

```markdown
| RF-17 | Busca/filtro **local (offline)** de listas pelo título (painel) e de itens pelo nome (tela da lista) | 05 §6.2 + §6.3 | F16 | [05 §8](05-app-flutter.md) |
```

E na matriz (§ rastreabilidade), após a linha do RF-16:

```markdown
| RF-17 | US-01 | F16 | F16-T01…T03 | Unit busca + widgets |
```

- [ ] **Step 2: 05 §6.2** — acrescentar um tópico ao painel (após a linha do FAB/estado vazio)

```
* **Busca (F16, RF-17):** a lupa na AppBar revela um campo no topo do corpo que filtra os cards pelo **título** (offline, sem acento/caixa); sem resultado → `AppEstadoVazio` "Nenhuma lista encontrada" (sem CTA); ✕ limpa e fecha.
```

- [ ] **Step 3: 05 §6.3** — acrescentar um tópico à tela da lista

```
* **Busca (F16, RF-17):** a lupa na AppBar (todas as roles) revela um campo que filtra os itens pelo **nome** (offline, sem acento/caixa); mantém os grupos de categoria (escondendo vazios) e a seção de concluídos (contagens filtradas); **drag desabilitado** enquanto filtra; ao **adicionar** um item a busca é limpa; sem resultado → `AppEstadoVazio` "Nenhum item encontrado" com "Limpar busca".
```

- [ ] **Step 4: 10 §2/§3** — anotar o layout

Em §2 (Minhas Listas), após a nota de navegação:

```
**Busca (F16):** lupa na AppBar revela um campo no topo do corpo (hint "Buscar lista"); a lista filtrada esconde os cards que não casam; sem resultado → vazio "Nenhuma lista encontrada".
```

Em §3 (Tela da Lista), após a nota de grupos:

```
**Busca (F16):** lupa na AppBar revela um campo (hint "Buscar item"); os grupos de categoria permanecem (vazios somem) e o drag fica desabilitado; sem resultado → vazio "Nenhum item encontrado" + "Limpar busca".
```

- [ ] **Step 5: 14 Tarefas** — criar a Fase 16 (após a Fase 14)

```markdown
## Fase 16 — Busca e filtro

Spec: [superpowers/specs/2026-09-16-busca-filtro-design.md](superpowers/specs/2026-09-16-busca-filtro-design.md) · Requisito: RF-17.

- [x] **F16-T00** — RF-17 + docs de planejamento
  Dep: — · Docs: spec da fase
  CP: RF-17 no 12 (tabela + matriz); 05 §6.2/§6.3, 10 §2/§3, 00/índice e Fase 16 no 14 consistentes; sem tocar código de app.
- [ ] **F16-T01** — Helper `contemBusca` + unit tests
  Dep: F16-T00 · Docs: [05 §6.2/§6.3](05-app-flutter.md)
  CP: `contemBusca` puro (caixa/acento) com unit tests dos casos da spec §7; `analyze`/`test` verdes.
- [ ] **F16-T02** — Busca no painel (título)
  Dep: F16-T01 · Docs: [05 §6.2](05-app-flutter.md), [10 §2](10-wireframes-telas.md)
  CP: lupa/campo/filtro por título/vazio de busca no `PainelListas`; widget tests.
- [ ] **F16-T03** — Busca na tela da lista (item)
  Dep: F16-T01 · Docs: [05 §6.3](05-app-flutter.md), [10 §3](10-wireframes-telas.md)
  CP: lupa/campo/filtro por nome, grupos preservados (vazios escondidos), drag off, concluídos filtrados, limpar-ao-adicionar, vazio; widget tests.
- [ ] **F16-T04** — Acessibilidade, docs e fechamento
  Dep: F16-T02, F16-T03 · Docs: [12](12-prd.md), [05](05-app-flutter.md), [10](10-wireframes-telas.md), [14](14-tarefas.md)
  CP: tooltips/estados conferidos; `format`/`analyze`/`test` verdes; Fase 16 marcada.
```

Na tabela de progresso, adicionar a linha e atualizar o total:

```markdown
| F16 Busca e filtro | 5 | 1 |
```

```markdown
| **Total** | **102** | **96** |
```

- [ ] **Step 6: 00 / índice** — se listarem fases, acrescentar a Fase 16 (Busca e filtro) na ordem; caso contrário, nenhuma edição.

- [ ] **Step 7: Conferir**

Run: `git diff --stat`
Expected: só arquivos de `docs/` alterados.

---

### Task 2 (F16-T01): Helper `contemBusca`

**Files:**
- Create: `lib/core/texto/busca.dart`
- Test: `test/core/texto/busca_test.dart`

**Interfaces:**
- Produces: `bool contemBusca(String texto, String consulta)` — normaliza ambos com `normalizarTexto` e devolve `true` quando `texto` **contém** `consulta`. Consumido nas Tasks 3 e 4.

- [ ] **Step 1: Escrever o teste que falha** — `test/core/texto/busca_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/texto/busca.dart';

void main() {
  test('deve_ignorar_caixa_e_acento_quando_buscar', () {
    expect(contemBusca('Café', 'cafe'), isTrue);
    expect(contemBusca('Açúcar', 'ACUCAR'), isTrue);
    expect(contemBusca('Leite', 'lei'), isTrue);
  });

  test('deve_devolver_false_quando_nao_casa', () {
    expect(contemBusca('Arroz', 'feijao'), isFalse);
  });

  test('deve_casar_com_espacos_normalizados_quando_buscar', () {
    expect(contemBusca('  Queijo   prato ', 'queijo prato'), isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/texto/busca_test.dart`
Expected: FAIL (`busca.dart` não existe).

- [ ] **Step 3: Implementar** — `lib/core/texto/busca.dart`

```dart
import 'normalizar.dart';

/// Busca local (RF-17): `true` quando [texto] contém [consulta], ignorando
/// caixa e acento (via [normalizarTexto]).
bool contemBusca(String texto, String consulta) =>
    normalizarTexto(texto).contains(normalizarTexto(consulta));
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/texto/busca_test.dart`
Expected: PASS (3 testes).

---

### Task 3 (F16-T02): Busca no painel (título)

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (strings novas)
- Modify: `lib/features/listas/ui/painel_listas.dart` (`PainelListas` → stateful + lupa/campo/filtro/vazio)
- Test: `test/features/listas/minhas_listas_screen_test.dart`, `test/features/listas/compartilhadas_screen_test.dart`

**Interfaces:**
- Consumes: `contemBusca` (Task 2).
- Produces: `AppStrings.buscar`, `buscarLista`, `limparBusca`, `nenhumaListaEncontrada`, `buscaSemResultadoDica` (reusadas na Task 4).

- [ ] **Step 1: Strings em `app_strings.dart`** (seção "Estados transversais")

```dart
  // Busca/filtro local (RF-17, F16)
  static const buscar = 'Buscar';
  static const buscarLista = 'Buscar lista';
  static const buscarItem = 'Buscar item';
  static const limparBusca = 'Limpar busca';
  static const nenhumaListaEncontrada = 'Nenhuma lista encontrada';
  static const nenhumItemEncontrado = 'Nenhum item encontrado';
  static const buscaSemResultadoDica = 'Tente outro termo.';
```

- [ ] **Step 2: Escrever os testes que falham** em `test/features/listas/minhas_listas_screen_test.dart`

```dart
  testWidgets('deve_filtrar_listas_quando_buscar_pelo_titulo', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras da Semana', donoId: 'user-a');
    await repo.criarLista(titulo: 'Churrasco', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'chur',
    );
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_quando_busca_sem_resultado', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.nenhumaListaEncontrada), findsOneWidget);

    await fechar(tester);
  });
```

Em `test/features/listas/compartilhadas_screen_test.dart`:

```dart
  testWidgets('deve_filtrar_compartilhadas_quando_buscar', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarLista),
      'parc',
    );
    await tester.pumpAndSettle();

    expect(find.text('Do parceiro'), findsOneWidget);
    await fechar(tester);
  });
```

(Use os helpers `abrirTela`/`fechar` já existentes em cada arquivo; ajuste o nome do helper se for diferente.)

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: FAIL (não há lupa/campo ainda).

- [ ] **Step 4: Implementar** — `lib/features/listas/ui/painel_listas.dart`

Trocar a declaração de `PainelListas` por `ConsumerStatefulWidget` e mover o `build` para o State, adicionando o estado de busca. Núcleo:

```dart
class PainelListas extends ConsumerStatefulWidget {
  const PainelListas({super.key, required this.filtro});

  final FiltroListas filtro;

  @override
  ConsumerState<PainelListas> createState() => _PainelListasState();
}

class _PainelListasState extends ConsumerState<PainelListas> {
  final _busca = TextEditingController();
  bool _buscando = false;

  bool get _compartilhadas => widget.filtro == FiltroListas.compartilhadas;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    _busca.clear();
    setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(donoAtualIdProvider);
    final consulta = _busca.text.trim();
    final listasAsync = ref
        .watch(listasComContagemProvider)
        .whenData(
          (todas) => todas
              .where(
                (c) => _compartilhadas
                    ? c.lista.donoId != usuario
                    : c.lista.donoId == usuario,
              )
              .where(
                (c) => consulta.isEmpty ||
                    contemBusca(c.lista.titulo, consulta),
              )
              .toList(),
        );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                _compartilhadas
                    ? AppStrings.compartilhadas
                    : AppStrings.minhasListas,
              ),
            ),
          ],
        ),
        actions: [
          if (_buscando)
            IconButton(
              tooltip: AppStrings.limparBusca,
              icon: const Icon(Icons.close),
              onPressed: _fecharBusca,
            )
          else ...[
            IconButton(
              tooltip: AppStrings.buscar,
              icon: const Icon(Icons.search),
              onPressed: _abrirBusca,
            ),
            if (_compartilhadas)
              IconButton(
                tooltip: AppStrings.conviteComCodigo,
                icon: const Icon(Icons.person_add),
                onPressed: () => abrirDialogoEntrarComCodigo(context, ref),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_buscando)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: AppCampoTexto(
                controller: _busca,
                hint: AppStrings.buscarLista,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: listasAsync.when(
              loading: () => const AppEsqueleto(linhas: 4),
              error: (_, _) => AppEstadoErro(
                mensagem: AppStrings.erroGenerico,
                onRetentar: () => ref.invalidate(listasComContagemProvider),
              ),
              data: (listas) {
                if (listas.isEmpty) {
                  return _buscando && consulta.isNotEmpty
                      ? const AppEstadoVazio(
                          icone: Icons.search_off,
                          titulo: AppStrings.nenhumaListaEncontrada,
                          descricao: AppStrings.buscaSemResultadoDica,
                        )
                      : _vazio(context, ref);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    88,
                  ),
                  itemCount: listas.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CardLista(contagem: listas[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _compartilhadas
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-nova-lista',
              onPressed: () => abrirSheetNovaLista(context, ref),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.novaLista),
            ),
    );
  }

  // Widget _vazio(BuildContext, WidgetRef) permanece exatamente como está hoje.
}
```

Adicionar os imports `../../../core/texto/busca.dart` e `../../../core/widgets/app_campo_texto.dart` (o `app_esqueleto`, `app_logo`, `app_estado_vazio`, `app_estado_erro` já existem).

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter analyze` e `flutter test test/features/listas/`
Expected: analyze limpo; testes verdes (a busca, o vazio de busca e os testes existentes do painel).

---

### Task 4 (F16-T03): Busca na tela da lista (item)

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: `contemBusca` (Task 2), `AppStrings.buscar/buscarItem/limparBusca/nenhumItemEncontrado/buscaSemResultadoDica` (Task 3).
- Produces: `_ListaItens({required String listaId, required String consulta, VoidCallback? onLimparBusca})`; `_CampoAdicionar({required String listaId, VoidCallback? onItemAdicionado})`.

- [ ] **Step 1: Escrever os testes que falham** em `test/features/listas/tela_lista_screen_test.dart`

```dart
  testWidgets('deve_filtrar_itens_e_manter_grupos_quando_buscar', (
    tester,
  ) async {
    await listaComItens(tester); // Arroz (Mercearia), Leite (Laticínios)

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'arr',
    );
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsNothing);
    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsNothing);
    // Drag desabilitado enquanto filtra.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_de_busca_quando_sem_resultado', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.nenhumItemEncontrado), findsOneWidget);
    expect(find.text(AppStrings.limparBusca), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_busca_quando_adicionar_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'arr',
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Busca fechada e itens todos visíveis de novo.
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.widgetWithText(TextField, AppStrings.buscarItem), findsNothing);

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL (sem lupa/filtro).

- [ ] **Step 3: Implementar** — `tela_lista_screen.dart`

No `_TelaListaScreenState`, adicionar o estado de busca:

```dart
  final _busca = TextEditingController();
  bool _buscando = false;

  @override
  void dispose() {
    _busca.dispose();
    _membroEntrou?.removeListener(_aoMembroEntrar);
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    _busca.clear();
    if (mounted) setState(() => _buscando = false);
  }
```

Na `AppBar.actions` (antes do `PopupMenuButton`), adicionar:

```dart
                if (_buscando)
                  IconButton(
                    tooltip: AppStrings.limparBusca,
                    icon: const Icon(Icons.close),
                    onPressed: _fecharBusca,
                  )
                else
                  IconButton(
                    tooltip: AppStrings.buscar,
                    icon: const Icon(Icons.search),
                    onPressed: _abrirBusca,
                  ),
```

No corpo (`Column`), logo após o `const IndicadorSync()`:

```dart
                if (_buscando)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: AppCampoTexto(
                      controller: _busca,
                      hint: AppStrings.buscarItem,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
```

Passar o termo/callback para os filhos:

```dart
                if (_papelNaLista(lista.id) != Papel.leitor)
                  _CampoAdicionar(
                    listaId: listaId,
                    onItemAdicionado: _buscando ? _fecharBusca : null,
                  ),
                Expanded(
                  child: _ListaItens(
                    listaId: listaId,
                    consulta: _busca.text,
                    onLimparBusca: _fecharBusca,
                  ),
                ),
```

Em `_CampoAdicionar`, adicionar o campo e chamar o callback no fim do `_adicionar`:

```dart
class _CampoAdicionar extends ConsumerStatefulWidget {
  const _CampoAdicionar({required this.listaId, this.onItemAdicionado});

  final String listaId;
  final VoidCallback? onItemAdicionado;
  ...
```

No fim de `_adicionar()`, após `_controller.clear();`:

```dart
    _controller.clear();
    widget.onItemAdicionado?.call();
```

Em `_ListaItens`, receber `consulta`/`onLimparBusca` e filtrar:

```dart
class _ListaItens extends ConsumerWidget {
  const _ListaItens({
    required this.listaId,
    required this.consulta,
    this.onLimparBusca,
  });

  final String listaId;
  final String consulta;
  final VoidCallback? onLimparBusca;

  bool _casa(Item item) =>
      consulta.trim().isEmpty || contemBusca(item.nome, consulta);
  ...
```

No `data: (itens)`, ajustar:

```dart
      data: (itens) {
        final filtrando = consulta.trim().isNotEmpty;
        if (itens.isEmpty) {
          return AppEstadoVazio(/* vazio real — inalterado */);
        }
        final pendentes = itens.where((i) => !i.concluido && _casa(i)).toList();
        final concluidos = itens.where((i) => i.concluido && _casa(i)).toList();
        if (filtrando && pendentes.isEmpty && concluidos.isEmpty) {
          return AppEstadoVazio(
            icone: Icons.search_off,
            titulo: AppStrings.nenhumItemEncontrado,
            descricao: AppStrings.buscaSemResultadoDica,
            acao: AppBotao(
              rotulo: AppStrings.limparBusca,
              variante: AppBotaoVariante.texto,
              expandido: false,
              onPressed: onLimparBusca,
            ),
          );
        }
        // ... (montagem dos slivers inalterada, EXCETO o reordenável:)
        // podeEscrever && !filtrando ? SliverReorderableList(...) : SliverList(...)
```

A condição do bloco reordenável passa a ser `podeEscrever && !filtrando` (com `filtrando` derivado de `consulta`). Adicionar os imports `../../../core/texto/busca.dart` (o `AppCampoTexto` já está importado).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter analyze` e `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: analyze limpo; todos os testes da tela verdes (busca, vazio, limpar-ao-adicionar e os existentes de papel/drag/estado).

---

### Task 5 (F16-T04): Acessibilidade, docs e fechamento

**Files:**
- Modify: `docs/05-app-flutter.md` e `docs/10-wireframes-telas.md` (conferir contra o implementado)
- Modify: `docs/14-tarefas.md` (marcar F16-T01…T04 + progresso)
- Test: `test/features/listas/*` (conferência de tooltips)

- [ ] **Step 1: A11y** — conferir que a lupa/✕ têm `tooltip` (`AppStrings.buscar`/`limparBusca`) e que o campo tem `hint`. Se faltar, ajustar. (O teste de tooltips já é coberto pelos testes das Tasks 3/4, que usam `find.byTooltip`.)

- [ ] **Step 2: Docs** — conferir 05 §6.2/§6.3 e 10 §2/§3 contra o implementado; corrigir divergências de texto (a copy real das strings). Nenhuma mudança de schema/RLS.

- [ ] **Step 3: 14** — marcar F16-T01…T04

Ajustar as caixas `- [ ]` para `- [x]` em F16-T01, T02, T03 e T04 (adicionando uma nota curta de implementação em cada, no estilo das fases anteriores).

Na tabela de progresso:

```markdown
| F16 Busca e filtro | 5 | 5 |
```

E o total:

```markdown
| **Total** | **102** | **100** |
```

- [ ] **Step 4: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações; analyze "No issues found!"; toda a suíte verde.

- [ ] **Step 5: Commit (somente com confirmação do usuário)**

```bash
git add lib test docs
git commit -m "F16: busca e filtro local no painel e na lista (RF-17)"
```

> **Nota:** não commitar sem confirmação explícita. Se o usuário autorizar, decidir o agrupamento com ele.

## Self-Review

- **Spec coverage (§3–§4):** helper (Task 2); painel por título + vazio (Task 3); lista por nome + grupos/vazios/drag off/concluídos/limpar-ao-adicionar/vazio (Task 4); a11y + docs donos (Tasks 1 e 5). ✔
- **Placeholders:** nenhum "TBD"; todos os passos têm código/teste reais e comandos executáveis.
- **Type consistency:** `contemBusca(String, String)` nasce na Task 2 e é consumida nas Tasks 3/4; `AppStrings.buscar/buscarLista/buscarItem/limparBusca/nenhumaListaEncontrada/nenhumItemEncontrado/buscaSemResultadoDica` nascem na Task 3 e são usadas na Task 4; `_ListaItens.consulta`/`onLimparBusca` e `_CampoAdicionar.onItemAdicionado` são definidos e consumidos no mesmo arquivo (Task 4).
- **Riscos:** (a) `PainelListas` vira stateful — os testes existentes do painel/compartilhadas devem seguir verdes (só ganham a lupa); (b) `_ListaItens` ganha `consulta` — os testes existentes continuam passando porque a busca fica fechada por padrão (`consulta` vazia = sem filtro); (c) o campo de busca é `AppCampoTexto` no topo do corpo (não no `title` da AppBar) para não estourar a altura.
