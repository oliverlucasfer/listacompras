# F14-T05 — Feedback de ação — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar retorno visual às ações hoje silenciosas (reenviar link, compartilhar convite, mudar papel, remover membro, criar/renomear lista), oferecer undo em "limpar concluídos" e confirmação destrutiva ao sair da conta.

**Architecture:** Toda a mudança é de app (UI + uma assinatura de repositório) sobre o `mostrarSnackBar` já existente (`lib/core/widgets/app_snack_bar.dart`, durações 2s/3s da F12-T07) e o `AppDialog.confirmarDestrutivo` (`lib/core/widgets/app_dialog.dart`). Os SnackBars entram onde a ação não tem efeito imediato sob o dedo (spec §7): criar/renomear lista, convites/membros, reenvio de e-mail, limpar concluídos e sair. Marcar/desmarcar item fica de fora.

**Tech Stack:** Flutter 3.44 · flutter_riverpod 3 · Drift · go_router 18 · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-14-ux-acessibilidade-design.md` (§7)

**Tarefa dona:** F14-T05 em `docs/14-tarefas.md` · Docs normativos: [05 §6.1/§6.2/§6.3](../../05-app-flutter.md), [08 §5/§8](../../08-compartilhamento-colaborativo.md), [15 §3](../../15-design-system.md)

## Global Constraints

- Comentários no código apenas quando indispensáveis (o padrão do repo é um comentário curto explicando o "porquê" quando há regra de negócio/UX — siga o estilo vizinho). Nomes `camelCase` (Dart); strings pt-BR centralizadas em `lib/core/l10n/app_strings.dart`.
- Testes: nome `deve_<resultado>_quando_<condição>`.
- **Não alterar schema/RLS/IA nem o contrato de sync**; a única mudança de assinatura é `ListasRepository.limparConcluidos` (passa a devolver a lista removida — uso local, sem tocar no payload).
- Reusar `mostrarSnackBar` (não criar `SnackBar` cru). Reusar `AppDialog.confirmarDestrutivo`.
- Rodar antes de fechar: `dart format .` e `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (segure os commits; a validação fecha a tarefa). O passo de commit é único, no fim (Task 6).
- Mensagens de erro das ações reusam `AppStrings.erroGenerico` (o padrão atual dos `catch`).

---

### Task 1: Strings novas + feedback ao reenviar link (registro)

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/auth/ui/registro_screen.dart` (classe `_VerificacaoEmail`, linhas ~184-247)
- Test: `test/features/auth/registro_screen_test.dart`

**Interfaces:**
- Produces: strings `linkReenviado`, `listaCriada`, `listaRenomeada`, `concluidosRemovidos`, `linkCompartilhado`, `papelAtualizado`, `membroRemovido`, `sairContaTitulo`, `sairContaMensagem` (consumidas nas Tasks 2-5).
- Produces: `_VerificacaoEmail` vira `ConsumerStatefulWidget` com estado `_reenviando` (comportamento: botão desabilita durante o envio — doc 05 §6.1).

- [ ] **Step 1: Adicionar as strings novas** em `lib/core/l10n/app_strings.dart`

Na seção de Autenticação, logo abaixo de `reenviarLink`:

```dart
  static const linkReenviado = 'Link reenviado.';
```

Na seção "Painel Minhas Listas", logo abaixo de `renomearLista`:

```dart
  static const listaCriada = 'Lista criada.';
  static const listaRenomeada = 'Lista renomeada.';
```

Na seção "Ações em massa", logo abaixo de `limparConcluidosMensagem`:

```dart
  static const concluidosRemovidos = 'Itens concluídos removidos.';
```

Na seção "Sheet Convidar e tela de membros", logo abaixo de `tokenCopiado`:

```dart
  static const linkCompartilhado = 'Link compartilhado.';
  static const papelAtualizado = 'Papel atualizado.';
  static const membroRemovido = 'Membro removido.';
