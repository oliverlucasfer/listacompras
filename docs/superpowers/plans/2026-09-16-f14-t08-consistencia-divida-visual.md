# F14-T08 — Consistência e dívida visual — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar inconsistências de UI apontadas na auditoria da F14: uma única copy de exclusão, strings restantes no `AppStrings`, `AppCampoTexto`/`AppDropdown` padronizados (migrando os campos crus), banner "Somente leitura" via `AppBannerTipo.leitura` e medidas em tokens.

**Architecture:** Tudo em UI/strings (`lib/core/**`, `lib/features/**/ui`, `lib/core/l10n`), sem schema/RLS/IA/sync. Dois componentes de design system evoluem: `AppCampoTexto` ganha params (`maxLength`, `minLines`, `maxLines`, `textInputAction`, `readOnly`, `hint`) e nasce `AppDropdown<T>`. As migrações são refatorações cobertas pela suíte existente; o conteúdo é travado por testes de widget/unit novos.

**Tech Stack:** Flutter 3.44 · flutter_riverpod 3 · go_router 18 · Drift · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-14-ux-acessibilidade-design.md` (§10)

**Tarefa dona:** F14-T08 em `docs/14-tarefas.md` · Docs normativos: [15 §1/§3](../../15-design-system.md), [05 §6/§7](../../05-app-flutter.md), [10 §3.3/§3.4](../../10-wireframes-telas.md)

## Global Constraints

- Comentários no código apenas quando indispensáveis. `camelCase` (Dart); pt-BR strings centralizadas em `lib/core/l10n/app_strings.dart` — string de UI fora do `AppStrings` é bug.
- Testes: nome `deve_<resultado>_quando_<condicao>`.
- **Não alterar schema/RLS/IA/sync nem repositórios.** Mudança de comportamento exige atualizar o doc dono (`15`/`05`) no mesmo PR.
- **Decisões aprovadas (2026-09-16):**
  1. Criar `AppDropdown<T>` e migrar os 4 dropdowns; migrar só os `TextField` crus para `AppCampoTexto`.
  2. `AppStrings.excluirListaMensagem(int nItens, {required bool temMembros})`; o painel usa `temMembros: false` e a tela da lista consulta `membrosDaListaProvider` (best-effort, sem bloquear).
  3. `AppCampoTexto` ganha os 4 params da spec **+ `hint`**; o visual dos modais é padronizado (perde `isDense`/borda/centralização) — decisão consciente.
- Medidas → tokens **só onde houver token exato**; valores sem token (`bottom: 88`, `width: 40`, ícones 64/72) permanecem (a spec diz "onde houver token aplicável").
- Rodar antes de fechar: `dart format .`, `flutter analyze` e `flutter test` verdes.
- **Não commitar** sem confirmação explícita do usuário (o controller decide o agrupamento com ele; a validação fecha a tarefa).

---

### Task 1: `AppCampoTexto` — params novos (`maxLength`, `minLines`, `maxLines`, `textInputAction`, `readOnly`, `hint`)

**Files:**
- Modify: `lib/core/widgets/app_campo_texto.dart`
- Test: `test/core/widgets/app_campo_texto_test.dart`

**Interfaces:**
- Produces: `AppCampoTexto` aceita `String? hint`, `int? maxLength`, `int? minLines`, `int? maxLines`, `TextInputAction? textInputAction`, `bool readOnly = false`. Com `maxLength`, o contador embutido do Flutter fica **oculto** (`counterText: ''`) e o limite **não trunca** (`MaxLengthEnforcement.none`) — o app mostra o próprio contador (ex.: importação) e permite passar do limite para avisar em vermelho.

- [ ] **Step 1: Escrever os testes que falham** em `test/core/widgets/app_campo_texto_test.dart` (após o teste existente)

```dart
  testWidgets('deve_aplicar_hint_readonly_linhas_e_action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(
            hint: 'Exemplo',
            readOnly: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 10,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ),
    );
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.readOnly, isTrue);
    expect(campo.minLines, 3);
    expect(campo.maxLines, 5);
    expect(campo.maxLength, 10);
    expect(campo.textInputAction, TextInputAction.newline);
    expect(find.text('Exemplo'), findsOneWidget);
    // Contador embutido oculto: o app usa o próprio (ex.: importação).
    expect(find.text('0/10'), findsNothing);
  });

  testWidgets('deve_permitir_exceder_max_length_quando_informado', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppCampoTexto(controller: controller, maxLength: 3),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();
    expect(controller.text, 'abcdefgh');
  });
