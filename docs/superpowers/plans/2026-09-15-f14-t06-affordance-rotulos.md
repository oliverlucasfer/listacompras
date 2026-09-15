# F14-T06 — Affordance e rótulos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tornar as ações do card de lista descubríveis por `⋮` (com o long-press virando atalho para o mesmo menu), corrigir o rótulo do editor de item e distinguir "Copiar link" de "Copiar código" no sheet Convidar.

**Architecture:** Tudo em UI (`lib/features/listas`, `lib/features/convites`), sem schema/RLS/IA/sync. O `⋮` do card usa `PopupMenuButton` e o long-press chama `PopupMenuButtonState.showButtonMenu()` — o mesmo menu, sem duplicar itens. O "Sair da lista" do card reaproveita a lógica já existente na tela de membros, extraída para um helper compartilhado.

**Tech Stack:** Flutter 3.44 · flutter_riverpod 3 · go_router 18 · Drift · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-14-ux-acessibilidade-design.md` (§8)

**Tarefa dona:** F14-T06 em `docs/14-tarefas.md` · Docs normativos: [10 §2.1/§3](../../10-wireframes-telas.md), [05 §6.2/§6.3](../../05-app-flutter.md), [08 §8](../../08-compartilhamento-colaborativo.md), [15 §4](../../15-design-system.md)

## Global Constraints

- Comentários no código apenas quando indispensáveis (um comentário curto de "porquê" onde há regra/UX — siga o estilo vizinho). `camelCase` (Dart); strings pt-BR centralizadas em `lib/core/l10n/app_strings.dart`.
- Testes: nome `deve_<resultado>_quando_<condição>`.
- **Não alterar schema/RLS/IA nem o contrato de sync.** Nenhuma mudança de repositório nesta fase.
- `tooltip` em todo `IconButton`/`PopupMenuButton` ([15 §4](../../15-design-system.md)).
- Swipe dos itens: **sem mudança** (decisão da spec §8).
- Rodar antes de fechar: `dart format .` e `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (segure os commits; a validação fecha a tarefa).

---

### Task 1: Helper `confirmarSairDaLista` (refatoração, sem mudança de comportamento)

**Files:**
- Create: `lib/features/convites/ui/acao_sair_da_lista.dart`
- Modify: `lib/features/convites/ui/tela_membros_screen.dart` (método `_confirmarSair` linhas ~123-146 e o `TextButton` do AppBar linhas ~172-176)
- Test: `test/features/convites/tela_membros_screen_test.dart` (regressão — nenhum teste novo)

**Interfaces:**
- Produces: `Future<void> confirmarSairDaLista(BuildContext context, WidgetRef ref, String listaId)` — mostra `AppDialog.confirmarDestrutivo` (`sairListaTitulo`/`sairListaMensagem`/`sairDaLista`); ao confirmar chama `sairDaLista`, `papelRepository.remover`, `syncBootstrap.perderAcessoLocal()` e navega a `/compartilhadas`; erros viram `mostrarSnackBar`. Consumido pela Task 2 (card) e pela tela de membros.

- [ ] **Step 1: Verificar a linha de base**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: PASS (11 testes) — é a evidência de que a refatoração não muda comportamento.

- [ ] **Step 2: Criar o helper** — `lib/features/convites/ui/acao_sair_da_lista.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../sync/providers/sync_providers.dart';
import '../domain/convite.dart';
import '../providers/convites_providers.dart';
import '../providers/papel_providers.dart';

/// Confirma e executa "sair da lista" (doc 08 §5, F14-T06): usado pelo menu
/// da tela de membros e pelo menu do card de Compartilhadas.
Future<void> confirmarSairDaLista(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final confirmou = await AppDialog.confirmarDestrutivo(
    context,
    titulo: AppStrings.sairListaTitulo,
    mensagem: AppStrings.sairListaMensagem,
    confirmar: AppStrings.sairDaLista,
  );
  if (!confirmou || !context.mounted) return;
  final repoConvites = ref.read(convitesRepositoryProvider);
  final repoPapeis = ref.read(papelRepositoryProvider);
  try {
    await repoConvites.sairDaLista(listaId);
    repoPapeis.remover(listaId);
    // Belt-and-suspenders (doc 08 §5, F7-T07): o Realtime pode filtrar o
    // DELETE do próprio usuário — limpa o cache local explicitamente.
    unawaited(ref.read(syncBootstrapProvider).perderAcessoLocal());
    if (context.mounted) context.go('/compartilhadas');
  } on ErroConvite catch (e) {
    if (context.mounted) mostrarSnackBar(context, e.message);
  } catch (_) {
    if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
  }
}
```

