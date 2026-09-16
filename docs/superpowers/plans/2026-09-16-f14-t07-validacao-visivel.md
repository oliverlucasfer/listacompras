# F14-T07 — Validação visível — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar feedback visível às validações silenciosas (campo "Adicionar item", editor de item e edição inline da importação) e dar paridade de toggle de senha ao registro.

**Architecture:** Tudo em UI Flutter (`lib/features/**/ui` + `lib/core/l10n`), sem schema/RLS/IA/sync. Os erros usam o `erro`/`errorText` dos componentes já existentes (`AppCampoTexto` no editor; `InputDecoration.errorText` nos `TextField` crus da importação, que só migram para `AppCampoTexto` na F14-T08). O estado de erro é local (`ConsumerState`/`State`) e limpa ao digitar; a semântica de gravação existente não muda.

**Tech Stack:** Flutter 3.44 · flutter_riverpod 3 · go_router 18 · Drift · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-14-ux-acessibilidade-design.md` (§9)

**Tarefa dona:** F14-T07 em `docs/14-tarefas.md` · Docs normativos: [05 §6.1/§6.3/§6.4](../../05-app-flutter.md), [15 §3](../../15-design-system.md)

## Global Constraints

- Comentários no código apenas quando indispensáveis (um "porquê" curto onde há regra/UX). `camelCase` (Dart); strings pt-BR centralizadas em `lib/core/l10n/app_strings.dart` — string de UI fora do `AppStrings` é bug.
- Testes: nome `deve_<resultado>_quando_<condição>`.
- **Não alterar schema/RLS/IA/sync nem repositório.** Mudança de comportamento exige atualizar o doc dono (`05`) no mesmo PR.
- **Não** migrar os `TextField` crus da importação para `AppCampoTexto` nesta tarefa (é escopo da F14-T08): adicione apenas `errorText` ao `InputDecoration`.
- Rodar antes de fechar: `dart format .`, `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (segure os commits; a validação fecha a tarefa).

---

### Task 1: Aviso do parser no campo "Adicionar item"

