# Fase 43 — Correções da revisão geral 2 (App & Docs): Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir os achados `G-xx` de i18n, UI/a11y, erros/validação, domínio e docs/CI da revisão geral 2, com TDD e doc dono atualizado no mesmo commit.

**Architecture:** Correções pontuais nas telas/componentes e documentos existentes — nenhuma mudança de arquitetura. Complementa o Plano A (dados & segurança); depende da Fase 43 registrada por `F43-T00`.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Riverpod, `flutter_test`, Drift (SQLite em memória), GitHub Actions.

**Spec:** [docs/superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md](../specs/2026-09-25-correcoes-revisao-geral-2-design.md) · Achados: [docs/relatorio-revisao-geral-2.md](../../relatorio-revisao-geral-2.md) · Tarefas: [docs/14-tarefas.md](../../14-tarefas.md) § Fase 43 · Plano A: [dados & segurança](2026-09-25-correcoes-revisao-2-dados-seguranca.md).

## Global Constraints

- Comandos do projeto: `flutter test`, `dart format . && flutter analyze` (CI exige os três verdes).
- Nome de teste: `deve_<resultado>_quando_<condição>`.
- Sem comentários novos no código, exceto quando indispensável; pt-BR em docs e UI.
- Componentes `App*` e tokens de `lib/core/theme/tokens/` são obrigatórios (doc 15); nenhum literal de cor.
- Commit por tarefa, com o ID (`F43-Tnn`) na mensagem; docs donos no mesmo commit.

---

### Task 1 (F43-T09) — i18n Material e strings

**Files:**
- Modify: `pubspec.yaml`, `lib/app.dart:28-36`, `lib/core/l10n/app_strings.dart:64,136,234,317-321,352`, `lib/features/configuracoes/ui/configuracoes_screen.dart:123`
- Modify: `docs/05-app-flutter.md` §7, `docs/15-design-system.md` §4
- Test: `test/core/l10n/app_strings_test.dart`, `test/core/widgets/acessibilidade_test.dart`

**Interfaces:**
- Consumes: `AppStrings` (`semValor`), componentes de app.
- Produces: `ListaComprasApp` com `pt_BR`; `mostrarSnackBar` ganha `ScaffoldMessengerState?` (usado também na Task 2).

- [ ] **Step 1: Write the failing tests**

Em `test/core/l10n/app_strings_test.dart` (ou um teste novo `test/core/l10n/localizacao_test.dart`):

```dart
  testWidgets('deve_localizar_material_em_pt_br', (tester) async {
    late String tooltip;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            tooltip = MaterialLocalizations.of(context).backButtonTooltip;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tooltip, 'Voltar');
  });
```

E um guarda de strings: nenhuma referência a `AppStrings.offline`, `importLocalTextoLongo`,
`mudarPapel`, `tituloLista` (grep no CI/local). Confirme com
`grep -rn "AppStrings.offline\|importLocalTextoLongo\|mudarPapel\|tituloLista" lib test`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/l10n/`
Expected: FAIL — `flutter_localizations` não está no pubspec/import; tooltip vem em inglês.

- [ ] **Step 3: Write minimal implementation**

`pubspec.yaml` (seção `dependencies`):

```yaml
  flutter_localizations:
    sdk: flutter
```

`lib/app.dart`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
```

No `MaterialApp.router`:

```dart
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
```

Remover de `app_strings.dart` as constantes órfãs (`offline`, `importLocalTextoLongo`, `mudarPapel`,
`tituloLista`) e unificar as duplicadas (`sairDaLista`/`sairListaTitulo` → uma; `removerItem`/
`removerMembro` → uma), atualizando os usos. Trocar `Text(email ?? '')` por
`Text(email ?? AppStrings.semValor)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/l10n/ test/core/widgets/`
Expected: PASS.

- [ ] **Step 5: Update the docs owners**