```

Adicionar `import 'package:flutter/services.dart';` (para `TextInputAction`) no topo do teste.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/widgets/app_campo_texto_test.dart`
Expected: FAIL (params não existem).

- [ ] **Step 3: Implementar** — `lib/core/widgets/app_campo_texto.dart`

Adicionar `import 'package:flutter/services.dart';` e trocar a classe por:

```dart
/// Campo de formulário padronizado com erro inline (doc 15 §3).
class AppCampoTexto extends StatelessWidget {
  const AppCampoTexto({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.erro,
    this.teclado,
    this.senha = false,
    this.sufixo,
    this.autofillHints,
    this.autofocus = false,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.textInputAction,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? erro;
  final TextInputType? teclado;
  final bool senha;
  final Widget? sufixo;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: senha,
      autofillHints: autofillHints,
      autofocus: autofocus,
      // O app mostra o próprio contador e permite exceder o limite para avisar
      // em vermelho; o contador/limite embutidos do Flutter ficam fora.
      maxLength: maxLength,
      maxLengthEnforcement: maxLength == null
          ? null
          : MaxLengthEnforcement.none,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: erro,
        counterText: maxLength == null ? null : '',
        suffixIcon: sufixo,
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/widgets/app_campo_texto_test.dart`
Expected: PASS (3 testes).

---

### Task 2: `AppDropdown<T>` novo

**Files:**
- Create: `lib/core/widgets/app_dropdown.dart`
- Test: `test/core/widgets/app_dropdown_test.dart`

**Interfaces:**
- Produces: `AppDropdown<T>({String? label, required T valor, required List<DropdownMenuItem<T>> itens, required ValueChanged<T?> onChanged, bool compacto = false})` — envolve `DropdownButtonFormField<T>` com `initialValue: valor` e `InputDecoration(labelText, border: OutlineInputBorder(), isDense: compacto)`. Consumido nas Tasks 3 e 4.

- [ ] **Step 1: Escrever o teste que falha** — `test/core/widgets/app_dropdown_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';

void main() {
  testWidgets('deve_exibir_label_e_disparar_onChanged_quando_seleciona', (
    tester,
  ) async {
    String? selecionado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: AppDropdown<String>(
            label: 'Unidade',
            valor: 'a',
            itens: const [
              DropdownMenuItem(value: 'a', child: Text('A')),
              DropdownMenuItem(value: 'b', child: Text('B')),
            ],
            onChanged: (v) => selecionado = v,
          ),
        ),
      ),
    );

    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(selecionado, 'b');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/widgets/app_dropdown_test.dart`
Expected: FAIL (`app_dropdown.dart` não existe).

- [ ] **Step 3: Implementar** — `lib/core/widgets/app_dropdown.dart`

```dart
import 'package:flutter/material.dart';

/// Dropdown de formulário padronizado (doc 15 §3, F14-T08): mesma decoração
/// dos demais campos (`AppCampoTexto`), em todos os seletores do app.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.label,
    required this.valor,
    required this.itens,
    required this.onChanged,
    this.compacto = false,
  });

  final String? label;
  final T valor;
  final List<DropdownMenuItem<T>> itens;
  final ValueChanged<T?> onChanged;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: compacto,
      ),
      items: itens,
      onChanged: onChanged,
    );
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/widgets/app_dropdown_test.dart`
Expected: PASS.

---

### Task 3: Migrar os campos crus da importação