Quando o texto digitado não é vazio mas o parser local descarta tudo (ex.: só pontuação), mostrar erro inline curto em vez de no-op silencioso. Texto vazio continua no-op.

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (seção "Tela da Lista", após `itemAtualizado`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_CampoAdicionarState`, linhas ~355-474)
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `AppStrings.naoEntendiItem = 'Não entendi o item'`.

- [ ] **Step 1: Escrever o teste que falha** em `test/features/listas/tela_lista_screen_test.dart` (logo após `deve_adicionar_item_quando_enter_no_campo`, linha ~219)

```dart
  testWidgets('deve_mostrar_erro_quando_parser_descarta_texto', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      '.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.naoEntendiItem), findsOneWidget);
    // Nada foi adicionado.
    expect(find.text('Mercearia (1)'), findsOneWidget);

    // O erro some ao digitar de novo.
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.pump();
    expect(find.text(AppStrings.naoEntendiItem), findsNothing);

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_mostrar_erro_quando_parser_descarta_texto`
Expected: FAIL (`AppStrings.naoEntendiItem` não existe).

- [ ] **Step 3: Adicionar a string** em `lib/core/l10n/app_strings.dart` (seção "Tela da Lista", após `itemAtualizado`)

```dart
  static const naoEntendiItem = 'Não entendi o item';
```

- [ ] **Step 4: Implementar** — `lib/features/listas/ui/tela_lista_screen.dart`

No `_CampoAdicionarState`, adicionar o estado `String? _erro;` (junto de `Unidade _unidade = Unidade.un;`) e tratá-lo em `_adicionar()`:

```dart
  /// Unidade usada quando o texto digitado não traz uma (F12-T06).
  Unidade _unidade = Unidade.un;

  /// Erro inline quando o parser descarta o texto digitado (F14-T07).
  String? _erro;
```

```dart
  Future<void> _adicionar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    // Reconhece "1kg de banana" → Banana, 1 kg (F12-T06); sem unidade no
    // texto, aplica a unidade escolhida no seletor.
    final extra = interpretarItemAvulso(texto, unidadePadrao: _unidade);
    if (extra == null) {
      // Texto só com pontuação/separador: nada foi reconhecido (F14-T07).
      setState(() => _erro = AppStrings.naoEntendiItem);
      return;
    }
    if (_erro != null) setState(() => _erro = null);
    final repo = ref.read(listasRepositoryProvider);
    // ... (restante do método inalterado)
```

No `build`, passar `erro` e limpar no `onChanged` (mantendo `onSubmitted` e `sufixo`):

```dart
      child: AppCampoTexto(
        controller: _controller,
        label: AppStrings.adicionarItem,
        erro: _erro,
        onChanged: (_) {
          if (_erro != null) setState(() => _erro = null);
        },
        onSubmitted: _adicionar,
        sufixo: Row(
          // ... (inalterado)
        ),
      ),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (todos os testes da tela da lista, incluindo o novo e os de adicionar com Enter/ícone).

---

### Task 2: Erro inline no editor de item

Hoje `_salvar()` apenas retorna sem feedback quando o nome está vazio ou a quantidade é inválida. Mostrar erro inline nos dois campos mantendo o diálogo aberto.

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (seção "Erros de autenticação", após `erroNomeVazio` — é usado no editor de item; OU seção "Tela da Lista" após `nomeDoItem`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_DialogoEditarItemState`, linhas ~757-894)
- Test: `test/features/listas/tela_lista_screen_test.dart`

**Interfaces:**
- Produces: `AppStrings.erroQuantidadeInvalida = 'Informe uma quantidade maior que zero.'` (reusa `AppStrings.erroNomeVazio` já existente).

- [ ] **Step 1: Escrever o teste que falha** em `test/features/listas/tela_lista_screen_test.dart` (após `deve_editar_quantidade_e_unidade_quando_swipe_direita`, linha ~458)

```dart
  testWidgets('deve_mostrar_erro_inline_quando_nome_e_quantidade_invalidos', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDoItem),
      '',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '0',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroNomeVazio), findsOneWidget);
    expect(find.text(AppStrings.erroQuantidadeInvalida), findsOneWidget);
    // O diálogo permanece aberto (nada foi salvo).
    expect(find.text(AppStrings.editarItem), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_mostrar_erro_inline_quando_nome_e_quantidade_invalidos`
Expected: FAIL (`AppStrings.erroQuantidadeInvalida` não existe / nenhum erro aparece).

- [ ] **Step 3: Adicionar a string** em `lib/core/l10n/app_strings.dart` (seção "Listas", logo após `erroNomeVazio`)

```dart
  static const erroNomeVazio = 'Informe um nome.';
  static const erroQuantidadeInvalida =
      'Informe uma quantidade maior que zero.';
```

- [ ] **Step 4: Implementar** — `lib/features/listas/ui/tela_lista_screen.dart` (`_DialogoEditarItemState`)

Adicionar os dois campos de erro (junto de `_unidade`/`_categoria`):

```dart
  late Unidade _unidade = widget.item.unidade;
  late CategoriaItem _categoria = widget.item.categoria;
  String? _erroNome;
  String? _erroQuantidade;
```

Reescrever `_salvar()`:

```dart
  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final quantidade = _quantidadeLida();
    setState(() {
      _erroNome = nome.isEmpty ? AppStrings.erroNomeVazio : null;
      _erroQuantidade = quantidade == null
          ? AppStrings.erroQuantidadeInvalida
          : null;
    });
    if (nome.isEmpty || quantidade == null) return;
    await ref
        .read(listasRepositoryProvider)
        .editarItem(
          widget.item.id,
          nome: nome,
          quantidade: quantidade,
          unidade: _unidade,
          categoria: _categoria,
        );
    if (mounted) Navigator.pop(context);
  }
```

No `build`, nos dois `AppCampoTexto` de nome e quantidade, adicionar `erro` e limpar no `onChanged`:

```dart
            AppCampoTexto(
              controller: _nome,
              label: AppStrings.nomeDoItem,
              erro: _erroNome,
              onChanged: (_) {
                if (_erroNome != null) setState(() => _erroNome = null);
              },
            ),
```

```dart
                  child: AppCampoTexto(
                    controller: _quantidade,
                    label: AppStrings.quantidade,
                    erro: _erroQuantidade,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      if (_erroQuantidade != null) {
                        setState(() => _erroQuantidade = null);
                      }
                    },
                  ),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (incluindo `deve_editar_quantidade_e_unidade_quando_swipe_direita` e `deve_rotular_nome_do_item_quando_abre_editor`, que não regridem).

---

### Task 3: Erro inline na edição inline da importação

Aplicar a mesma validação de nome/quantidade ao painel de edição inline do modal de pré-visualização.

**Files:**
- Modify: `lib/features/importacao/ui/modal_previsao_importacao.dart` (`_PainelEdicaoState`, linhas ~235-359)
- Test: `test/features/importacao/modal_previsao_importacao_test.dart`

**Interfaces:**
- Consumes: `AppStrings.erroNomeVazio` (Task 2), `AppStrings.erroQuantidadeInvalida` (Task 2).
- Produces: `_PainelEdicaoState._erroNome`/`_erroQuantidade` aplicados como `InputDecoration.errorText`; a semântica de gravação não muda (nome vazio continua excluindo a linha de `_selecionados`; quantidade inválida continua mantendo o último valor válido).