`docs/05` §7 e `docs/15` §4 — registrar `flutter_localizations`/`pt_BR` e que o Material é localizado.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/app.dart lib/core/l10n/app_strings.dart lib/features/configuracoes/ui/configuracoes_screen.dart test/core/ docs/05-app-flutter.md docs/15-design-system.md
git commit -m "F43-T09: localizacao pt-BR do Material e limpeza de strings (G-05, G-34, G-35, G-42)"
```

---

### Task 2 (F43-T10) — UI e acessibilidade

**Files:**
- Modify: `lib/core/widgets/app_snack_bar.dart`, `lib/core/widgets/app_botao.dart:77,85`, `lib/core/widgets/app_banner.dart:73`, `lib/core/theme/seletor_tema.dart:67-87`, `lib/app.dart:19-26`, `lib/router.dart:200,214-217`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart:305,704-744,927`, `lib/features/listas/ui/tela_ordenar_categorias.dart:53-56`, `lib/features/listas/ui/mercado_screen.dart:132-155,241-248`
- Modify: `lib/features/convites/ui/sheet_convidar.dart:315`, `lib/features/importacao/ui/modal_importar.dart:105-154`, `lib/features/configuracoes/ui/configuracoes_screen.dart:79-83`
- Modify: `lib/core/l10n/app_strings.dart` (string da dica do leitor)
- Test: `test/features/listas/tela_lista_screen_test.dart`, `test/features/listas/tela_ordenar_categorias_test.dart`, `test/features/listas/mercado_screen_test.dart`, `test/features/convites/sheet_convidar_test.dart`, `test/features/importacao/modal_importar_test.dart`, `test/core/widgets/acessibilidade_test.dart`, `test/core/theme/seletor_tema_test.dart`

**Interfaces:**
- Consumes: `mostrarSnackBar(BuildContext, String, {...})`, `AppEsqueleto`, `AppBotao`, `AppDropdown`, tokens.
- Produces: `mostrarSnackBar` com parâmetro opcional `ScaffoldMessengerState? messenger`; string `somenteLeitorDica`.

- [ ] **Step 1: Write the failing tests**

- `tela_lista_screen_test.dart`: enquanto `listaPorIdProvider` carrega, `find.byType(AppEsqueleto)` presente e `CircularProgressIndicator` ausente.
- `tela_ordenar_categorias_test.dart`: alça com tap target ≥48dp (usar `meetsGuideline(androidTapTargetGuideline)` no `ReorderableListView`).
- `sheet_convidar_test.dart`: o campo do link tem `label`/`hint` (buscar por `find.bySemanticsLabel` ou o rótulo).
- `tela_lista_screen_test.dart`: como leitor, tocar num item mostra `AppStrings.somenteLeitorDica`.
- `mercado_screen_test.dart`: rodapé dentro de `SafeArea` (e sem overflow a 2x).
- `acessibilidade_test.dart`: `SeletorTema` sem overflow em largura estreita/escala 2x; campo add item a 2x sem overflow.
- `seletor_tema_test.dart`: o ramo responsivo usa `AppDropdown` (por tipo/presença do rótulo padronizado).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/listas/ test/features/convites/ test/features/importacao/ test/core/widgets/ test/core/theme/`
Expected: FAIL nos casos novos.

- [ ] **Step 3: Write minimal implementation**

- `mostrarSnackBar`: aceitar messenger opcional:

```dart
void mostrarSnackBar(
  BuildContext context,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
  Duration? duracao,
  ScaffoldMessengerState? messenger,
}) {
  final alvo = messenger ?? ScaffoldMessenger.of(context);
  // ... resto inalterado, usando `alvo`
}
```

- `app.dart`: trocar o `showSnackBar` cru por `mostrarSnackBar` com
  `messenger: _messengerKey.currentState` (guarda se null). `configuracoes_screen.dart:79-83` idem.
- `tela_lista_screen.dart:305`: `CircularProgressIndicator` → `AppEsqueleto(linhas: 5)`.
- `tela_ordenar_categorias.dart:53-56`: envolver a alça em `Padding(EdgeInsets.all(AppSpacing.sm))`
  (ou `SizedBox` 48) mantendo o `ReorderableDragStartListener`.
- `sheet_convidar.dart:315`: adicionar `label`/`hint` ao `AppCampoTexto` do link.
- `tela_lista_screen.dart:927`: como leitor, `onTap: () => mostrarSnackBar(context, AppStrings.somenteLeitorDica)`.
- `mercado_screen.dart`: envolver rodapé/faixa "Marcados" em `SafeArea(top: false)`.
- `modal_importar.dart:105-154`: corpo do diálogo em `SingleChildScrollView`.
- `app_botao.dart:77,85` e `app_banner.dart:73`: substituir `SizedBox(width: 12/8)` e ícone 20 por
  tokens (`AppSpacing.sm`, `AppSpacing.md`; ícone por token de tamanho existente ou `AppSpacing.lg`).
- `seletor_tema.dart:67-87`: trocar `DropdownButtonFormField` por `AppDropdown`.
- `router.dart:200,214-217`: `FilledButton` → `AppBotao`; progresso com rótulo semântico.
- `tela_lista_screen.dart:704-744`: ajustar o `suffixIcon`/`prefix` para não estourar a 2x (limitar
  largura do rótulo de unidade/prover `Flexible`), mantendo a interação.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/listas/ test/features/convites/ test/features/importacao/ test/core/`
