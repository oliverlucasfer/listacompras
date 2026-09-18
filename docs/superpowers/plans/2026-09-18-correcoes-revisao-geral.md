# Fase 20 — Correções da revisão geral: Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir os achados confirmados da revisão geral de 2026-09-18, começando pelos 3 Críticos (parser e sincronização), com TDD e doc dono atualizado no mesmo commit.

**Architecture:** Correções pontuais nos módulos existentes — nenhuma mudança de arquitetura. Cada tarefa altera o menor conjunto de arquivos que fecha o achado, com teste que falha primeiro e o doc dono (`docs/04`, `docs/03`, …) ajustado quando o contrato muda.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Drift (SQLite em memória nos testes), Riverpod, `flutter_test`.

**Spec:** [docs/relatorio-revisao-geral.md](../../relatorio-revisao-geral.md) — achados `R-xx` com evidência `arquivo:linha`. Tarefas em [docs/14-tarefas.md § Fase 20](../../14-tarefas.md).

## Global Constraints

- Comandos do projeto: `flutter test`, `dart format . && flutter analyze` (CI exige os três verdes).
- Nome de teste: `deve_<resultado>_quando_<condição>`.
- Sem comentários novos no código, exceto quando indispensável; pt-BR em docs e UI.
- Nenhuma chave/segredo; nenhuma mudança de schema/RLS fora das tarefas de banco (`F20-T06`, `F20-T11`).
- Commit por tarefa, com o ID (`F20-Tnn`) na mensagem; docs donos no mesmo commit.
- Doc dono é autoridade: se a correção muda o contrato, o dono muda junto.

---

### Task 1 (F20-T01) — CONCLUÍDA: Vírgula decimal no parser — R-01

**Files:**
- Modify: `lib/core/importacao/parser_lista_local.dart:37-56,62-76` (novo helper + uso)
- Modify: `docs/04-importacao-lista.md:36` (§3, item 1 — remover a contradição)
- Test: `test/core/importacao/parser_lista_local_test.dart`

**Interfaces:**
- Consumes: `analisarListaLocal(String texto) → RespostaParse`, `interpretarItemAvulso(String texto, {Unidade unidadePadrao}) → ItemExtraido?` (assinaturas inalteradas).
- Produces: nada novo — só o comportamento de entrada.

- [ ] **Step 1: Write the failing tests**

Adicionar ao fim de `test/core/importacao/parser_lista_local_test.dart`:

```dart
  test('deve_converter_virgula_decimal_quando_1_5_kg', () {
    final r = analisarListaLocal('1,5 kg de arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_segmentar_por_virgula_entre_itens_quando_arroz_leite', () {
    final r = analisarListaLocal('arroz, leite');
    expect(r.itens.map((i) => i.nome), ['Arroz', 'Leite']);
  });

  test('deve_converter_virgula_decimal_no_item_avulso_quando_2_5_leite', () {
    final item = interpretarItemAvulso('2,5 leite');
    expect(item!.quantidade, 2.5);
    expect(item.nome, 'Leite');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: FAIL em `deve_converter_virgula_decimal_quando_1_5_kg` — `itens` tem 2 elementos (`Arroz` com 1 e `5 kg de arroz`), não 1 com 1.5.

- [ ] **Step 3: Write minimal implementation**

Em `lib/core/importacao/parser_lista_local.dart`, junto dos outros `RegExp` (linha ~37):

```dart
/// Vírgula **entre dígitos** é decimal (`1,5`), não separador — o texto é
/// normalizado antes de segmentar (doc 04 §3).
final _decimalComVirgula = RegExp(r'(\d),(\d)');

String _protegerDecimais(String texto) =>
    texto.replaceAllMapped(_decimalComVirgula, (m) => '${m[1]}.${m[2]}');