- [ ] **Step 1: Escrever os testes que falham** em `test/features/importacao/modal_previsao_importacao_test.dart` (após `deve_editar_nome_quantidade_unidade_quando_expandir`, linha ~201)

```dart
  testWidgets('deve_mostrar_erro_quando_nome_vazio_na_edicao_inline', (
    tester,
  ) async {
    await abrir(tester, resposta4);

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    expect(find.text(AppStrings.erroNomeVazio), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_mostrar_erro_quando_quantidade_invalida_na_edicao_inline', (
    tester,
  ) async {
    await abrir(tester, resposta4);

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pump();

    expect(find.text(AppStrings.erroQuantidadeInvalida), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/importacao/modal_previsao_importacao_test.dart`
Expected: FAIL (nenhum `errorText` renderizado).

- [ ] **Step 3: Implementar** — `lib/features/importacao/ui/modal_previsao_importacao.dart` (`_PainelEdicaoState`)

Adicionar os estados de erro junto de `_unidade`/`_categoria`:

```dart
  late Unidade _unidade = widget.linha.unidade;
  late CategoriaItem _categoria = widget.linha.categoria;
  String? _erroNome;
  String? _erroQuantidade;
```

Reescrever `_notificar()` para validar e atualizar os erros (o valor passado ao pai segue a regra atual):

```dart
  void _notificar({double? quantidade}) {
    final lida = _quantidadeLida();
    setState(() {
      _erroNome = _nome.text.trim().isEmpty ? AppStrings.erroNomeVazio : null;
      _erroQuantidade = lida == null
          ? AppStrings.erroQuantidadeInvalida
          : null;
    });
    widget.onAlterar(
      _nome.text,
      quantidade ?? lida ?? widget.linha.quantidade,
      _unidade,
      _categoria,
    );
  }
```

No `build`, adicionar `errorText` aos dois `TextField` (trocando o `decoration: const InputDecoration(...)` por não-const):

Campo de nome:

```dart
          TextField(
            controller: _nome,
            onChanged: (_) => _notificar(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _erroNome,
            ),
          ),
```

Campo de quantidade:

```dart
                child: TextField(
                  controller: _quantidade,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) => _notificar(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: _erroQuantidade,
                  ),
                ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/importacao/modal_previsao_importacao_test.dart`
Expected: PASS (os testes novos e os existentes de edição/confirmar/cancelar).

---

### Task 4: Toggle de senha nos dois campos do registro

Hoje ambos os campos usam `senha: true` fixo. Espelhar `RedefinirSenhaScreen` (F14-T03): um toggle independente por campo.

**Files:**
- Modify: `lib/features/auth/ui/registro_screen.dart` (`_RegistroScreenState`, linhas ~26-181)
- Test: `test/features/auth/registro_screen_test.dart`

**Interfaces:**
- Produces: `_ocultarSenha`/`_ocultarConfirmar` (bool) + `sufixo: IconButton` em cada campo, com tooltips `AppStrings.mostrarSenha`/`AppStrings.ocultarSenha`.

- [ ] **Step 1: Escrever o teste que falha** em `test/features/auth/registro_screen_test.dart` (antes do fecho de `main`, linha ~160)

```dart
  testWidgets('deve_alternar_visualizacao_das_senhas_quando_toca_nos_toggles', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await abrirTela(tester, repo);

    TextField campo(String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(campo(AppStrings.senha).obscureText, isTrue);
    expect(campo(AppStrings.confirmarSenha).obscureText, isTrue);

    await tester.tap(find.byTooltip(AppStrings.mostrarSenha).first);
    await tester.pump();

    expect(campo(AppStrings.senha).obscureText, isFalse);
    expect(campo(AppStrings.confirmarSenha).obscureText, isTrue);

    await tester.tap(find.byTooltip(AppStrings.mostrarSenha));
    await tester.pump();

    expect(campo(AppStrings.confirmarSenha).obscureText, isFalse);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/auth/registro_screen_test.dart --plain-name deve_alternar_visualizacao_das_senhas_quando_toca_nos_toggles`
Expected: FAIL (`find.byTooltip(mostrarSenha)` não encontra nada — não há toggle).

- [ ] **Step 3: Implementar** — `lib/features/auth/ui/registro_screen.dart`

Adicionar os dois booleanos junto de `_carregando`:

```dart
  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmar = true;
```

Trocar o campo de senha:

```dart
                  AppCampoTexto(
                    controller: _senha,
                    label: AppStrings.senha,
                    erro: _erroSenha,
                    senha: _ocultarSenha,
                    sufixo: IconButton(
                      tooltip: _ocultarSenha
                          ? AppStrings.mostrarSenha
                          : AppStrings.ocultarSenha,
                      icon: Icon(
                        _ocultarSenha
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _ocultarSenha = !_ocultarSenha),
                    ),
                  ),
```