Expected: PASS.

- [ ] **Step 5: Update the docs owners**

`docs/10-wireframes-telas.md` §3/§6 (dica do leitor, alça 48dp, SafeArea) e `docs/15` §3 (snackbar por
messenger, `AppDropdown` no seletor) — sincronizar o descrito.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test`

- [ ] **Step 7: Commit**

```bash
git add lib/ test/ docs/10-wireframes-telas.md docs/15-design-system.md
git commit -m "F43-T10: a11y e consistencia de UI (G-07..G-09, G-31..G-33, G-36..G-41)"
```

---

### Task 3 (F43-T11) — Erros e validação

**Files:**
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart:200-219`, `lib/features/listas/data/listas_repository.dart:244-260`, `lib/features/listas/ui/sheet_titulo_lista.dart:44-55`, `lib/features/listas/ui/tela_lista_screen.dart:778-780`, `lib/features/listas/ui/mercado_screen.dart:41-53`, `lib/features/importacao/ui/modal_importar.dart:62-77`
- Modify: `docs/05-app-flutter.md` §6
- Test: `test/features/configuracoes/exclusao_conta_test.dart`, `test/features/listas/listas_repository_test.dart`, `test/features/listas/sheet_titulo_lista_test.dart`, `test/features/importacao/modal_importar_test.dart`

**Interfaces:**
- Consumes: `AuthRepository.entrar`, `ListasRepository.definirOrcamento`, `SheetTituloLista`, telas.
- Produces: `definirOrcamento` lança `ArgumentError` fora de `0..99999999`; título limitado a 120.

- [ ] **Step 1: Write the failing tests**

- `exclusao_conta_test.dart`: fake de auth que lança erro genérico (rede) em `entrar` → diálogo mostra
  erro e botão volta a habilitar (sem spinner preso).
- `listas_repository_test.dart`: `definirOrcamento(id, centavos: -1)` e `99999999+1` lançam.
- `sheet_titulo_lista_test.dart`: digitar 200 chars → campo limita a 120 e salva.
- `modal_importar_test.dart`: erro de categoria (Drift) não deixa a tela em `_carregando`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/configuracoes/ test/features/listas/ test/features/importacao/`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

- `configuracoes_screen.dart`: no confirmar exclusão, capturar erro genérico além de `AuthException`,
  exibir inline e garantir `_verificando = false` (em `finally`).
- `listas_repository.dart:244-260`: validar faixa antes do write:

```dart
    if (centavos != null && (centavos < 0 || centavos > 99999999)) {
      throw ArgumentError.value(centavos, 'centavos');
    }