```

E usar como primeira linha do corpo das duas funções públicas:

```dart
RespostaParse analisarListaLocal(String texto) {
  final normalizado = _protegerDecimais(texto);
  final itens = <ItemExtraido>[];
  var algumSemNumero = false;
  for (final parte in normalizado.split(_separadores)) {
    // ... resto inalterado
```

```dart
ItemExtraido? interpretarItemAvulso(
  String texto, {
  Unidade unidadePadrao = Unidade.un,
}) {
  final partes = _protegerDecimais(texto).split(_separadores);
  // ... resto inalterado
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart`
Expected: PASS (incluindo `deve_segmentar_por_virgula_ponto_e_virgula_linha_e_conjuncao`, que continua válido).

- [ ] **Step 5: Update the doc owner**

`docs/04-importacao-lista.md:36` — trocar:

```
1. Segmenta o texto por `,`, `;`, quebra de linha e o conectivo ` e `.
```

por:

```
1. Normaliza a vírgula **entre dígitos** como decimal (`1,5` → `1.5`) e segmenta o texto por `,`, `;`, quebra de linha e o conectivo ` e ` (vírgula entre itens continua separador: `arroz, leite`).
```

- [ ] **Step 6: Format, analyze e suíte completa**

Run: `dart format . && flutter analyze && flutter test`
Expected: 0 alterados pelo format, `No issues found!`, suíte verde (366 testes + 3 novos).

- [ ] **Step 7: Commit**

```bash
git add lib/core/importacao/parser_lista_local.dart test/core/importacao/parser_lista_local_test.dart docs/04-importacao-lista.md
git commit -m "F20-T01: virgula decimal no parser de importacao (R-01, RF-16)"
```

---

### Task 2 (F20-T02) — CONCLUÍDA: Quantidade ≤ 0 tratada como ausente — R-02

**Files:**
- Modify: `lib/core/importacao/parser_lista_local.dart:78-85,138-172` (`_tinhaNumero`, `_qtdInicio`, `_qtdFim`)
- Modify: `lib/features/importacao/ui/modal_previsao_importacao.dart:254-266` (validação inline)
- Modify: `docs/04-importacao-lista.md` (§3 — nova linha sobre `≤ 0`)
- Test: `test/core/importacao/parser_lista_local_test.dart`, `test/features/importacao/modal_previsao_importacao_test.dart`

**Interfaces:**
- Consumes: `analisarListaLocal`, `interpretarItemAvulso`, `AppStrings.importLocalAvisoPadrao`, `AppStrings.erroQuantidadeInvalida`.
- Produces: garantia de que `ItemExtraido.quantidade > 0` sempre (a UI pode confiar nisso).

- [ ] **Step 1: Write the failing tests**

Em `test/core/importacao/parser_lista_local_test.dart`:

```dart
  test('deve_usar_1_un_e_avisar_quando_quantidade_zero', () {
    final r = analisarListaLocal('0 arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.un);
    expect(r.aviso, isNotNull);
  });

  test('deve_manter_unidade_explicita_quando_quantidade_zero', () {
    final r = analisarListaLocal('0 kg de arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
    expect(r.itens.single.nome, 'Arroz');
    expect(r.aviso, isNotNull);
  });

  test('deve_usar_1_un_quando_quantidade_zero_no_fim', () {
    final r = analisarListaLocal('arroz 0');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.aviso, isNotNull);
  });
```

Em `test/features/importacao/modal_previsao_importacao_test.dart` (usar o helper de pump já existente no arquivo), um teste de widget que edita a quantidade para `0` e confirma que aparece `AppStrings.erroQuantidadeInvalida` e que o item **não** é gravado:

```dart
  testWidgets('deve_bloquear_confirmacao_quando_quantidade_zero', (
    tester,
  ) async {
    await pumpPrevisao(tester, texto: '1 arroz');
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.pump();
    expect(find.text(AppStrings.erroQuantidadeInvalida), findsOneWidget);
  });
```

> Ajustar o nome/assinatura do helper (`pumpPrevisao`) ao que o arquivo já usa — o importante é montar a pré-visualização com `'1 arroz'` e editar a quantidade.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart test/features/importacao/modal_previsao_importacao_test.dart`
Expected: FAIL — `'0 arroz'` devolve `quantidade: 0` e `aviso: null`; o widget não mostra erro para `0`.

- [ ] **Step 3: Write minimal implementation**

Em `parser_lista_local.dart`, substituir `_tinhaNumero` por uma checagem que exige número **positivo**:

```dart
double? _numeroDoToken(String token) {
  final colado = _numeroColado.firstMatch(token);
  if (colado != null) return _paraDouble(colado.group(1)!);
  final numero = _soNumero.firstMatch(token);
  if (numero != null) return _paraDouble(numero.group(1)!);
  return null;
}

bool _tinhaNumero(String parte) {
  final tokens = parte.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty) return false;
  final primeiro = _numeroDoToken(tokens.first);
  if (primeiro != null && primeiro > 0) return true;
  final ultimo = _numeroDoToken(tokens.last);
  return ultimo != null && ultimo > 0;
}
```

E clampar nas duas leituras de quantidade (`_qtdInicio` e `_qtdFim`), trocando `final qtd = _paraDouble(...)` por:

```dart
  final bruto = _paraDouble(numero.group(1)!);
  final qtd = bruto > 0 ? bruto : 1.0;
```

(4 ocorrências: `_numeroColado`/`_soNumero` em `_qtdInicio` e `_qtdFim` — no caso `colado`, usar `colado.group(1)!`.)

Em `modal_previsao_importacao.dart` (`_notificar`, ~linha 265), trocar:

```dart
    final erroQuantidade = lida == null
        ? AppStrings.erroQuantidadeInvalida
        : null;
```

por:

```dart
    final erroQuantidade = (lida == null || lida <= 0)
        ? AppStrings.erroQuantidadeInvalida
        : null;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/importacao/parser_lista_local_test.dart test/features/importacao/`
Expected: PASS.

- [ ] **Step 5: Update the doc owner**

`docs/04-importacao-lista.md` §3 — após o item 3 ("Sem quantidade → `1 un` e marca `aviso`.") inserir:

```
   * Quantidade `≤ 0` é tratada como ausente: entra `1 un` (ou a unidade explícita) e marca `aviso` — `ItemExtraido.quantidade` é sempre `> 0`.
```

- [ ] **Step 6: Format, analyze e suíte completa**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 7: Commit**

```bash
git add lib/core/importacao/parser_lista_local.dart lib/features/importacao/ui/modal_previsao_importacao.dart test/core/importacao/parser_lista_local_test.dart test/features/importacao/modal_previsao_importacao_test.dart docs/04-importacao-lista.md
git commit -m "F20-T02: quantidade invalida vira 1 un e nao derruba a importacao (R-02, RF-16)"
```

---

### Task 3 (F20-T03) — CONCLUÍDA: Preservar mutação enfileirada durante o flush — R-03

**Files:**
- Modify: `lib/features/sync/data/mutacao_sync.dart` (campo `id`)
- Modify: `lib/features/sync/data/sync_engine.dart:215-223,256-263` (`_paraSync`, `_removerRegistro`)
- Modify: `docs/03-sincronizacao-offline.md` §4 (nota de robustez)
- Test: `test/features/sync/sync_engine_test.dart`

**Interfaces:**
- Consumes: `SyncEngine(db:, remoto:, …)`, `ListasRepository.adicionarItem/editarItem`, fake `RemotoFake` do teste.
- Produces: `MutacaoSync.id` (`int`, default `0` = "não veio da fila") e `_removerRegistro(String tabela, String registroId, int ateId)`.

- [ ] **Step 1: Write the failing test**

Em `test/features/sync/sync_engine_test.dart`, adicionar o fake e o teste:

```dart
/// Servidor fake que dispara um callback enquanto "envia" — usado para
/// simular uma edição do usuário durante o await de rede (R-03).
class RemotoQueEditaAoEnviar implements SyncRemoto {
  RemotoQueEditaAoEnviar(this.aoEnviar);

  final Future<void> Function(MutacaoSync mutacao) aoEnviar;
  final recebidas = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    recebidas.add(mutacao);
    if (recebidas.length == 1) await aoEnviar(mutacao);
    return const Enviado();
  }
}
```

```dart
  test('deve_manter_na_fila_mutacao_enfileirada_durante_o_flush', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final remoto = RemotoQueEditaAoEnviar((mutacao) async {
      if (mutacao.tabela == 'itens_lista') {
        await repo.editarItem(item.id, nome: 'Arroz integral');
      }
    });
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    final nomesEnviados = remoto.recebidas
        .where((m) => m.tabela == 'itens_lista')
        .map((m) => m.payload['nome'])
        .toList();
    expect(nomesEnviados, contains('Arroz integral'));
    expect(await mutacoesNaFila(), 0);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sync/sync_engine_test.dart --plain-name deve_manter_na_fila_mutacao_enfileirada_durante_o_flush`
Expected: FAIL — `nomesEnviados` só tem `Arroz` (a mutação nova é apagada por `_removerRegistro`).

- [ ] **Step 3: Write minimal implementation**

`lib/features/sync/data/mutacao_sync.dart` — novo campo com default (compatível com quem constrói à mão):

```dart
  const MutacaoSync({
    // ...
    this.id = 0,
    // ...
  });

  /// Id da linha em `mutacao_pendente` (0 quando a mutação não veio da fila).
  final int id;
```

`sync_engine.dart` — `_paraSync` propaga o id:

```dart
  MutacaoSync _paraSync(MutacaoPendenteData linha) => MutacaoSync(
    id: linha.id,
    // ... demais campos inalterados
  );
```

E a remoção passa a respeitar o lote:

```dart
  /// Sucesso apaga as linhas do registro sombreadas pelo coalescing **até o
  /// id do lote** — mutações enfileiradas durante o envio (id maior) ficam
  /// para o próximo ciclo (doc 03 §4, R-03).
  Future<void> _removerRegistro(String tabela, String registroId, int ateId) {
    return (_db.delete(_db.mutacaoPendente)..where(
          (m) =>
              m.tabela.equals(tabela) &
              m.registroId.equals(registroId) &
              m.id.isSmallerOrEqualValue(ateId),
        ))
        .go();
  }
```

Atualizar as 3 chamadas em `_drenar` (`:126`, `:131`, `:138`) para `_removerRegistro(mutacao.tabela, mutacao.registroId, mutacao.id)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sync/`
Expected: PASS (os testes existentes de coalescing/LWW/duplicado continuam verdes).

- [ ] **Step 5: Update the doc owner**

`docs/03-sincronizacao-offline.md` §4 — no bloco de robustez (após a linha 78), acrescentar:

```
> **Coalescing e concorrência:** a remoção pós-envio apaga apenas as mutações do
> registro que estavam no lote enviado (id ≤ id do lote). Uma edição feita pelo
> usuário durante o `await` de rede permanece na fila e sobe no ciclo seguinte —
> nunca é descartada (R-03 da revisão geral).
```

- [ ] **Step 6: Format, analyze e suíte completa**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 7: Commit**

```bash
git add lib/features/sync/data/mutacao_sync.dart lib/features/sync/data/sync_engine.dart test/features/sync/sync_engine_test.dart docs/03-sincronizacao-offline.md
git commit -m "F20-T03: nao descarta mutacao enfileirada durante o flush (R-03, RF-08)"
```

---

## Tarefas seguintes (T04–T12) — mesmo ciclo TDD, detalhadas ao serem iniciadas

Cada uma segue os 7 passos da Task 1 (teste que falha → confirmar falha → implementação mínima → verde → doc dono → `format`/`analyze`/`test` → commit `F20-Tnn`). Mapa de arquivos e teste-âncora:

- **F20-T04** (R-04, R-05) — CONCLUÍDA — `lib/features/sync/data/sync_engine.dart`: `flush()` com laço interno no lugar da reentrância (`:89-107`) e bootstrap derivando o status da fila (`iniciar`, `:63-82`, `_temEnviaveis`). Testes: `deve_drenar_em_um_unico_ciclo_quando_mutacao_chega_durante_o_flush`, `deve_expor_erro_quando_fila_esgotada_no_bootstrap`. Doc: `03 §4/§6`.
- **F20-T05** (R-06) — CONCLUÍDA — `lib/features/sync/data/*`: comparar `ts_local` com o `now()` do servidor (retorno do upsert), injetável para teste; `_reportarSeRelogioAdiantado` deixa de usar `DateTime.now()`. Teste: `deve_reportar_relogio_adiantado_quando_servidor_esta_atras`, `deve_ignorar_quando_dentro_da_tolerancia`. Doc: `03 §5`, `07 §4`.
- **F20-T06** (R-09, R-17) — CONCLUÍDA — só docs: `01 §7` e §4 incluem `lista_membros`/`convites` no publication e no inventário; `02 §2` idem; `06 §4` e ADR-013 sem afirmar deploy entregue (remeter à F19-T03); `07 §3` espelhando `ci.yml:5-8`; cascata de `convites.criado_por` na lista do `06 §3.3.1`. Sem teste; CP = `git diff` só em docs.
- **F20-T07** (R-10) — CONCLUÍDA — `.github/workflows/ci.yml` (step novo no job `supabase`, com `node supabase/tests/realtime_test.mjs` após exportar as chaves do stack), `supabase/tests/package.json` (`npm test` real) e `supabase/tests/realtime_test.mjs` (contas via `admin.createUser` + login por senha, lista criada pelo cliente — o teste estava obsoleto e não passava em nenhum CI). Doc: `02 §5`/`07 §3`. Descobriu o **R-23** (publishable key não entrega Realtime local).
- **F20-T08** (R-07) — CONCLUÍDA — `lib/features/convites/ui/sheet_convidar.dart` (botão "Revogar link" com `AppBotaoVariante.texto`, estado `_revogando`, volta ao início e SnackBar) + `AppStrings.revogarConvite`/`conviteRevogado`. Testes: widget (PATCH `estado=revogado`, volta ao início) e repositório já cobria `revogar`.
- **F20-T09** (R-08) — CONCLUÍDA — `lib/core/categorias/sugestao_categorias.dart`: desempate em 4 níveis (mais palavras no termo → termo que aparece **primeiro** no nome → mais longo → alfabético) e match por **sequência** de palavras; `'suco de laranja'` e `'suco de uva'` agora dão a mesma categoria (bebidas). Testes: `suco de laranja`→bebidas, `suco de uva`→bebidas, `laranja`→hortifruti, `leite condensado`→mercearia, composto e fallback. Doc: `04 §5`.
- **F20-T10** (R-11, R-12) — CONCLUÍDA — `supabase_bootstrap.dart` (`subscribe` com callback de status e `_aoMudarStatusCanal`: re-sync em `SUBSCRIBED`, com `_disposed` de guarda) e teste de 2 contas medido no stack local para a remoção de membro. Doc: `08 §9` (nova seção de perda de acesso), `03 §4/§7`. **R-11 medido como real:** o `old_record` chega **vazio** no DELETE de `lista_membros` apesar do `replica identity full` (relreplident = `f`), porque o Realtime v2.34 decide pela coluna `_realtime.tenants.private_only` (`false` no stack local, sem opção no `config.toml` do CLI 2.116) — a limpeza por evento fica impossível hoje e foi documentada com as vias confiáveis. **R-23 retirado** (falso positivo: 12 cenários reconfirmados; era a primeira conexão WS pós-`db reset`).
- **F20-T11** (R-18, R-19) — migration nova `0015_convites_updated_e_insert_dono.sql`: policy de insert de `lista_membros` sem `papel='dono'` para terceiro, trigger de `atualizado_em` em `convites`; testes de negação em `supabase/tests/rls_tests.sql`. Docs: `01`, `02 §4.3`.
- **F20-T12** (R-13…R-16, R-20, R-21) — `lib/main.dart:50-53` (`beforeSend` limpando `extra`/`contexts`/mensagem), `lib/router.dart:174-182` (i18n + tokens), `lib/core/l10n/politica_privacidade.dart:2` (comentário), `pubspec.yaml:38,50` (deps — checar o pin do WASM antes de remover `sqlite3`), ajustes de a11y (`app_logo.dart:26`, `indicador_sync.dart:28-31`, `seletor_tema.dart`, telas sem scroll) e CSP em `firebase.json`/`web/index.html` como decisão documentada em `06 §3.4`. Docs: `05 §7`, `07 §4`, `15 §4`.

## Auto-revisão do plano

- **Cobertura do relatório:** R-01→T01, R-02→T02, R-03→T03, R-04/R-05→T04, R-06→T05, R-07→T08, R-08→T09, R-09→T06, R-10→T07, R-11/R-12→T10, R-13…R-16/R-20/R-21→T12, R-17→T06/T11, R-18/R-19→T11. Sem lacunas.
- **Sem placeholders:** T01–T03 têm teste, implementação e commits literais; T04–T12 têm arquivo, teste-âncora e CP.
- **Consistência de tipos:** `MutacaoSync.id` (`int`, default 0) usado só por `_paraSync` e `_removerRegistro(…, ateId)`; `_numeroDoToken` é privado do parser; nenhum nome novo fora dos arquivos citados.