E o de confirmação:

```dart
                  AppCampoTexto(
                    controller: _confirmar,
                    label: AppStrings.confirmarSenha,
                    erro: _erroConfirmar,
                    senha: _ocultarConfirmar,
                    onSubmitted: _registrar,
                    sufixo: IconButton(
                      tooltip: _ocultarConfirmar
                          ? AppStrings.mostrarSenha
                          : AppStrings.ocultarSenha,
                      icon: Icon(
                        _ocultarConfirmar
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _ocultarConfirmar = !_ocultarConfirmar,
                      ),
                    ),
                  ),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/auth/registro_screen_test.dart`
Expected: PASS (os 8 testes existentes + o novo).

---

### Task 5: Docs donos, marcação da tarefa e validação final

**Files:**
- Modify: `docs/05-app-flutter.md` (§6.1, §6.3, §6.4)
- Modify: `docs/14-tarefas.md` (F14-T07 + tabela de progresso)

- [ ] **Step 1: Doc 05 §6.1** (linha ~137) — citar a tarefa do toggle

Trocar:

```
* **Registro:** os dois campos de senha ganham toggle de mostrar/ocultar (paridade com o login) e "Reenviar link" passa a dar retorno (SnackBar) e a desabilitar durante o envio (F14-T05).
```

por:

```
* **Registro:** os dois campos de senha ganham toggle de mostrar/ocultar (paridade com o login; F14-T07) e "Reenviar link" passa a dar retorno (SnackBar) e a desabilitar durante o envio (F14-T05).
```

- [ ] **Step 2: Doc 05 §6.3** — na tabela, a linha do campo "Adicionar item" (linha ~152) recebe, ao final:

```
; texto que o parser descarta (ex.: só pontuação) → erro inline "Não entendi o item" (F14-T07)
```

- [ ] **Step 3: Doc 05 §6.4** — no item 3 (linha ~179), após "edição inline de nome/quantidade/unidade/**categoria**":

```
, com erro inline de nome/quantidade (F14-T07)
```

- [ ] **Step 4: Doc 14** — marcar F14-T07 (linhas 373-375)

```markdown
- [x] **F14-T07** — Validação visível
  Dep: F14-T00 · Docs: [05 §6](05-app-flutter.md), [15 §3](15-design-system.md)
  CP: erro inline no editor (nome/quantidade) e na edição inline da importação; aviso quando o parser descarta todo o texto; toggle de senha no registro; testes verdes.
  *(`_CampoAdicionar` com erro inline `naoEntendiItem` quando o parser descarta o texto, limpo ao digitar; editor de item com `erroNomeVazio`/`erroQuantidadeInvalida` mantendo o diálogo aberto; `_PainelEdicao` da importação com `errorText` de nome/quantidade (migração para `AppCampoTexto` segue na F14-T08); registro com toggle independente por campo (padrão da `RedefinirSenhaScreen`); docs 05 §6.1/§6.3/§6.4 atualizados)*
```

Na tabela de progresso:

```markdown
| F14 Acessibilidade & UX | 10 | 8 |
```

E o total:

```markdown
| **Total** | **97** | **93** |
```

- [ ] **Step 5: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações; analyze "No issues found!"; toda a suíte verde.

- [ ] **Step 6: Commit (somente com confirmação do usuário)**

```bash
git add lib test docs
git commit -m "F14-T07: validacao inline no editor, no add e na importacao (RNF-06)"
```

> **Nota:** não commitar sem confirmação explícita. Se o usuário autorizar, decidir o agrupamento com ele.

## Self-Review

- **Spec coverage (§9):** Adicionar item → erro do parser (Task 1); editor com erro inline de nome/quantidade (Task 2); edição inline da importação com a mesma validação (Task 3); toggle de senha nos dois campos do registro (Task 4). Docs donos + marcação (Task 5). ✔
- **Placeholders:** nenhum "TBD"; todos os passos têm código/teste reais e comandos executáveis.
- **Type consistency:** `AppStrings.naoEntendiItem` (Task 1) e `AppStrings.erroQuantidadeInvalida` (Task 2) nascem antes de serem consumidas (`naoEntendiItem` na Task 1; `erroNomeVazio` já existe; `erroQuantidadeInvalida` usada nas Tasks 2 e 3). Os nomes de estado `_erro` (Task 1), `_erroNome`/`_erroQuantidade` (Tasks 2 e 3) são distintos por classe e coerentes com o `erro`/`errorText` de cada componente.
- **Risco:** os `TextField` da importação continuam crus (só ganham `errorText`) — a migração para `AppCampoTexto` é explicitamente da F14-T08; os testes de `deve_editar_nome_quantidade_unidade_quando_expandir` e `deve_editar_categoria_quando_expandir_f6t05` não devem regredir.