```

- `sheet_titulo_lista.dart`: `maxLength: 120` no `AppCampoTexto` do título (contador já existe no
  componente).
- `tela_lista_screen.dart:778-780` / `mercado_screen.dart:41-53`: `await` + `try/catch` com
  `mostrarSnackBar` de erro (usar string genérica existente de erro de escrita).
- `modal_importar.dart:62-77`: capturar erro genérico de `_extrairLocal`, sempre liberar `_carregando`
  e mostrar mensagem amigável.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/configuracoes/ test/features/listas/ test/features/importacao/`
Expected: PASS.

- [ ] **Step 5: Update the doc owner**

`docs/05` §6 — erros de exclusão de conta, limites de título/orçamento e feedback de falha de escrita.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test`

- [ ] **Step 7: Commit**

```bash
git add lib/features/ test/features/ docs/05-app-flutter.md
git commit -m "F43-T11: erros e validacoes de UI (G-06, G-47, G-49, G-50, G-52)"
```

---

### Task 4 (F43-T12) — Domínio e app

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart:76-80,116-151`, `lib/core/categorias/sugestao_categorias.dart:23-28`, `lib/core/importacao/parser_lista_local.dart:197-229`, `lib/features/notificacoes/data/notificacoes_service.dart:26-59`, `lib/features/notificacoes/providers/notificacoes_providers.dart:22-24`, `lib/features/convites/providers/convites_providers.dart:12-14`, `lib/features/convites/providers/papel_providers.dart:11-13`, `lib/features/configuracoes/ui/configuracoes_screen.dart:34`
- Modify: `pubspec.yaml` (nota de `sqlite3` — sem remover), `docs/03-sincronizacao-offline.md` §3, `docs/04-importacao-lista.md` §3, `docs/05-app-flutter.md` §3/§6
- Test: `test/features/listas/listas_repository_test.dart`, `test/core/categorias/sugestao_categorias_test.dart`, `test/core/importacao/parser_lista_local_test.dart`, `test/features/notificacoes/notificacoes_service_test.dart`, `test/features/listas/lite_ui_test.dart`

**Interfaces:**
- Consumes: `ListaComContagem`, `sugerirCategoria`, `interpretarItemAvulso`, `NotificacoesService`.
- Produces: `ListaComContagem.orcamentoCentavos` preenchido; parser lê `"<nome> <qtd> <un>"` no fim.

- [ ] **Step 1: Write the failing tests**

- `listas_repository_test.dart`: `watchListasComContagem` devolve `orcamentoCentavos` da lista.
- `sugestao_categorias_test.dart`: item de lista soft-deletada não entra na memória.
- `parser_lista_local_test.dart`: `"leite 2 kg"` → nome Leite, qtd 2, un kg (e `"arroz 1 1/2 kg"`).
- `notificacoes_service_test.dart`: `definirAtivas(false)` + `talvezPedirPermissao()` não religa.
- `lite_ui_test.dart`: consumir o provider de notificações/convites no Lite não lança.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/listas/ test/core/categorias/ test/core/importacao/ test/features/notificacoes/`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

- `listas_repository.dart` `watchListasComContagem`: incluir `orcamento_centavos` no SELECT e no
  `ListaComContagem`.
- `sugestao_categorias.dart:23-28`: filtrar itens cujo `lista_id` pertence a lista ativa
  (`l.deletado_em is null`), como em `watchItensFrequentes`.
- `parser_lista_local.dart:197-229`: em `_qtdFim`, aceitar `<nome> <qtd> <un>` separados (reusar
  `_numeroDoToken`/tabela de unidades) antes de desistir.
- `notificacoes_service.dart`: `definirAtivas` marca `_chavePedido = true` para o opt-out ser final
  até o usuário religar no switch.
- Providers de rede: só resolver `Supabase.instance` quando `capacidadesProvider` permitir; no Lite
  retornar um fake/no-op (ou lançar só se consumido — sem tocar no construtor).
- `configuracoes_screen.dart:34`: chamar `aoSair()` também quando a sessão termina (hook no
  bootstrap/logout), não só no botão.
- `pubspec.yaml`: manter `sqlite3` e documentar (comentário) que é dependência direta usada por teste.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/listas/lite_ui_test.dart test/features/notificacoes/ test/core/ test/features/listas/`
Expected: PASS.