```

Na seção "Configurações", logo abaixo de `sair` (ou ao lado dele):

```dart
  static const sairContaTitulo = 'Sair da conta?';
  static const sairContaMensagem =
      'Você precisará entrar novamente para acessar suas listas.';
```

- [ ] **Step 2: Escrever os testes que falham** em `test/features/auth/registro_screen_test.dart` (antes do fecho de `main`)

```dart
  testWidgets('deve_mostrar_snackbar_quando_reenviar_link', (tester) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    repo.onReenviar = (email) async {};
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.reenviarLink),
    );
    await tester.pumpAndSettle();

    expect(repo.reenvioChamado, isTrue);
    expect(find.text(AppStrings.linkReenviado), findsOneWidget);
  });

  testWidgets('deve_mostrar_erro_quando_reenviar_link_falha', (tester) async {
    final repo = FakeAuthRepository();
    repo.onRegistrar = (email, senha) => Future.value(AuthResponse());
    repo.onReenviar = (email) async => throw Exception('offline');
    await abrirTela(tester, repo);
    await preencherFormulario(tester, 'a@b.com', '123456', '123456');
    await aceitarPolitica(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.reenviarLink),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroGenerico), findsOneWidget);
  });
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/auth/registro_screen_test.dart --plain-name deve_mostrar_snackbar_quando_reenviar_link`
Expected: FAIL (não encontra `AppStrings.linkReenviado` e o botão não dá retorno).

- [ ] **Step 4: Implementar** — em `lib/features/auth/ui/registro_screen.dart`

Adicionar import:

```dart
import '../../../core/widgets/app_snack_bar.dart';
```

Trocar a classe `_VerificacaoEmail` (e o `State`) por:

```dart
/// Tela "Verifique seu e-mail" (wireframe 10 §1.2) com reenvio de link.
class _VerificacaoEmail extends ConsumerStatefulWidget {
  const _VerificacaoEmail({required this.email, this.next});

  final String email;
  final String? next;

  @override
  ConsumerState<_VerificacaoEmail> createState() => _VerificacaoEmailState();
}