- [ ] **Step 3: Usar o helper na tela de membros** — `lib/features/convites/ui/tela_membros_screen.dart`

Adicionar o import:

```dart
import 'acao_sair_da_lista.dart';
```

Trocar o `TextButton` do AppBar (linhas ~172-176) por:

```dart
            if (membrosAsync.hasValue && !_eDono(membrosAsync, usuarioId))
              TextButton(
                onPressed: () => confirmarSairDaLista(context, ref, listaId),
                child: const Text(AppStrings.sairDaLista),
              ),
```

**Apagar** o método `_confirmarSair` inteiro (linhas ~123-146).

**Remover imports que ficaram órfãos** (o `flutter analyze` do Step 4 confirma): provavelmente `dart:async` (não há mais `unawaited`), `package:go_router/go_router.dart` (não há mais `context.go`) e `../../sync/providers/sync_providers.dart`. **Não** remova imports ainda usados (`app_snack_bar`, `app_dialog`, `domain/convite`, providers de convites/papel).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter analyze`
Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: analyze "No issues found!"; os 11 testes de membros verdes (incluindo `deve_sair_da_lista_quando_seleciona_e_confirma`, que verifica o bootstrap e a navegação).

---

### Task 2: `⋮` no card + long-press abrindo o mesmo menu

**Files:**
- Modify: `lib/features/listas/ui/painel_listas.dart` (classe `_CardLista`, linhas ~137-241; imports)
- Test: `test/features/listas/minhas_listas_screen_test.dart`
- Test: `test/features/listas/compartilhadas_screen_test.dart`

**Interfaces:**
- Consumes: `confirmarSairDaLista(context, ref, listaId)` da Task 1.
- Produces: `_CardLista` vira `ConsumerStatefulWidget` com `PopupMenuButton<String>` (`key: _menuKey`, `tooltip: AppStrings.menu`, `icon: Icons.more_vert`); `onLongPress` chama `_menuKey.currentState?.showButtonMenu()`. Itens: Minhas → `renomear`/`excluir`; Compartilhadas → `membros`/`sair`.

- [ ] **Step 1: Escrever os testes que falham** em `test/features/listas/minhas_listas_screen_test.dart` (antes do fecho de `main`)

```dart
  testWidgets('deve_renomear_lista_quando_toca_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Antigo', donoId: 'user-a');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.renomear));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Novo',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Antigo'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_tooltip_no_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await abrirTela(tester);

    expect(find.byTooltip(AppStrings.menu), findsOneWidget);
    await fechar(tester);
  });