**Files:**
- Modify: `lib/features/importacao/ui/modal_importar.dart` (textarea + import)
- Modify: `lib/features/importacao/ui/modal_previsao_importacao.dart` (2 `TextField` + 2 `DropdownButtonFormField` + imports)
- Test: `test/features/importacao/modal_importar_test.dart`, `test/features/importacao/modal_previsao_importacao_test.dart` (regressão)

**Interfaces:**
- Consumes: `AppCampoTexto` (Task 1), `AppDropdown` (Task 2).

- [ ] **Step 1: Baseline verde**

Run: `flutter test test/features/importacao/`
Expected: PASS — é a evidência de que a refatoração não muda comportamento.

- [ ] **Step 2: `modal_importar.dart`** — trocar o `TextField` do textarea (linhas ~156-162) por

```dart
          AppCampoTexto(
            controller: _controller,
            hint: AppStrings.iaExemplo,
            teclado: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLength: _limite,
            minLines: 5,
            maxLines: 5,
          ),
```

Adicionar `import '../../../core/widgets/app_campo_texto.dart';` (e `import 'package:flutter/services.dart';` para `TextInputAction`).

- [ ] **Step 3: `modal_previsao_importacao.dart`** — substituir os campos crus

Campo de nome (linhas ~294-300):

```dart
          AppCampoTexto(
            controller: _nome,
            erro: _erroNome,
            onChanged: (_) => _notificar(),
          ),
```

Campo de quantidade (linhas ~312-322):

```dart
                child: AppCampoTexto(
                  controller: _quantidade,
                  erro: _erroQuantidade,
                  teclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _notificar(),
                ),
```

Dropdown de unidade (linhas ~333-353):

```dart
                child: AppDropdown<Unidade>(
                  valor: _unidade,
                  compacto: true,
                  itens: [
                    for (final u in Unidade.values)
                      DropdownMenuItem(value: u, child: Text(u.valor)),
                  ],
                  onChanged: (u) {
                    if (u == null) return;
                    setState(() => _unidade = u);
                    _notificar();
                  },
                ),
```

Dropdown de categoria (linhas ~355-367):

```dart
          AppDropdown<CategoriaItem>(
            label: AppStrings.categoria,
            valor: _categoria,
            compacto: true,
            itens: [
              for (final c in CategoriaItem.values)
                DropdownMenuItem(value: c, child: Text(c.rotulo)),
            ],
            onChanged: (c) {
              if (c == null) return;
              setState(() => _categoria = c);
              _notificar();
            },
          ),
```

Adicionar `import '../../../core/widgets/app_campo_texto.dart';` e `import '../../../core/widgets/app_dropdown.dart';`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter analyze` (imports órfãos saem) e `flutter test test/features/importacao/`
Expected: analyze limpo; 13+ testes verdes — o counter/limite da importação segue correto (`deve_exibir_contador_atualizado_quando_digitar` garante contador único) e a edição inline/confirmar segue verde.

---

### Task 4: Migrar `sheet_convidar` e os dropdowns do editor de item

**Files:**
- Modify: `lib/features/convites/ui/sheet_convidar.dart` (link readOnly + import)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_DialogoEditarItem`, 2 dropdowns + import)
- Test: `test/features/convites/sheet_convidar_test.dart`, `test/features/listas/tela_lista_screen_test.dart` (regressão)

**Interfaces:**
- Consumes: `AppCampoTexto` (Task 1), `AppDropdown` (Task 2).

- [ ] **Step 1: Baseline verde**

Run: `flutter test test/features/convites/sheet_convidar_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: PASS.

- [ ] **Step 2: `sheet_convidar.dart`** — trocar `TextField(readOnly: true, controller: _linkController!)` (linha ~146) por

```dart
            AppCampoTexto(controller: _linkController, readOnly: true),