class _VerificacaoEmailState extends ConsumerState<_VerificacaoEmail> {
  bool _reenviando = false;

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .reenviarVerificacao(widget.email);
      if (mounted) mostrarSnackBar(context, AppStrings.linkReenviado);
    } catch (_) {
      if (mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.verificarSeuEmail)),
      body: Center(
        child: Padding(
          padding: AppSpacing.tela,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_unread,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.verificarEmailMensagem,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppBotao(
                  rotulo: AppStrings.reenviarLink,
                  variante: AppBotaoVariante.outlined,
                  carregando: _reenviando,
                  onPressed: _reenviar,
                ),
                AppBotao(
                  rotulo: AppStrings.entrar,
                  variante: AppBotaoVariante.texto,
                  onPressed: () => context.go(
                    widget.next == null || widget.next!.isEmpty
                        ? '/login'
                        : Uri.parse('/login')
                              .replace(
                                queryParameters: {'next': widget.next!},
                              )
                              .toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/auth/registro_screen_test.dart`
Expected: PASS (8 testes).

---

### Task 2: Feedback ao compartilhar convite e nas ações de membros

**Files:**
- Modify: `lib/features/convites/ui/sheet_convidar.dart` (botão "Compartilhar", linhas ~167-178)
- Modify: `lib/features/convites/ui/tela_membros_screen.dart` (`_mudarPapel` linhas ~79-98; `_confirmarRemover` linhas ~100-121)
- Test: `test/features/convites/sheet_convidar_test.dart`
- Test: `test/features/convites/tela_membros_screen_test.dart`

**Interfaces:**
- Consumes: strings `linkCompartilhado`, `papelAtualizado`, `membroRemovido` (Task 1).

- [ ] **Step 1: Escrever o teste que falha** em `test/features/convites/sheet_convidar_test.dart` (antes do fecho de `main`)

```dart
  testWidgets('deve_mostrar_snackbar_ao_compartilhar_link', (tester) async {
    final canal = const MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      canal,
      (call) async => 'ok',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
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
      find.widgetWithText(OutlinedButton, AppStrings.compartilhar),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.linkCompartilhado), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/sheet_convidar_test.dart --plain-name deve_mostrar_snackbar_ao_compartilhar_link`
Expected: FAIL (nenhum SnackBar após compartilhar).

- [ ] **Step 3: Implementar** — em `lib/features/convites/ui/sheet_convidar.dart`

Trocar o `onPressed` do botão "Compartilhar":

```dart
            AppBotao(
              rotulo: AppStrings.compartilhar,
              variante: AppBotaoVariante.outlined,
              icone: Icons.share_outlined,
              onPressed: () => _compartilhar(convite),
            ),
```

Adicionar o método (junto de `_copiar`):

```dart
  Future<void> _compartilhar(Convite convite) async {
    await SharePlus.instance.share(
      ShareParams(
        text: ref.read(convitesRepositoryProvider).linkConvite(convite.token),
      ),
    );
    if (mounted) mostrarSnackBar(context, AppStrings.linkCompartilhado);
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/sheet_convidar_test.dart`
Expected: PASS (6 testes).

- [ ] **Step 5: Escrever as asserções que falham** em `test/features/convites/tela_membros_screen_test.dart`

No teste `deve_mudar_papel_quando_dono_escolhe`, após a checagem do corpo do PATCH:

```dart
    expect(find.text(AppStrings.papelAtualizado), findsOneWidget);
```

No teste `deve_remover_membro_apos_confirmacao`, após `expect(find.text('U2'), findsNothing);`:

```dart
    expect(find.text(AppStrings.membroRemovido), findsOneWidget);
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: FAIL (`papelAtualizado`/`membroRemovido` não aparecem).

- [ ] **Step 7: Implementar** — em `lib/features/convites/ui/tela_membros_screen.dart`

Em `_mudarPapel`, trocar o `try`:

```dart
    try {
      await repo.mudarPapel(
        listaId: listaId,
        userId: membro.userId,
        papel: papel,
      );
      ref.invalidate(membrosDaListaProvider(listaId));
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.papelAtualizado);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
```

Em `_confirmarRemover`, trocar o `try`:

```dart
    try {
      await repo.removerMembro(listaId: listaId, userId: membro.userId);
      ref.invalidate(membrosDaListaProvider(listaId));
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.membroRemovido);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
```

- [ ] **Step 8: Rodar e ver passar**

Run: `flutter test test/features/convites/tela_membros_screen_test.dart`
Expected: PASS (11 testes).

---

### Task 3: Feedback ao criar/renomear lista (2s)

**Files:**
- Modify: `lib/features/listas/ui/sheet_titulo_lista.dart` (parâmetro novo + SnackBar no `_salvar`)
- Modify: `lib/features/listas/ui/painel_listas.dart` (`_abrirSheetRenomear` linha ~211, `abrirSheetNovaLista` linha ~324)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (ação `'renomear'` no `_acaoMenu` linha ~89)
- Test: `test/features/listas/minhas_listas_screen_test.dart`
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Consumes: strings `listaCriada`, `listaRenomeada` (Task 1).
- Produces: `SheetTituloLista({required titulo, required rotuloBotao, required onSalvar, valorInicial, mensagemSucesso})` e `abrirSheetTitulo(..., mensagemSucesso)` — quando `mensagemSucesso != null`, mostra o SnackBar antes de fechar o sheet.

- [ ] **Step 1: Escrever as asserções que falham** em `test/features/listas/minhas_listas_screen_test.dart`

No teste `deve_criar_lista_quando_sheet_preenchido_e_salvo`, após `expect(find.text(AppStrings.nenhumaLista), findsNothing);`:

```dart
    expect(find.text(AppStrings.listaCriada), findsOneWidget);
```

No teste `deve_renomear_lista_quando_long_press_e_sheet_salvo`, após `expect(find.text('Antigo'), findsNothing);`:

```dart
    expect(find.text(AppStrings.listaRenomeada), findsOneWidget);
```

Em `test/features/listas/tela_lista_screen_test.dart`, no teste `deve_renomear_lista_quando_menu`, após `expect(find.text('Compras da Semana'), findsNothing);`:

```dart
    expect(find.text(AppStrings.listaRenomeada), findsOneWidget);
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: FAIL (`listaCriada`/`listaRenomeada` não aparecem).

- [ ] **Step 3: Implementar** — em `lib/features/listas/ui/sheet_titulo_lista.dart`

Adicionar import:

```dart
import '../../../core/widgets/app_snack_bar.dart';
```

Adicionar o campo em `SheetTituloLista`:

```dart
  final String? mensagemSucesso;
```

No construtor:

```dart
  const SheetTituloLista({
    super.key,
    required this.titulo,
    required this.rotuloBotao,
    required this.onSalvar,
    this.valorInicial,
    this.mensagemSucesso,
  });
```

Trocar o `try` do `_salvar`:

```dart
    try {
      await widget.onSalvar(nome);
      if (mounted) {
        final mensagem = widget.mensagemSucesso;
        if (mensagem != null) {
          mostrarSnackBar(context, mensagem);
        }
        Navigator.pop(context);
      }
    } catch (_) {
```

No helper `abrirSheetTitulo`, adicionar o parâmetro e repassá-lo:

```dart
Future<void> abrirSheetTitulo(
  BuildContext context, {
  required String titulo,
  required String rotuloBotao,
  required Future<void> Function(String nome) onSalvar,
  String? valorInicial,
  String? mensagemSucesso,
}) {
  return AppSheet.mostrar<void>(
    context,
    child: SheetTituloLista(
      titulo: titulo,
      rotuloBotao: rotuloBotao,
      valorInicial: valorInicial,
      mensagemSucesso: mensagemSucesso,
      onSalvar: onSalvar,
    ),
  );
}
```

- [ ] **Step 4: Implementar** — nos chamadores

Em `lib/features/listas/ui/painel_listas.dart`, `_abrirSheetRenomear`:

```dart
    abrirSheetTitulo(
      context,
      titulo: AppStrings.renomearLista,
      rotuloBotao: AppStrings.salvar,
      valorInicial: contagem.lista.titulo,
      mensagemSucesso: AppStrings.listaRenomeada,
      onSalvar: (nome) => ref
          .read(listasRepositoryProvider)
          .renomearLista(id: contagem.lista.id, titulo: nome),
    );
```

Em `abrirSheetNovaLista` (mesmo arquivo):

```dart
  return abrirSheetTitulo(
    context,
    titulo: AppStrings.novaLista,
    rotuloBotao: AppStrings.criarLista,
    mensagemSucesso: AppStrings.listaCriada,
    onSalvar: (nome) async {
```

Em `lib/features/listas/ui/tela_lista_screen.dart`, no `case 'renomear'`:

```dart
      case 'renomear':
        abrirSheetTitulo(
          context,
          titulo: AppStrings.renomearLista,
          rotuloBotao: AppStrings.salvar,
          mensagemSucesso: AppStrings.listaRenomeada,
          onSalvar: (nome) => repo.renomearLista(id: idLista, titulo: nome),
        );
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/minhas_listas_screen_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

---

### Task 4: Undo ao "limpar concluídos" (restaura `id`/`ordem`)

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (`limparConcluidos`, linhas ~331-356)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_confirmarLimparConcluidos`, linhas ~105-119)
- Test: `test/features/listas/listas_repository_test.dart`
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `Future<List<Item>> ListasRepository.limparConcluidos(String listaId)` — devolve os itens removidos (`id`, `ordem` e demais campos intactos) para o undo.
- Consumes: `Item` (`lib/features/listas/domain/item.dart`), `Item.fromLocal`, e `restaurarItem(id)` (já existente) — restaurar não altera `ordem`.

- [ ] **Step 1: Escrever os testes que falham** em `test/features/listas/listas_repository_test.dart` (perto do teste de limpar existente, linha ~294)

```dart
  test('deve_devolver_itens_removidos_quando_limpar_concluidos', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.editarItem(i1.id, concluido: true);
    await repo.editarItem(i3.id, concluido: true);

    final removidos = await repo.limparConcluidos(lista.id);

    expect(removidos.map((i) => i.id).toSet(), {i1.id, i3.id});
    expect(removidos.map((i) => i.ordem).toSet(), {i1.ordem, i3.ordem});
    expect(removidos, hasLength(2));
    expect(removidos.every((i) => i.listaId == lista.id), isTrue);
    expect(removidos.map((i) => i.id), isNot(contains(i2.id)));
  });

  test('deve_restaurar_id_e_ordem_quando_undo_do_limpar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.editarItem(i1.id, concluido: true);
    await repo.editarItem(i3.id, concluido: true);

    final removidos = await repo.limparConcluidos(lista.id);
    for (final item in removidos) {
      await repo.restaurarItem(item.id);
    }

    final ativos = await (db.select(db.itemLocal)
          ..where((i) => i.listaId.equals(lista.id) & i.deletadoEm.isNull()))
        .get();
    final ordens = {for (final i in ativos) i.id: i.ordem};
    expect(ordens, {i1.id: i1.ordem, i2.id: i2.ordem, i3.id: i3.ordem});
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/listas_repository_test.dart --plain-name deve_devolver_itens_removidos_quando_limpar_concluidos`
Expected: FAIL (`limparConcluidos` devolve `void`; `removidos` não é iterável).

- [ ] **Step 3: Implementar** — em `lib/features/listas/data/listas_repository.dart`

Trocar a assinatura e o retorno de `limparConcluidos`:

```dart
  /// Remove (soft delete) os concluídos e devolve os itens removidos para o
  /// undo da UI restaurar sem perder `id`/`ordem` (F14-T05).
  Future<List<Item>> limparConcluidos(String listaId) async {
    final concluidos =
        await (_db.select(_db.itemLocal)..where(
              (i) =>
                  i.listaId.equals(listaId) &
                  i.deletadoEm.isNull() &
                  i.concluido.equals(true),
            ))
            .get();
    final agora = DateTime.now().toUtc();
    for (final item in concluidos) {
      await (_db.update(
        _db.itemLocal,
      )..where((i) => i.id.equals(item.id))).write(
        ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
      await _enfileirar(
        tabela: 'itens_lista',
        operacao: 'DELETE_SOFT',
        registroId: item.id,
        listaId: listaId,
        tsLocal: agora,
        payload: await _payloadItem(item.id),
      );
    }
    return concluidos.map(Item.fromLocal).toList();
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Escrever o widget test que falha** em `test/features/listas/tela_lista_screen_test.dart` (perto do teste `deve_limpar_concluidos_quando_confirmar_dialogo`, linha ~459)

```dart
  testWidgets('deve_restaurar_concluidos_quando_desfazer_limpar', (tester) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
    await tester.pumpAndSettle();

    expect(find.text('Detergente'), findsNothing);
    expect(find.text(AppStrings.concluidosRemovidos), findsOneWidget);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_restaurar_concluidos_quando_desfazer_limpar`
Expected: FAIL (nenhum SnackBar de limpar / nada a desfazer).

- [ ] **Step 7: Implementar** — em `lib/features/listas/ui/tela_lista_screen.dart`

Trocar `_confirmarLimparConcluidos` por:

```dart
  Future<void> _confirmarLimparConcluidos(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.limparConcluidos,
      mensagem: AppStrings.limparConcluidosMensagem,
      confirmar: AppStrings.limpar,
    );
    if (!confirmou) return;
    final repo = ref.read(listasRepositoryProvider);
    final removidos = await repo.limparConcluidos(idLista);
    if (!context.mounted || removidos.isEmpty) return;
    mostrarSnackBar(
      context,
      AppStrings.concluidosRemovidos,
      rotuloAcao: AppStrings.desfazer,
      onAcao: () {
        for (final item in removidos) {
          unawaited(repo.restaurarItem(item.id));
        }
      },
    );
  }
```

(`unawaited` já está disponível: `dart:async` é importado no topo do arquivo.)

- [ ] **Step 8: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

---

### Task 5: Confirmação destrutiva ao sair da conta

**Files:**
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (ListTile "Sair", linhas ~98-105)
- Modify: `test/features/auth/fakes.dart` (override de `sair`)
- Test: `test/features/configuracoes/configuracoes_screen_test.dart`

**Interfaces:**
- Consumes: strings `sairContaTitulo`, `sairContaMensagem`, `sair` (Task 1); `AppDialog.confirmarDestrutivo`.
- Produces: `FakeAuthRepository.sairChamado` (bool) + override de `sair()`.

- [ ] **Step 1: Adicionar o espião ao fake** em `test/features/auth/fakes.dart`

No topo da classe `FakeAuthRepository`:

```dart
  bool sairChamado = false;
```

E o override (junto dos demais):

```dart
  @override
  Future<void> sair() async {
    sairChamado = true;
  }
```

- [ ] **Step 2: Escrever os testes que falham** em `test/features/configuracoes/configuracoes_screen_test.dart`

Trocar o topo do arquivo / imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);
```

Adicionar o helper (depois do `abrir` existente) e os testes (antes do fecho de `main`):

```dart
  Future<void> abrirComRouter(
    WidgetTester tester,
    FakeAuthRepository repo,
  ) async {
    final router = GoRouter(
      initialLocation: '/configuracoes',
      routes: [
        GoRoute(
          path: '/configuracoes',
          builder: (_, _) => const ConfiguracoesScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_pedir_confirmacao_quando_sair', (tester) async {
    final repo = FakeAuthRepository();
    await abrirComRouter(tester, repo);

    await tester.tap(find.text(AppStrings.sair));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sairContaMensagem), findsOneWidget);
    expect(repo.sairChamado, isFalse);
  });

  testWidgets('deve_sair_da_conta_quando_confirma', (tester) async {
    final repo = FakeAuthRepository();
    await abrirComRouter(tester, repo);

    await tester.tap(find.text(AppStrings.sair));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.sair));
    await tester.pumpAndSettle();

    expect(repo.sairChamado, isTrue);
    expect(find.text('login'), findsOneWidget);
  });
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: FAIL (sair executa sem diálogo; `AppStrings.sairContaMensagem` não existe no diálogo).

- [ ] **Step 4: Implementar** — em `lib/features/configuracoes/ui/configuracoes_screen.dart`

Trocar o `onTap` do ListTile "Sair":

```dart
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.sair),
            onTap: () => _confirmarSair(context, ref),
          ),
```

E adicionar o método (por exemplo, logo após `_assinar`/antes de `_excluirConta`):

```dart
  Future<void> _confirmarSair(BuildContext context, WidgetRef ref) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.sairContaTitulo,
      mensagem: AppStrings.sairContaMensagem,
      confirmar: AppStrings.sair,
    );
    if (!confirmou || !context.mounted) return;
    await ref.read(authRepositoryProvider).sair();
    if (context.mounted) context.go('/login');
  }
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/configuracoes/configuracoes_screen_test.dart`
Expected: PASS (5 testes).

---

### Task 6: Docs donos + marcar a tarefa + validação final

**Files:**
- Modify: `docs/08-compartilhamento-colaborativo.md` (§8, linha ~249)
- Modify: `docs/10-wireframes-telas.md` (§5, linha ~271)
- Modify: `docs/14-tarefas.md` (F14-T05 + tabela de progresso)

- [ ] **Step 1: Doc 08 §8** — o texto na linha ~249 está no futuro ("os SnackBars de papel/remoção/compartilhamento entram na T05"); trocar por:

```
  * Vazio e feedback (F14-T04/T05): a lista de membros vazia (só acontece sem cache local, ex.: cache apagado) mostra `AppEstadoVazio` **sem ações** — o papel não é confiável nesse estado (o dono é sempre mesclado por `membrosDaListaProvider`); trocar papel, remover membro e compartilhar o convite dão SnackBar (F14-T05, [05 §6.1](../05-app-flutter.md)).
```

- [ ] **Step 2: Doc 10 §5** — após o diagrama das Configurações (linha ~282), adicionar a nota:

```
"**Sair** pede confirmação destrutiva antes de encerrar a sessão (F14-T05).
```

- [ ] **Step 3: Doc 14** — marcar a tarefa e atualizar o histórico

Trocar o cabeçalho de F14-T05 (linha 365-367) por:

```markdown
- [x] **F14-T05** — Feedback de ação
  Dep: F14-T00 · Docs: [05 §6](05-app-flutter.md), [08 §5](08-compartilhamento-colaborativo.md)
  CP: SnackBars de reenviar link/compartilhar/papel/remover membro/criar-renomear lista; undo em "limpar concluídos" (restaura `id`/`ordem`); "Sair" com confirmação destrutiva; testes verdes.
  *(reenviar link com "Link reenviado" + erro amigável e botão desabilitado durante o envio; compartilhar convite com "Link compartilhado"; papel/remoção de membro com SnackBar; criar/renomear lista com SnackBar 2s via `mensagemSucesso` do `SheetTituloLista`; `limparConcluidos` devolve os itens removidos e o SnackBar 3s "Desfazer" restaura `id`/`ordem`; "Sair" via `AppDialog.confirmarDestrutivo`; testes novos/ajustados em auth, convites, listas e configurações)*
```

Na tabela de progresso:

```markdown
| F14 Acessibilidade & UX | 10 | 6 |
```

E o total:

```markdown
| **Total** | **97** | **91** |
```

- [ ] **Step 4: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações; analyze "No issues found!"; toda a suíte verde.

- [ ] **Step 5: Commit (somente com confirmação do usuário)**

```bash
git add lib test docs
git commit -m "F14-T05: feedback de acao, undo e confirmacao ao sair (RNF-06)"
```

> **Nota:** o working tree já contém as F14-T00…T04 (não commitadas). Se o usuário quiser, este commit pode incluir aquelas mudanças — o dono decide o agrupamento. Sem confirmação explícita, **não** commitar.

## Self-Review

- **Spec coverage (§7):** reenviar link (Task 1); compartilhar convite + papel + remover membro (Task 2); criar/renomear (Task 3); limpar com undo (Task 4); sair (Task 5); docs/14 (Task 6). ✔
- **Fora de escopo (§7):** marcar/desmarcar item — sem SnackBar, por decisão registrada na spec. Não implementado. ✔
- **Placeholders:** nenhum "TBD"/"implement later"; todos os passos de código têm o conteúdo real (testes e implementação). Trocar papel já usa `CheckedPopupMenuItem` (sem instrução solta).
- **Type consistency:** `limparConcluidos` devolve `List<Item>` (Task 4) e a UI consome `item.id` + `restaurarItem(id)`; `mensagemSucesso` é `String?` em `SheetTituloLista`/`abrirSheetTitulo` e passado igual nos três chamadores; as 9 strings nascem na Task 1 e são consumidas nas Tasks 2-5 com os mesmos nomes.
- **Risco:** o teste de "compartilhar" depende do mock do `MethodChannel('dev.fluttercommunity.plus/share')` (share_plus 12.x); se o `share` mudar de canal, o teste falha no `pumpAndSettle` — nesse caso, verificar `MethodChannelShare.channel` no pacote e ajustar o handler.