```

Em `test/features/listas/compartilhadas_screen_test.dart`, **substituir** o teste `deve_abrir_membros_quando_long_press_em_compartilhada` (linhas ~124-139) por:

```dart
  testWidgets('deve_abrir_membros_quando_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Do parceiro',
      donoId: 'user-a',
    );

    await abrirTela(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.membros));
    await tester.pumpAndSettle();

    expect(find.text('membros-${lista.id}'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_pedir_confirmacao_ao_sair_pelo_menu_do_card', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-a');

    await abrirTela(tester);
    await tester.longPress(find.text('Do parceiro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.sairDaLista));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sairListaMensagem), findsOneWidget);
    await fechar(tester);
  });
```

(O confirm-and-leave é coberto pela Task 1 em `tela_membros_screen_test`; aqui só a fiação do card.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: FAIL (`Icons.more_vert` não existe no card; o menu de membros não abre).

- [ ] **Step 3: Implementar** — em `lib/features/listas/ui/painel_listas.dart`

Adicionar o import:

```dart
import '../../convites/ui/acao_sair_da_lista.dart';
```

Substituir a classe `_CardLista` (linhas ~137-241) por:

```dart
class _CardLista extends ConsumerStatefulWidget {
  const _CardLista({required this.contagem});

  final ListaComContagem contagem;

  @override
  ConsumerState<_CardLista> createState() => _CardListaState();
}

class _CardListaState extends ConsumerState<_CardLista> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) {
    final lista = widget.contagem.lista;
    final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/lista/${lista.id}'),
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        title: Text(
          lista.titulo,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.contagem.contagem),
              Text(
                '${AppStrings.atualizada} ${tempoRelativo(lista.atualizadoEm, agora: DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: _menuKey,
          tooltip: AppStrings.menu,
          icon: const Icon(Icons.more_vert),
          onSelected: _acaoMenu,
          itemBuilder: (context) =>
              ehDono ? _itensDono(context) : _itensMembro(),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _itensDono(BuildContext context) => [
    const PopupMenuItem(value: 'renomear', child: Text(AppStrings.renomear)),
    PopupMenuItem(
      value: 'excluir',
      child: Text(
        AppStrings.excluir,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  ];

  List<PopupMenuEntry<String>> _itensMembro() => const [
    PopupMenuItem(value: 'membros', child: Text(AppStrings.membros)),
    PopupMenuItem(value: 'sair', child: Text(AppStrings.sairDaLista)),
  ];

  void _acaoMenu(String acao) {
    final listaId = widget.contagem.lista.id;
    switch (acao) {
      case 'renomear':
        _abrirSheetRenomear();
      case 'excluir':
        _confirmarExclusao();
      case 'membros':
        context.push('/membros/$listaId');
      case 'sair':
        confirmarSairDaLista(context, ref, listaId);
    }
  }

  void _abrirSheetRenomear() {
    abrirSheetTitulo(
      context,
      titulo: AppStrings.renomearLista,
      rotuloBotao: AppStrings.salvar,
      valorInicial: widget.contagem.lista.titulo,
      mensagemSucesso: AppStrings.listaRenomeada,
      onSalvar: (nome) => ref
          .read(listasRepositoryProvider)
          .renomearLista(id: widget.contagem.lista.id, titulo: nome),
    );
  }

  Future<void> _confirmarExclusao() async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirLista,
      mensagem: AppStrings.excluirListaMensagem,
    );
    if (confirmou) {
      await ref
          .read(listasRepositoryProvider)
          .excluirLista(widget.contagem.lista.id);
    }
  }
}
```

**Remover o import `'../../../core/widgets/app_sheet.dart'`** se o `flutter analyze` acusar que ficou órfão (o antigo `_abrirAcoes` era o único uso de `AppSheet`).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/compartilhadas_screen_test.dart`
Expected: PASS (os testes de long-press existentes continuam passando: o long-press abre o mesmo menu).

---

### Task 3: Editor de item com o rótulo "Nome do item"

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (adicionar `nomeDoItem`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (linha ~804, `_DialogoEditarItemState.build`)
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `AppStrings.nomeDoItem = 'Nome do item'` — usado como `label` do campo de nome no editor; a entrada rápida mantém `AppStrings.adicionarItem` ("Adicionar item").

- [ ] **Step 1: Escrever o teste que falha** em `test/features/listas/tela_lista_screen_test.dart` (perto de `deve_editar_e_remover_quando_tocar_no_item`, linha ~338)

```dart
  testWidgets('deve_rotular_nome_do_item_quando_abre_editor', (tester) async {
    await listaComItens(tester);

    // Entrada rápida mantém "Adicionar item".
    expect(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      findsOneWidget,
    );

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);
    expect(
      find.widgetWithText(TextField, AppStrings.nomeDoItem),
      findsOneWidget,
    );

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_rotular_nome_do_item_quando_abre_editor`
Expected: FAIL (`AppStrings.nomeDoItem` não existe / o editor usa "Adicionar item").

- [ ] **Step 3: Adicionar a string** em `lib/core/l10n/app_strings.dart` (seção "Tela da Lista", ao lado de `editarItem`)

```dart
  static const nomeDoItem = 'Nome do item';
```

- [ ] **Step 4: Implementar** — em `lib/features/listas/ui/tela_lista_screen.dart` (linha ~804)

```dart
            AppCampoTexto(controller: _nome, label: AppStrings.nomeDoItem),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (todos os testes da tela; a entrada rápida continua com "Adicionar item").

---

### Task 4: "Copiar link" × "Copiar código" com tooltips no sheet Convidar

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (renomear `copiarToken`→`copiarCodigo`, `tokenCopiado`→`codigoCopiado`; adicionar `copiarLinkAjuda`, `copiarCodigoAjuda`)
- Modify: `lib/features/convites/ui/sheet_convidar.dart` (botões linhas ~139-165)
- Modify: `docs/08-compartilhamento-colaborativo.md` (§8, linha ~241)
- Test: `test/features/convites/sheet_convidar_test.dart`

**Interfaces:**
- Produces: `copiarCodigo = 'Copiar código'`, `codigoCopiado = 'Código copiado para a área de transferência.'`, `copiarLinkAjuda`, `copiarCodigoAjuda`. Os dois botões ficam envoltos em `Tooltip`; o de link copia `linkConvite(token)`, o de código copia o `token` cru.

- [ ] **Step 1: Atualizar/criar os testes que falham** em `test/features/convites/sheet_convidar_test.dart`

No teste `deve_gerar_link_quando_escolhe_papel_e_confirma`, logo após a asserção de `AppStrings.compartilhar`, acrescentar os tooltips:

```dart
    expect(find.byTooltip(AppStrings.copiarLinkAjuda), findsOneWidget);
    expect(find.byTooltip(AppStrings.copiarCodigoAjuda), findsOneWidget);
```

Substituir o teste `deve_copiar_token_cru_quando_tocar_copiar_token` (linhas ~216-258) por:

```dart
  testWidgets('deve_copiar_codigo_quando_tocar_copiar_codigo', (tester) async {
    String? copiado;
    final canal = SystemChannels.platform;
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(canal.name, (
      data,
    ) async {
      final conteudo = const JSONMessageCodec().decodeMessage(data);
      if (conteudo is Map && conteudo['method'] == 'Clipboard.setData') {
        copiado = conteudo['args']['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        canal.name,
        null,
      ),
    );

    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.copiarCodigo),
    );
    await tester.pumpAndSettle();

    // Código cru, sem scheme da deep link.
    expect(copiado, _token);
    expect(find.text(AppStrings.codigoCopiado), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/sheet_convidar_test.dart`
Expected: FAIL (`copiarCodigo`/`codigoCopiado`/`copiarLinkAjuda` não existem).

- [ ] **Step 3: Adicionar/renomear as strings** em `lib/core/l10n/app_strings.dart` (seção "Sheet Convidar e tela de membros")

Trocar `copiarToken` por:

```dart
  static const copiarCodigo = 'Copiar código';
  static const copiarLinkAjuda =
      'Copia o endereço completo para enviar por onde quiser.';
  static const copiarCodigoAjuda =
      'Copia só o código, para colar em "Entrar com código".';
```

Trocar `tokenCopiado` por:

```dart
  static const codigoCopiado = 'Código copiado para a área de transferência.';
```

- [ ] **Step 4: Implementar** — em `lib/features/convites/ui/sheet_convidar.dart` (linhas ~139-165)

```dart
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: AppStrings.copiarLinkAjuda,
                    child: AppBotao(
                      rotulo: AppStrings.copiarLink,
                      variante: AppBotaoVariante.outlined,
                      icone: Icons.copy_outlined,
                      onPressed: () => _copiar(
                        ref
                            .read(convitesRepositoryProvider)
                            .linkConvite(convite.token),
                        AppStrings.linkCopiado,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Tooltip(
                    message: AppStrings.copiarCodigoAjuda,
                    child: AppBotao(
                      rotulo: AppStrings.copiarCodigo,
                      variante: AppBotaoVariante.outlined,
                      icone: Icons.copy_outlined,
                      onPressed: () =>
                          _copiar(convite.token, AppStrings.codigoCopiado),
                    ),
                  ),
                ),
              ],
            ),
```

- [ ] **Step 5: Atualizar o doc 08 §8** (linha ~241, tabela "UI necessária")

Trocar a linha do sheet por:

```
| Sheet "Convidar" (dono/editor) | Escolha de papel + gerar link; o link completo e o código têm botões distintos ("Copiar link" × "Copiar código", com tooltip) (F14-T06) |
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/convites/sheet_convidar_test.dart`
Expected: PASS (os testes de copiar link e o novo de copiar código).

---

### Task 5: Docs (10), marcar a tarefa e validação final

**Files:**
- Modify: `docs/10-wireframes-telas.md` (linha ~76, nota de navegação das Compartilhadas)
- Modify: `docs/14-tarefas.md` (F14-T06 + progresso)

- [ ] **Step 1: Doc 10 §2** — na nota de navegação (linha ~76), a Compartilhadas tem o parentético "(long-press leva aos membros para sair da lista)". Trocar por:

```
(o menu `⋮` do card abre Membros e Sair da lista; o long-press abre o mesmo menu)
```

- [ ] **Step 2: Doc 14** — marcar F14-T06 (linhas 368-370) e atualizar o progresso

```markdown
- [x] **F14-T06** — Affordance e rótulos
  Dep: F14-T00 · Docs: [10 §2.1/§3](10-wireframes-telas.md), [05 §6.2/§6.3](05-app-flutter.md)
  CP: `⋮` no card com as ações do contexto (long-press abre o mesmo menu); rótulo "Nome do item" no editor; "Copiar link" × "Copiar código" distinguidos; testes verdes.
  *(card com `PopupMenuButton` `⋮` (Minhas: Renomear/Excluir; Compartilhadas: Membros/Sair) e long-press via `showButtonMenu`; "Sair da lista" extraído para `confirmarSairDaLista` (reuso tela de membros/card); editor de item com "Nome do item" (entrada rápida segue "Adicionar item"); sheet Convidar com "Copiar código" + tooltips nos dois botões e doc 08 §8 atualizado)*
```

Na tabela de progresso:

```markdown
| F14 Acessibilidade & UX | 10 | 7 |
```

E o total:

```markdown
| **Total** | **97** | **92** |
```

- [ ] **Step 3: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações; analyze "No issues found!"; toda a suíte verde.

- [ ] **Step 4: Commit (somente com confirmação do usuário)**

```bash
git add lib test docs
git commit -m "F14-T06: menu no card, rotulo do editor e copiar codigo (RNF-06)"
```

> **Nota:** não commitar sem confirmação explícita. Se o usuário autorizar, decidir o agrupamento com ele.

## Self-Review

- **Spec coverage (§8):** card `⋮` + long-press no mesmo menu (Task 2); "Nome do item" (Task 3); "Copiar link"/"Copiar código" + tooltips (Task 4); swipe inalterado (nenhuma task toca). ✔
- **Placeholders:** nenhum "TBD"; todos os passos têm código/teste reais.
- **Type consistency:** `confirmarSairDaLista(BuildContext, WidgetRef, String)` definido na Task 1 e consumido na Task 2 e na tela de membros com a mesma assinatura; `_menuKey` é `GlobalKey<PopupMenuButtonState<String>>` e `PopupMenuButton<String>` usa a mesma chave; strings `nomeDoItem`, `copiarCodigo`, `codigoCopiado`, `copiarLinkAjuda`, `copiarCodigoAjuda` nascem nas Tasks 3/4 e são usadas no mesmo diff.
- **Risco:** `confirmarSairDaLista` lê `syncBootstrapProvider`/`convitesRepositoryProvider` só depois da confirmação — por isso o teste do card (Task 2) só verifica a abertura do diálogo, sem overrides frágeis; o caminho confirmado já é coberto por `tela_membros_screen_test`.