```

Adicionar `import '../../../core/widgets/app_campo_texto.dart';`. (`_linkController` é `TextEditingController?` — o campo aceita null.)

- [ ] **Step 3: `tela_lista_screen.dart`** — no `_DialogoEditarItemState.build`, trocar os dois `DropdownButtonFormField` (linhas ~876 e ~892)

Unidade:

```dart
            AppDropdown<Unidade>(
              label: AppStrings.unidade,
              valor: _unidade,
              itens: [
                for (final u in Unidade.values)
                  DropdownMenuItem(value: u, child: Text(u.valor)),
              ],
              onChanged: (u) {
                if (u != null) setState(() => _unidade = u);
              },
            ),
```

Categoria:

```dart
            AppDropdown<CategoriaItem>(
              label: AppStrings.categoria,
              valor: _categoria,
              itens: [
                for (final c in CategoriaItem.values)
                  DropdownMenuItem(value: c, child: Text(c.rotulo)),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _categoria = c);
              },
            ),
```

Adicionar `import '../../../core/widgets/app_dropdown.dart';`.

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter analyze` e `flutter test test/features/convites/sheet_convidar_test.dart test/features/listas/tela_lista_screen_test.dart`
Expected: analyze limpo; testes verdes (incl. `deve_editar_categoria_quando_swipe_direita_f6t04` e `deve_copiar_*`).

---

### Task 5: Copy única de exclusão de lista

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (trocar `excluirListaMensagem` const por funções)
- Modify: `lib/features/listas/ui/painel_listas.dart` (`_confirmarExclusao`)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_confirmarExcluirLista` + import do provider)
- Create: `test/core/l10n/app_strings_test.dart`
- Modify: `test/features/listas/minhas_listas_screen_test.dart` (linha ~195)

**Interfaces:**
- Produces: `AppStrings.excluirListaTitulo(String titulo) => 'Excluir "$titulo"?'` e `AppStrings.excluirListaMensagem(int nItens, {required bool temMembros})`.
- Consumes (tela da lista): `membrosDaListaProvider` de `lib/features/convites/ui/tela_membros_screen.dart`.

- [ ] **Step 1: Escrever o teste que falha** — `test/core/l10n/app_strings_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';

void main() {
  test('deve_montar_titulo_de_exclusao_quando_informado_o_nome', () {
    expect(AppStrings.excluirListaTitulo('Compras'), 'Excluir "Compras"?');
  });

  test('deve_variar_mensagem_de_exclusao_por_itens_e_membros', () {
    expect(
      AppStrings.excluirListaMensagem(0, temMembros: false),
      'A lista será excluída.',
    );
    expect(
      AppStrings.excluirListaMensagem(1, temMembros: false),
      'O item será removido.',
    );
    expect(
      AppStrings.excluirListaMensagem(3, temMembros: false),
      'Os 3 itens serão removidos.',
    );
    expect(
      AppStrings.excluirListaMensagem(3, temMembros: true),
      'Os 3 itens serão removidos para todos os participantes.',
    );
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/l10n/app_strings_test.dart`
Expected: FAIL (`excluirListaTitulo` não existe; `excluirListaMensagem` ainda é const).

- [ ] **Step 3: `app_strings.dart`** — substituir o bloco de exclusão (linhas ~85-87) por

```dart
  static const excluirLista = 'Excluir lista';

  static String excluirListaTitulo(String titulo) => 'Excluir "$titulo"?';

  static String excluirListaMensagem(int nItens, {required bool temMembros}) {
    final sufixo = temMembros ? ' para todos os participantes' : '';
    if (nItens == 0) return 'A lista será excluída$sufixo.';
    if (nItens == 1) return 'O item será removido$sufixo.';
    return 'Os $nItens itens serão removidos$sufixo.';
  }
```

- [ ] **Step 4: `painel_listas.dart`** — `_confirmarExclusao`

```dart
  Future<void> _confirmarExclusao() async {
    final contagem = widget.contagem;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirListaTitulo(contagem.lista.titulo),
      mensagem: AppStrings.excluirListaMensagem(
        contagem.totalItens,
        temMembros: false,
      ),
    );
    if (confirmou) {
      await ref
          .read(listasRepositoryProvider)
          .excluirLista(contagem.lista.id);
    }
  }
```

- [ ] **Step 5: `tela_lista_screen.dart`** — `_confirmarExcluirLista` passa a usar a copy única

```dart
  Future<void> _confirmarExcluirLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final titulo = ref.read(listaPorIdProvider(idLista)).value?.titulo ?? '';
    final nItens = ref.read(itensDaListaProvider(idLista)).value?.length ?? 0;
    final membros = ref.read(membrosDaListaProvider(idLista)).value;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirListaTitulo(titulo),
      mensagem: AppStrings.excluirListaMensagem(
        nItens,
        // Best-effort: se os membros ainda não foram carregados, assume só o
        // dono (não bloqueia a exclusão).
        temMembros: (membros?.length ?? 0) > 1,
      ),
    );
    if (!confirmou) return;
    await ref.read(listasRepositoryProvider).excluirLista(idLista);
    if (context.mounted) context.go('/listas');
  }