- [ ] **Step 5: Update the docs owners**

`docs/03` §3 (descartar `sqlite3`/provider no Lite, token ao fim de sessão), `docs/04` §3 (parser fim),
`docs/05` §3/§6 (orçamento na contagem, memória de categoria, push).

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test`

- [ ] **Step 7: Commit**

```bash
git add lib/ pubspec.yaml test/ docs/03-sincronizacao-offline.md docs/04-importacao-lista.md docs/05-app-flutter.md
git commit -m "F43-T12: dominio, Lite e parser (G-43..G-46, G-48, G-51, G-53)"
```

---

### Task 5 (F43-T13) — Docs e CI, fechamento

**Files:**
- Modify: `docs/07-qualidade-ci.md:64,99,125-132,157`, `README.md:10-12,21-29`, `.github/workflows/ci.yml:16-22,103`, `docs/14-tarefas.md:904,950`, `docs/09-runbook-operacoes.md`
- Test: inspeção (sem teste de código); CI verde

**Interfaces:**
- Consumes: `.github/workflows/ci.yml`, docs donos.
- Produces: docs donos espelhando o CI real; progresso da F43 fechado.

- [ ] **Step 1: Corrigir o doc 07 (G-11)**

- `docs/07:64` e `:99`: `flutter build apk --debug --flavor lite -t lib/main_lite.dart`.
- `docs/07:125-132`: incluir `orcamento_lista_tests.sql` e `push_tokens_tests.sql` (10 scripts).
- `docs/07:157`: "três scripts" → "dez scripts".

- [ ] **Step 2: Limpar o `ci.yml` (G-56)**

Remover o step condicional legado (`check`/`if: ... flutter == 'enabled'`) e o comentário de fase
(`# Fase 4+: ...`), sem alterar jobs/etapas reais.

- [ ] **Step 3: Atualizar o README (G-55, G-58)**

- Inventário RLS: `N-01…N-22` / `P-01…P-12`.
- Documentar flavors (`--flavor prod|lite`, `-t lib/main_lite.dart`), push/Firebase e os builds do CI.
- Nota do `google-services.json`: rastreado; API key Android restrita por package + SHA-1 no console.

- [ ] **Step 4: Corrigir a contagem e o progresso (G-54, G-57)**

- `docs/14:904`: ajustar a contagem citada (695 no HEAD) ou anotar a evolução.
- `docs/14`: marcar `F43-T00…T13` como concluídas, atualizar a linha `F43` na tabela e o total.

- [ ] **Step 5: Verificação final**

Run: `dart format . && flutter analyze && flutter test` · `supabase db reset` + suítes SQL + Deno
Expected: tudo verde (CI).

- [ ] **Step 6: Commit**

```bash
git add docs/ .github/workflows/ci.yml README.md
git commit -m "F43-T13: docs donos e CI sincronizados; Fase 43 fechada (G-11, G-54..G-58)"
```

---

## Auto-revisão do plano B

- **Cobertura do spec:** G-05/G-34/G-35/G-42→T09; G-07…G-09/G-31…G-33/G-36…G-41→T10;
  G-06/G-47/G-49/G-50/G-52→T11; G-43…G-46/G-48/G-51/G-53→T12; G-11/G-54…G-58→T13. Sem lacunas no
  escopo de app/docs.
- **Sem placeholders:** todas as tasks têm teste que falha, implementação e commit; as edições de UI
  indicam o arquivo e a linha e o critério do teste.
- **Consistência de tipos:** `mostrarSnackBar(messenger:)` é definido em T09/T10 e consumido em T10/T11;
  `somenteLeitorDica` definida e consumida em T10; `definirOrcamento` validado em T11 e documentado em
  T12.