```

Adicionar `import '../../convites/ui/tela_membros_screen.dart';`.

- [ ] **Step 6: Atualizar o teste do painel** — `test/features/listas/minhas_listas_screen_test.dart` linha ~195

```dart
    expect(
      find.text(AppStrings.excluirListaMensagem(0, temMembros: false)),
      findsOneWidget,
    );
```

- [ ] **Step 7: Rodar e ver passar**

Run: `flutter test test/core/l10n/app_strings_test.dart test/features/listas/`
Expected: PASS (o teste da tela da lista `deve_excluir_lista_e_voltar_ao_painel_quando_confirmar` continua verde: título e "O item será removido." inalterados).

---

### Task 6: Strings centralizadas (tempo relativo, fallback, contagem)

**Files:**
- Modify: `lib/core/l10n/app_strings.dart` (novos grupos)
- Modify: `lib/core/utils/tempo_relativo.dart`
- Modify: `lib/features/listas/domain/lista_com_contagem.dart`
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (fallback `'—'`)
- Modify: `test/core/l10n/app_strings_test.dart` (novos asserts)

**Interfaces:**
- Produces: `AppStrings.tempoAgora`, `tempoMinutos(int)`, `tempoHoras(int)`, `tempoOntem`, `tempoDias(int)`, `tempoMeses(int)`, `tempoAnos(int)`, `progressoLista(int concluidos, int total)`, `semValor = '—'`.

- [ ] **Step 1: Escrever os testes que falham** — acrescentar em `test/core/l10n/app_strings_test.dart`

```dart
  test('deve_montar_tempo_relativo_centralizado', () {
    expect(AppStrings.tempoAgora, 'agora');
    expect(AppStrings.tempoMinutos(5), 'há 5 min');
    expect(AppStrings.tempoHoras(3), 'há 3 h');
    expect(AppStrings.tempoOntem, 'ontem');
    expect(AppStrings.tempoDias(5), 'há 5 dias');
    expect(AppStrings.tempoMeses(2), 'há 2 meses');
    expect(AppStrings.tempoAnos(2), 'há 2 anos');
  });

  test('deve_montar_progresso_da_lista', () {
    expect(AppStrings.progressoLista(3, 10), '3/10 itens concluídos');
    expect(AppStrings.progressoLista(0, 1), '0/1 item concluído');
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/l10n/app_strings_test.dart`
Expected: FAIL (strings não existem).

- [ ] **Step 3: `app_strings.dart`** — adicionar (seção "Tela da Lista" e "Estados transversais")

```dart
  // Tempo relativo dos cards (wireframe 10 §2, F14-T08)
  static const tempoAgora = 'agora';
  static String tempoMinutos(int m) => 'há $m min';
  static String tempoHoras(int h) => 'há $h h';
  static const tempoOntem = 'ontem';
  static String tempoDias(int d) => 'há $d dias';
  static String tempoMeses(int m) => 'há $m meses';
  static String tempoAnos(int a) => 'há $a anos';

  static String progressoLista(int concluidos, int total) {
    final palavra = total == 1 ? 'item concluído' : 'itens concluídos';
    return '$concluidos/$total $palavra';
  }

  static const semValor = '—';
```

- [ ] **Step 4: `tempo_relativo.dart`** — passar a usar o `AppStrings`

```dart
import '../l10n/app_strings.dart';

/// Tempo relativo pt-BR para cards (wireframe 10 §2: "atualizada há 5 min").
String tempoRelativo(DateTime de, {required DateTime agora}) {
  final diferenca = agora.difference(de);
  if (diferenca.inSeconds < 60) return AppStrings.tempoAgora;
  if (diferenca.inMinutes < 60) {
    return AppStrings.tempoMinutos(diferenca.inMinutes);
  }
  if (diferenca.inHours < 24) return AppStrings.tempoHoras(diferenca.inHours);
  if (diferenca.inDays < 2) return AppStrings.tempoOntem;
  if (diferenca.inDays < 30) return AppStrings.tempoDias(diferenca.inDays);
  if (diferenca.inDays < 365) {
    return AppStrings.tempoMeses(diferenca.inDays ~/ 30);
  }
  return AppStrings.tempoAnos(diferenca.inDays ~/ 365);
}
```

- [ ] **Step 5: `lista_com_contagem.dart`** — usar `progressoLista`

```dart
import '../../../core/l10n/app_strings.dart';
import 'lista.dart';

/// Lista com contagem de itens para o card do painel (wireframe 10 §2.1:
/// "3/10 itens concluídos"). Itens com tombstone ficam fora da contagem.
class ListaComContagem {
  const ListaComContagem({
    required this.lista,
    required this.totalItens,
    required this.concluidos,
  });

  final Lista lista;
  final int totalItens;
  final int concluidos;

  String get contagem => AppStrings.progressoLista(concluidos, totalItens);
}
```

- [ ] **Step 6: `configuracoes_screen.dart`** — linha ~128

```dart
                  Text(snapshot.data?.version ?? AppStrings.semValor),
```

- [ ] **Step 7: Rodar e ver passar**

Run: `flutter test test/core/l10n/app_strings_test.dart test/core/tempo_relativo_test.dart test/features/listas/minhas_listas_screen_test.dart test/features/configuracoes/`
Expected: PASS (os testes de tempo relativo seguem verdes — mesmos textos).

---

### Task 7: Banner "Somente leitura" com `AppBannerTipo.leitura`

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`_BannerSomenteLeitura`)
- Modify: `test/features/listas/tela_lista_screen_test.dart` (`deve_mostrar_banner_e_menu_reduzido_quando_leitor_f7t04`)

**Interfaces:**
- Consumes: `AppBanner`/`AppBannerTipo.leitura` (já existentes).

- [ ] **Step 1: Atualizar o teste que falha** — `test/features/listas/tela_lista_screen_test.dart`, no teste `deve_mostrar_banner_e_menu_reduzido_quando_leitor_f7t04` (linhas ~959-970), trocar o trecho

```dart
    // Banner fixo de somente leitura (surfaceVariant).
    final banner = find.text(AppStrings.somenteLeitura);
    expect(banner, findsOneWidget);
    expect(find.text(AppStrings.somenteLeituraDica), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.ancestor(of: banner, matching: find.byType(Container)).first,
          )
          .color,
      isNotNull,
    );
```

por

```dart
    // Banner de leitura pelo componente padrão (F14-T08).
    final bannerApp = tester.widget<AppBanner>(
      find.byType(AppBanner).first,
    );
    expect(bannerApp.tipo, AppBannerTipo.leitura);
    expect(
      find.text(
        '${AppStrings.somenteLeitura}: ${AppStrings.somenteLeituraDica}',
      ),
      findsOneWidget,
    );
```

Adicionar os imports `package:lista_compras/core/widgets/app_banner.dart` no topo do teste.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart --plain-name deve_mostrar_banner_e_menu_reduzido_quando_leitor_f7t04`
Expected: FAIL (ainda é `Container` manual / texto separado).

- [ ] **Step 3: Implementar** — `tela_lista_screen.dart`, substituir a classe `_BannerSomenteLeitura`

```dart
class _BannerSomenteLeitura extends StatelessWidget {
  const _BannerSomenteLeitura();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AppBanner(
        tipo: AppBannerTipo.leitura,
        mensagem:
            '${AppStrings.somenteLeitura}: ${AppStrings.somenteLeituraDica}',
      ),
    );
  }
}
```

Adicionar `import '../../../core/widgets/app_banner.dart';` (se ainda não houver).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/tela_lista_screen_test.dart`
Expected: PASS (todos os testes de leitor/papel verdes).

---

### Task 8: Medidas hardcoded → tokens (onde houver token exato)

**Files:**
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart` (linhas ~70 e ~131)
- Modify: `lib/features/auth/ui/registro_screen.dart` (linhas ~255 e ~261)
- Modify: `lib/features/auth/ui/recuperar_senha_screen.dart` (linha ~72)
- Modify: `lib/features/importacao/ui/modal_previsao_importacao.dart` (linhas ~156, ~303, ~331, ~352)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (linha ~664)

- [ ] **Step 1: Aplicar as trocas exatas**

- `configuracoes_screen.dart:70`: `const SizedBox(height: 16)` → `const SizedBox(height: AppSpacing.lg)`
- `configuracoes_screen.dart:131`: `const Divider(height: 32)` → `const Divider(height: AppSpacing.xxl)`
- `registro_screen.dart:255`: `const SizedBox(height: 16)` → `const SizedBox(height: AppSpacing.lg)`
- `registro_screen.dart:261`: `const SizedBox(height: 8)` → `const SizedBox(height: AppSpacing.sm)`
- `recuperar_senha_screen.dart:72`: `const SizedBox(height: 16)` → `const SizedBox(height: AppSpacing.lg)`
- `modal_previsao_importacao.dart:156`: `const SizedBox(height: 12)` → `const SizedBox(height: AppSpacing.md)`
- `modal_previsao_importacao.dart:303`: `const SizedBox(height: 8)` → `const SizedBox(height: AppSpacing.sm)`
- `modal_previsao_importacao.dart:331`: `const SizedBox(width: 8)` → `const SizedBox(width: AppSpacing.sm)`
- `modal_previsao_importacao.dart:352`: `const SizedBox(height: 8)` → `const SizedBox(height: AppSpacing.sm)`
- `tela_lista_screen.dart:664`: `const EdgeInsets.all(12)` → `const EdgeInsets.all(AppSpacing.md)`

Garantir o import do `app_spacing.dart` em cada arquivo tocado (adicionar onde faltar). **Manter** os valores sem token exato (`bottom: 88`, `width: 40`, ícones 64/72) — a spec diz "onde houver token aplicável".

- [ ] **Step 2: Rodar e ver passar**

Run: `flutter analyze` e `flutter test`
Expected: analyze limpo; suíte inteira verde (refatoração sem mudança de comportamento).

---

### Task 9: Docs donos, marcação da tarefa e validação final

**Files:**
- Modify: `docs/15-design-system.md` (§3)
- Modify: `docs/05-app-flutter.md` (§6.2/§6.3 — conferir; já descrevem a F14-T08)
- Modify: `docs/14-tarefas.md` (F14-T08 + progresso)

- [ ] **Step 1: Doc 15 §3** — atualizar a linha do `AppCampoTexto` e adicionar a linha do `AppDropdown`

Trocar:

```
| `AppCampoTexto` | Campo de formulário com erro inline; aceita `maxLength`, `minLines`/`maxLines`, `textInputAction` e `readOnly` (Fase 14) |
```

por:

```
| `AppCampoTexto` | Campo de formulário com erro inline; aceita `hint`, `maxLength`, `minLines`/`maxLines`, `textInputAction` e `readOnly` (Fase 14) |
| `AppDropdown<T>` | Dropdown de formulário padronizado (`label`/`valor`/`itens`/`onChanged`/`compacto`), mesma decoração dos campos (Fase 14) |
```

(inserir a linha do `AppDropdown` logo após a do `AppCampoTexto` na tabela).

- [ ] **Step 2: Doc 05 §6.2/§6.3** — conferir que as descrições já batem com o implementado (copy única de exclusão em §6.2, banner de leitura em §6.3). Se houver divergência de texto, ajustar; caso contrário, nenhuma edição.

- [ ] **Step 3: Doc 14** — marcar F14-T08 (linhas 376-378)

```markdown
- [x] **F14-T08** — Consistência e dívida visual
  Dep: F14-T00 · Docs: [15 §1/§3](15-design-system.md), [05 §6/§7](05-app-flutter.md)
  CP: uma única copy de exclusão de lista; strings (tempo relativo, fallbacks) no `AppStrings`; `AppBannerTipo.leitura` usado; `AppCampoTexto` com `maxLength`/`minLines`/`textInputAction`/`readOnly` e os `TextField` crus migrados; medidas em tokens; `analyze`/`test` verdes.
  *(`AppCampoTexto` com `hint`/`maxLength`/`minLines`/`maxLines`/`textInputAction`/`readOnly` (contador embutido oculto, sem truncar); `AppDropdown<T>` novo migrando os 4 dropdowns; `TextField` crus de `modal_importar`/`modal_previsao_importacao`/`sheet_convidar` migrados; `excluirListaTitulo`/`excluirListaMensagem(nItens, temMembros)` única (painel `false`, tela da lista best-effort via `membrosDaListaProvider`); tempo relativo/`progressoLista`/`semValor` no `AppStrings`; banner de leitura via `AppBannerTipo.leitura`; medidas exatas em tokens; docs 15 §3 atualizado)*
```

Na tabela de progresso:

```markdown
| F14 Acessibilidade & UX | 10 | 9 |
```

E o total:

```markdown
| **Total** | **97** | **94** |
```

- [ ] **Step 4: Validação final**

Run: `dart format --set-exit-if-changed .`
Run: `flutter analyze`
Run: `flutter test`
Expected: format sem alterações; analyze "No issues found!"; toda a suíte verde.

- [ ] **Step 5: Commit (somente com confirmação do usuário)**

```bash
git add lib test docs
git commit -m "F14-T08: copy unica, AppDropdown, campos migrados e tokens (RNF-06)"
```

> **Nota:** não commitar sem confirmação explícita. Se o usuário autorizar, decidir o agrupamento com ele.

## Self-Review

- **Spec coverage (§10):** copy única de exclusão (Task 5); strings tempo relativo/fallback/contagem no `AppStrings` (Task 6); `AppBannerTipo.leitura` (Task 7); `AppCampoTexto` com params + migração dos campos crus (Tasks 1/3/4); medidas em tokens (Task 8). Docs donos (Task 9). ✔
- **Placeholders:** nenhum "TBD"; todos os passos têm código/teste reais e comandos executáveis.
- **Type consistency:** `AppCampoTexto` ganha os params na Task 1 e é consumido nas Tasks 3/4; `AppDropdown<T>` nasce na Task 2 com `valor`/`itens`/`onChanged`/`compacto` e é consumido com essa assinatura nas Tasks 3/4; `excluirListaTitulo`/`excluirListaMensagem` nascem na Task 5 e são usadas no mesmo diff; `progressoLista`/`tempo*`/`semValor` nascem na Task 6 antes do uso.
- **Riscos:** (a) o contador da importação não pode duplicar — guardado por `deve_exibir_contador_atualizado_quando_digitar` (Task 3); (b) `DropdownButtonFormField`/`TextField` continuam no widget tree dentro dos `App*`, então `find.byType(...)` dos testes existentes segue encontrando (Tasks 3/4); (c) o banner de leitura muda de dois textos para um — teste atualizado (Task 7).
