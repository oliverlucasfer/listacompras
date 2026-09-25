# Fase 43 — Correções da revisão geral 2 (Dados & Segurança): Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir os achados `G-xx` de backup, sincronização e banco/RLS da revisão geral 2, com TDD e doc dono atualizado no mesmo commit.

**Architecture:** Correções pontuais nos módulos existentes — nenhuma mudança de arquitetura. Cada tarefa altera o menor conjunto de arquivos que fecha o achado, com teste que falha primeiro; correções de banco entram em migration nova (`0023+`) porque `0001`–`0022` já foram aplicadas em produção.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Drift (SQLite em memória nos testes), Riverpod, `flutter_test`, Postgres/Supabase local (CLI 2.116.0), `supabase/tests/*.sql`.

**Spec:** [docs/superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md](../specs/2026-09-25-correcoes-revisao-geral-2-design.md) · Achados: [docs/relatorio-revisao-geral-2.md](../../relatorio-revisao-geral-2.md) · Tarefas: [docs/14-tarefas.md](../../14-tarefas.md) § Fase 43.

## Global Constraints

- Comandos do projeto: `flutter test`, `dart format . && flutter analyze` (CI exige os três verdes); banco: `supabase db reset` e as suítes `supabase/tests/`.
- Nome de teste: `deve_<resultado>_quando_<condição>`.
- Sem comentários novos no código, exceto quando indispensável; pt-BR em docs e UI.
- Nenhuma chave/segredo; migrations **novas** (`0023+`), nunca editando as já aplicadas.
- Commit por tarefa, com o ID (`F43-Tnn`) na mensagem; docs donos no mesmo commit.
- Doc dono é autoridade: se a correção muda o contrato, o dono muda junto.

---

### Task 1 (F43-T00) — Registrar o relatório 2 e a Fase 43 no doc 14

**Files:**
- Modify: `docs/14-tarefas.md` (nova seção "Fase 43" + 2 linhas na tabela de progresso)

**Interfaces:**
- Consumes: `docs/relatorio-revisao-geral-2.md`, `docs/superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md`.
- Produces: IDs `F43-T00…T13` referenciados pelos dois planos.

- [ ] **Step 1: Inserir a seção da fase antes de "## Progresso por fase"**

Inserir em `docs/14-tarefas.md`, logo após a Fase 42 (antes de `## Progresso por fase (atualize ao concluir)`):

```markdown
## Fase 43 — Correções da revisão geral 2 (RNF-08)

Fonte: [relatorio-revisao-geral-2.md](relatorio-revisao-geral-2.md) · Spec: [superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md](superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md) · Docs donos: 01, 02, 03, 04, 05, 06, 07, 10, 15.

- [ ] **F43-T00** — Registrar o relatório 2 e a Fase 43
  Dep: — · Docs: [14](14-tarefas.md), [relatório](relatorio-revisao-geral-2.md)
  CP: relatório `G-01…G-58` e spec na árvore; Fase 43 no 14 com progresso; sem tocar código.
- [ ] **F43-T01** — Backup: exportar o banco inteiro e erro de restauração (G-01, G-10)
  Dep: F43-T00 · Docs: [05](05-app-flutter.md) §6.10
  CP: exportar→importar com lista soft-deletada não lança FK; item sem lista → erro de restauração distinto.
- [ ] **F43-T02** — Sync: dedup com coalescing (G-02)
  Dep: F43-T00 · Docs: [03](03-sincronizacao-offline.md) §5
  CP: item criado+editado offline com duplicado remoto vira `Duplicado`; `23505` refaz a dedup.
- [ ] **F43-T03** — Sync: robustez do flush e do canal (G-12…G-15, G-19, G-20)
  Dep: F43-T00 · Docs: [03](03-sincronizacao-offline.md) §3/§4/§7
  CP: falha não incrementa mutação fora do lote; coalescing por `ts_local`; relatório na 6ª falha; canal re-sincroniza em erro.
- [ ] **F43-T04** — Sync: histórico no logout e paginação (G-16, G-18)
  Dep: F43-T00 · Docs: [03](03-sincronizacao-offline.md) §7
  CP: histórico de preços limpo na troca de usuário; download pagina até esgotar.
- [ ] **F43-T05** — Repositórios: escrita local + fila atômicas (G-17)
  Dep: F43-T00 · Docs: [03](03-sincronizacao-offline.md) §3
  CP: falha simulada no enfileiramento reverte o write local; suíte verde.
- [ ] **F43-T06** — RLS: `deletado_em` imutável para editor (G-03)
  Dep: F43-T00 · Docs: [02](02-seguranca-rls.md) §3/§4.1
  CP: migration `0023`; editor não altera `deletado_em`; dono exclui; testes SQL verdes.
- [ ] **F43-T07** — Banco: PII no `excluir_conta`, `revoke` e CHECK de convites (G-04, G-22, G-24)
  Dep: F43-T00 · Docs: [01](01-banco-de-dados.md), [02](02-seguranca-rls.md), [06](06-mvp-entregas.md)
  CP: convites do e-mail do titular somem; anon não executa `aceitar_convite`; `tipo`↔`email` coerentes.
- [ ] **F43-T08** — Banco: higiene de policies/limites e `search_path` (G-23, G-26, G-27, G-29, G-30)
  Dep: F43-T00 · Docs: [01](01-banco-de-dados.md), [02](02-seguranca-rls.md)
  CP: policies restritas, CHECKs de tamanho, definers com `search_path=''`; testes SQL verdes.
- [ ] **F43-T09** — i18n Material e strings (G-05, G-34, G-35, G-42)
  Dep: F43-T00 · Docs: [05](05-app-flutter.md) §7, [15](15-design-system.md) §4
  CP: tooltips nativos em pt-BR; strings órfãs removidas; e-mail com fallback.
- [ ] **F43-T10** — UI e a11y (G-07…G-09, G-31…G-33, G-36…G-41)
  Dep: F43-T00 · Docs: [10](10-wireframes-telas.md), [15](15-design-system.md)
  CP: esqueleto na lista, alça 48dp, campo do link rotulado, snackbars no helper, SafeArea no mercado.
- [ ] **F43-T11** — Erros e validação (G-06, G-47, G-49, G-50, G-52)
  Dep: F43-T00 · Docs: [05](05-app-flutter.md)
  CP: exclusão de conta não trava no erro de rede; título/orçamento validados; falhas da UI tratadas.
- [ ] **F43-T12** — Domínio e app (G-43…G-46, G-48, G-51, G-53)
  Dep: F43-T00 · Docs: [03](03-sincronizacao-offline.md), [04](04-importacao-lista.md), [05](05-app-flutter.md)
  CP: orçamento na contagem; opt-out estável; Lite sem `Supabase.instance`; parser lê `"leite 2 kg"`.
- [ ] **F43-T13** — Docs e CI (G-11, G-54…G-58)
  Dep: F43-T00 · Docs: [07](07-qualidade-ci.md), [09](09-runbook-operacoes.md), [14](14-tarefas.md)
  CP: doc 07 espelha o `ci.yml`; progresso do 14 coerente; README/flavors atualizados.
```

- [ ] **Step 2: Atualizar a tabela de progresso**

Em `docs/14-tarefas.md`, corrigir a linha `| F5 Publicação | 7 | 5 |` (manter `5`, é o real) — o total passa a refletir tarefas abertas. Adicionar, ao fim da tabela (antes de `| **Total** |`):

```markdown
| F43 Correções da revisão 2 | 14 | 0 |
```

E trocar o rodapé `| **Total** | **224** | **224** |` por `| **Total** | **238** | **224** |`.

- [ ] **Step 3: Commit das docs de planejamento**

```bash
git add docs/14-tarefas.md docs/relatorio-revisao-geral-2.md docs/superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md docs/superpowers/plans/2026-09-25-correcoes-revisao-2-dados-seguranca.md docs/superpowers/plans/2026-09-25-correcoes-revisao-2-app-docs.md
git commit -m "F43-T00: relatorio da revisao geral 2 e Fase 43 no breakdown (RNF-08)"
```

---

### Task 2 (F43-T01) — Backup: exportar tudo e erro de restauração

**Files:**
- Modify: `lib/features/backup/data/backup_repository.dart:10-17,42-49,104-227`
- Modify: `lib/features/backup/ui/secao_backup.dart:124-138`
- Modify: `lib/core/l10n/app_strings.dart` (nova string `backupRestauracaoErro`)
- Modify: `docs/05-app-flutter.md` §6.10
- Test: `test/features/backup/backup_export_test.dart`, `test/features/backup/backup_import_test.dart`, `test/features/backup/secao_backup_test.dart`

**Interfaces:**
- Consumes: `BackupRepository.exportarJson() → Future<String>`, `importarJson(String) → Future<void>`, `ListasRepository.excluirLista(String)`.
- Produces: `class BackupRestauracaoException implements Exception` (nova) — a UI a distingue de `BackupInvalidoException`.

- [ ] **Step 1: Write the failing tests**

Em `test/features/backup/backup_export_test.dart`, adicionar:

```dart
  test('deve_exportar_lista_excluida_com_seus_itens_quando_soft_delete', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final lista = await listas.criarLista(titulo: 'Mercado', donoId: 'local');
    await listas.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await listas.excluirLista(lista.id);

    final json = await BackupRepository(db).exportarJson();
    final mapa = jsonDecode(json) as Map<String, dynamic>;

    expect((mapa['listas'] as List), hasLength(1));
    expect((mapa['itens'] as List), hasLength(1));
    expect(
      (mapa['listas'] as List).single['deletado_em'],
      isNotNull,
      reason: 'o backup é fiel ao banco',
    );
  });
```

Em `test/features/backup/backup_import_test.dart`, adicionar:

```dart
  test('deve_restaurar_backup_com_lista_excluida_quando_export_completo', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    final repoOrigem = ListasRepository(origem);
    final lista = await repoOrigem.criarLista(titulo: 'Mercado', donoId: 'local');
    await repoOrigem.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repoOrigem.excluirLista(lista.id);
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    expect(await destino.select(destino.listaLocal).get(), hasLength(1));
    expect(await destino.select(destino.itemLocal).get(), hasLength(1));
  });

  test('deve_lancar_restauracao_quando_item_sem_lista', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const json =
        '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z","listas":[],'
        '"itens":[{"id":"i1","lista_id":"l1","nome":"Arroz","quantidade":1.0,'
        '"unidade":"un","categoria":"outros","preco_centavos":null,'
        '"concluido":false,"ordem":0,"created_at":"2026-01-01T00:00:00Z",'
        '"updated_at":"2026-01-01T00:00:00Z","deletado_em":null}],'
        '"historicoPrecos":[]}';
    await expectLater(
      BackupRepository(db).importarJson(json),
      throwsA(isA<BackupRestauracaoException>()),
    );
    expect(await db.select(db.itemLocal).get(), isEmpty);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/backup/`
Expected: FAIL — o 1º export tem 0 listas; a importação da lista excluída lança `SqliteException` (FK) em vez de sucesso; `BackupRestauracaoException` não existe.

- [ ] **Step 3: Write minimal implementation**

Em `backup_repository.dart`, adicionar a exceção antes de `BackupRepository`:

```dart
/// Backup válido, mas que não pôde ser restaurado (FK/CHECK). O banco é
/// revertido pela transação.
class BackupRestauracaoException implements Exception {
  const BackupRestauracaoException(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'BackupRestauracaoException: $mensagem';
}
```

Remover os filtros de `exportarJson` (os dois `..where(...)`), deixando:

```dart
    final listas = await _db.select(_db.listaLocal).get();
    final itens = await _db.select(_db.itemLocal).get();
    final historico = await _db.select(_db.historicoPrecoLocal).get();
```

Reestruturar o `try` de `importarJson` para classificar os erros (o `transaction` continua íntegro):

```dart
  Future<void> importarJson(String conteudo) async {
    late final BackupArquivo arquivo;
    try {
      final mapa = jsonDecode(conteudo) as Map<String, dynamic>;
      if (mapa['versao'] != BackupArquivo.versao) {
        throw BackupInvalidoException(
          'Versão de backup não suportada: ${mapa['versao']}',
        );
      }
      arquivo = BackupArquivo.fromJson(mapa);
    } on BackupInvalidoException {
      rethrow;
    } on FormatException {
      throw const BackupInvalidoException('JSON inválido');
    } on TypeError {
      throw const BackupInvalidoException('JSON inválido');
    }

    try {
      await _db.transaction(() async {
        // ... corpo atual inalterado ...
      });
    } on BackupInvalidoException {
      rethrow;
    } catch (e) {
      throw BackupRestauracaoException(e.toString());
    }
  }
```

Em `secao_backup.dart`, no catch do import (por volta de `:124-138`), separar os casos:

```dart
    } on BackupInvalidoException catch (_) {
      mensagemErro = AppStrings.backupInvalido;
    } on BackupRestauracaoException catch (_) {
      mensagemErro = AppStrings.backupRestauracaoErro;
    } catch (_) {
      mensagemErro = AppStrings.backupLeituraErro;
    }
```

Em `app_strings.dart`, adicionar junto das demais strings de backup:

```dart
  static const backupRestauracaoErro =
      'Não foi possível restaurar o backup neste aparelho.';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/backup/`
Expected: PASS (os testes antigos de LWW/erro continuam válidos; o de "campos inválidos" segue `BackupInvalidoException`).

- [ ] **Step 5: Update the doc owner**

`docs/05-app-flutter.md` §6.10 — registrar que o backup exporta o banco inteiro (inclusive listas
excluídas, para a FK do restore) e que a UI distingue arquivo inválido de falha de restauração.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test test/features/backup/`
Expected: 0 alterados, `No issues found!`, verde.

- [ ] **Step 7: Commit**

```bash
git add lib/features/backup/data/backup_repository.dart lib/features/backup/ui/secao_backup.dart lib/core/l10n/app_strings.dart test/features/backup/ docs/05-app-flutter.md
git commit -m "F43-T01: backup completo e erro de restauracao distinto (G-01, G-10, RF-31)"
```

---

### Task 3 (F43-T02) — Sync: dedup com coalescing

**Files:**
- Modify: `lib/features/sync/data/supabase_sync_remoto.dart:63-120`
- Modify: `docs/03-sincronizacao-offline.md` §5
- Test: `test/features/sync/supabase_sync_remoto_enviar_test.dart`

**Interfaces:**
- Consumes: `SupabaseSyncRemoto.enviar(MutacaoSync) → Future<ResultadoEnvio>`, `ServidorFake` de `test/features/convites/servidor_fake.dart`.
- Produces: nada novo — comportamento do `enviar` para `itens_lista` sem linha remota.

- [ ] **Step 1: Write the failing tests**

Em `supabase_sync_remoto_enviar_test.dart`, adicionar helpers de item e os testes:

```dart
const _listaId = '22222222-2222-3333-4444-555555555555';

Map<String, Object?> _payloadItem({required String updatedAt, String? nome}) => {
  'id': _id,
  'lista_id': _listaId,
  'nome': nome ?? 'Arroz',
  'quantidade': 1.0,
  'unidade': 'un',
  'categoria': 'outros',
  'preco_centavos': null,
  'concluido': false,
  'ordem': 0,
  'created_at': '2026-09-04T12:00:00.000Z',
  'updated_at': updatedAt,
  'deletado_em': null,
};

MutacaoSync _mutacaoItem({required String operacao, required String updatedAt}) =>
    MutacaoSync(
      tabela: 'itens_lista',
      operacao: operacao,
      registroId: _id,
      listaId: _listaId,
      tsLocal: DateTime.utc(2026, 9, 4, 12),
      payload: _payloadItem(updatedAt: updatedAt),
    );

  test('deve_deduplicar_quando_update_coalescido_sem_linha_remota', () async {
    final remoto = _payloadItem(
      updatedAt: '2026-09-04T11:00:00.000Z',
      nome: 'Arroz',
    )..['id'] = '99999999-9999-9999-9999-999999999999';
    final servidor = ServidorFake((req) {
      if (req.method == 'GET') {
        return (200, req.url.path.endsWith('itens_lista') ? [remoto] : <Object>[]);
      }
      if (req.method == 'PATCH') return (204, <Object>[]);
      if (req.method == 'POST') return (201, <Object>[]);
      return (500, {'message': 'inesperado ${req.method} ${req.url.path}'});
    });
    addTearDown(servidor.close);

    final resultado = await _remotoCom(servidor).enviar(
      _mutacaoItem(operacao: 'UPDATE', updatedAt: '2026-09-04T13:00:00.000Z'),
    );

    expect(resultado, isA<Duplicado>());
    expect(servidor.pedidos.any((p) => p.method == 'PATCH'), isTrue);
    expect(servidor.pedidos.any((p) => p.method == 'POST'), isFalse);
  });

  test('deve_deduplicar_quando_insert_leva_23505', () async {
    var gets = 0;
    final servidor = ServidorFake((req) {
      if (req.method == 'GET') {
        gets++;
        // 1ª consulta (registro por id): vazio; 2ª (duplicado): acha.
        if (gets == 1) return (200, <Object>[]);
        return (200, [
          _payloadItem(updatedAt: '2026-09-04T11:00:00.000Z')
            ..['id'] = '99999999-9999-9999-9999-999999999999',
        ]);
      }
      if (req.method == 'POST') {
        return (409, {'code': '23505', 'message': 'duplicate key'});
      }
      if (req.method == 'PATCH') return (204, <Object>[]);
      return (500, {'message': 'inesperado'});
    });
    addTearDown(servidor.close);

    final resultado = await _remotoCom(servidor).enviar(
      _mutacaoItem(operacao: 'INSERT', updatedAt: '2026-09-04T13:00:00.000Z'),
    );

    expect(resultado, isA<Duplicado>());
  });
```

> O `ServidorFake` já é usado no arquivo; se o `GET` de `.select().eq('id').maybeSingle()` não casar
> com o filtro por path, ajuste o predicado para o path real de `itens_lista` inspecionando
> `servidor.pedidos` (o teste de listas já distingue INSERT/PATCH).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/sync/supabase_sync_remoto_enviar_test.dart`
Expected: FAIL — no UPDATE coalescido o código não consulta duplicado e faz `POST`; o `23505` propaga como erro.

- [ ] **Step 3: Write minimal implementation**

Em `supabase_sync_remoto.dart`, extrair a dedup e chamá-la para item vivo sem linha remota, com catch de `23505`:

```dart
    final tentarDedup = registro == null &&
        mutacao.tabela == 'itens_lista' &&
        mutacao.payload['deletado_em'] == null;
    if (tentarDedup) {
      final duplicado = await _buscarDuplicado(mutacao);
      if (duplicado != null) return _mesclarEDevolver(tabela, duplicado, mutacao);
    }
    try {
      if (registro == null) {
        await tabela.insert(mutacao.payload);
      } else {
        await tabela.update(mutacao.payload).eq('id', mutacao.registroId);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505' || mutacao.tabela != 'itens_lista') rethrow;
      final duplicado = await _buscarDuplicado(mutacao);
      if (duplicado == null) rethrow;
      return _mesclarEDevolver(tabela, duplicado, mutacao);
    }
    return const Enviado();
```

Com o helper:

```dart
  Future<ResultadoEnvio> _mesclarEDevolver(
    PostgrestFilterBuilder<dynamic> tabela,
    Map<String, Object?> duplicado,
    MutacaoSync mutacao,
  ) async {
    final mesclado = mesclarDuplicado(duplicado, mutacao.payload);
    if (mesclado == null) return Duplicado(duplicado);
    await tabela.update(mesclado).eq('id', mesclado['id']!);
    return Duplicado(mesclado);
  }
```

Remover o bloco `if (mutacao.operacao == 'INSERT')` antigo (a dedup agora cobre INSERT e UPDATE).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sync/supabase_sync_remoto_enviar_test.dart test/features/sync/`
Expected: PASS.

- [ ] **Step 5: Update the doc owner**

`docs/03-sincronizacao-offline.md` §5 — anotar que a dedup roda em qualquer item vivo sem linha
remota (INSERT ou UPDATE resultante do coalescing), com o `23505` como rede de segurança.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test test/features/sync/`

- [ ] **Step 7: Commit**

```bash
git add lib/features/sync/data/supabase_sync_remoto.dart test/features/sync/supabase_sync_remoto_enviar_test.dart docs/03-sincronizacao-offline.md
git commit -m "F43-T02: dedup cobre update coalescido e violacao 23505 (G-02, RF-10)"
```

---

### Task 4 (F43-T03) — Sync: robustez do flush e do canal

**Files:**
- Modify: `lib/features/sync/data/sync_engine.dart:224-259,296-357`
- Modify: `lib/drift/tables/mutacao_pendente.dart:11`, `lib/features/sync/data/sync_remoto.dart:38-39`
- Modify: `lib/features/sync/data/supabase_bootstrap.dart:237-242`
- Modify: `lib/features/sync/data/aplicador_remoto.dart:14`
- Modify: `docs/03-sincronizacao-offline.md` §3/§4/§7
- Test: `test/features/sync/sync_engine_test.dart`, `test/features/sync/supabase_bootstrap_test.dart`

**Interfaces:**
- Consumes: `SyncEngine`, `_proximoLote`, `_paraSync`, `_registrarFalha`, `_reportarFalha`, `supabase_bootstrap.dart::_aoMudarStatusCanal`.
- Produces: `_proximoLote` escolhe o vencedor por `ts_local`; `_registrarFalha` respeita o lote.

- [ ] **Step 1: Write the failing tests**

Em `test/features/sync/sync_engine_test.dart` (usar os helpers/fakes já existentes no arquivo):

```dart
  test('deve_nao_incrementar_tentativas_de_mutacao_fora_do_lote', () async {
    // Mede que uma edição enfileirada durante o envio não queima tentativa.
    // Reaproveita RemotoQueEditaAoEnviar do teste de R-03, com falha na 2ª.
  });

  test('deve_eleger_ultima_por_ts_local_quando_coalescing', () async {
    // Insere duas mutações do mesmo registro com ids invertidos ao ts_local.
  });

  test('deve_reportar_tentativas_altas_na_sexta_falha', () async {
    // Fonte de relatório captura o contexto na 6ª falha consecutiva.
  });
```

> Use os fakes existentes (`RemotoFake`, captura de `_reportar`); o nome do helper de espera é o
> do arquivo (`aguardarSincronizado`/equivalente). O importante é: (a) falhar no 2º envio enquanto
> uma nova mutação entra na fila e conferir `tentativas` dela = 0; (b) inserir por SQL linhas com
> `id`/`ts_local` conflitantes e conferir o payload vencedor; (c) contar o evento na 6ª falha.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/sync/sync_engine_test.dart`
Expected: FAIL nos três (a mutação nova ganha tentativa; o vencedor é o de maior id; o evento sai na 7ª).

- [ ] **Step 3: Write minimal implementation**

`_proximoLote` — eleger por `ts_local` e devolver o `ateId` do grupo:

```dart
    final doGrupo = linhas.where((m) => m.listaId == listaId).toList();
    final porRegistro = <String, MutacaoPendenteData>{};
    final payloadMesclado = <String, Map<String, Object?>>{};
    final ateId = <String, int>{};
    for (final linha in doGrupo) {
      final atual = jsonDecode(linha.payload) as Map<String, Object?>;
      payloadMesclado.update(
        linha.registroId,
        (anterior) => {...anterior, ...atual},
        ifAbsent: () => atual,
      );
      ateId.update(
        linha.registroId,
        (max) => linha.id > max ? linha.id : max,
        ifAbsent: () => linha.id,
      );
      final atualVencedor = porRegistro[linha.registroId];
      if (atualVencedor == null ||
          linha.tsLocal.isAfter(atualVencedor.tsLocal) ||
          (linha.tsLocal == atualVencedor.tsLocal &&
              linha.id > atualVencedor.id)) {
        porRegistro[linha.registroId] = linha;
      }
    }
```

`_paraSync` passa a expor o `ateId` do grupo para a remoção — troque a assinatura e a construção do
lote para propagar `ateId` em `MutacaoSync` (já existe `id`; a remoção usa `_removerRegistro(..., idDoGrupo)`,
guardado em um `Map<String,int>` local a `_drenar`), ou use o maior `id` das linhas do grupo no
momento da remoção. Implemente mantendo o menor diff: reutilize `mutacao.id` como id do lote e
remova o registro com o **maior id do grupo** (que é o `id` da última linha por `id`, não do
vencedor por ts). Para isso, `_drenar` pode ler `await _maiorIdDoRegistro(tabela, registroId)` antes
de `_removerRegistro`.

`_registrarFalha` — limitar ao lote:

```dart
  Future<void> _registrarFalha(List<MutacaoSync> lote) async {
    for (final mutacao in lote) {
      await _db.customUpdate(
        'UPDATE mutacao_pendente SET tentativas = tentativas + 1 '
        'WHERE tabela = ? AND registro_id = ? AND id <= ?',
        variables: [
          Variable(mutacao.tabela),
          Variable(mutacao.registroId),
          Variable(mutacao.id),
        ],
      );
    }
  }
```

`_reportarFalha` — usar tentativas pós-incremento (some 1, pois o lote foi lido antes):

```dart
    final maiorTentativas = lote.fold<int>(
      0,
      (maior, m) => (m.tentativas + 1) > maior ? m.tentativas + 1 : maior,
    );
```

`mutacao_pendente.dart:11` e `sync_remoto.dart:38-39` — alinhar o comentário de `ts_local` ao uso
real (`payload['updated_at']` é o carimbo do LWW; `ts_local` é a hora da fila).

`supabase_bootstrap.dart:237-242` — também agir em erro do canal:

```dart
  void _aoMudarStatusCanal(RealtimeSubscribeStatus status) {
    if (_disposed) return;
    if (status == RealtimeSubscribeStatus.subscribed) {
      unawaited(_sincronizarERegistrarPapel());
      return;
    }
    if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut) {
      unawaited(_sincronizarERegistrarPapel());
    }
  }
```

`aplicador_remoto.dart:14` — não abortar a cadeia por FK do pai ausente:

```dart
    try {
      await _db.into(_db.itemLocal).insertOnConflictUpdate(...);
    } on SqliteException {
      // pai (lista) ainda não chegou; o próximo sync/re-sync reconcilia
    }
```

> Ajuste o tipo da exceção ao que o Drift lança no alvo (as suítes existentes mostram o padrão);
> o ponto é não propagar.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sync/`
Expected: PASS.

- [ ] **Step 5: Update the doc owner**

`docs/03-sincronizacao-offline.md` §3/§4/§7 — registrar: vencedor do coalescing por `ts_local`;
remoção pelo id do lote; re-sync em `CHANNEL_ERROR`/`TIMED_OUT`; item remoto com pai ausente é
ignorado até o próximo sync.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test test/features/sync/`

- [ ] **Step 7: Commit**

```bash
git add lib/features/sync/ lib/drift/tables/mutacao_pendente.dart test/features/sync/ docs/03-sincronizacao-offline.md
git commit -m "F43-T03: robustez do flush, coalescing e canal realtime (G-12..G-15, G-19, G-20)"
```

---

### Task 5 (F43-T04) — Sync: histórico no logout e paginação

**Files:**
- Modify: `lib/features/sync/data/supabase_bootstrap.dart:111-117,192-197,267-273`
- Modify: `docs/03-sincronizacao-offline.md` §7
- Test: `test/features/sync/supabase_bootstrap_test.dart`

**Interfaces:**
- Consumes: `SupabaseBootstrap._limparCache()`, `_baixarDoSupabase()`.
- Produces: `_limparCache` apaga `historico_preco_local`; `_baixarDoSupabase` pagina com `range`.

- [ ] **Step 1: Write the failing tests**

Em `test/features/sync/supabase_bootstrap_test.dart` (seguir o fake de servidor do arquivo):

```dart
  test('deve_limpar_historico_de_precos_quando_troca_de_usuario', () async {
    // grava um histórico local, dispara a limpeza de sessão e confere vazio.
  });

  test('deve_paginar_download_quando_mais_de_uma_pagina', () async {
    // fake devolve 2 páginas (range) e confere que ambas foram aplicadas.
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/sync/supabase_bootstrap_test.dart`
Expected: FAIL — histórico permanece; a 2ª página não é baixada.

- [ ] **Step 3: Write minimal implementation**

Em `_limparCache`, incluir:

```dart
    await _db.delete(_db.historicoPrecoLocal).go();
```

Em `_baixarDoSupabase`, trocar o `select()` único por um laço de páginas:

```dart
  static const _tamanhoPagina = 500;

  Future<void> _baixarTabela(...) async {
    var inicio = 0;
    while (true) {
      final pagina = await _client
          .from(tabela)
          .select()
          .range(inicio, inicio + _tamanhoPagina - 1);
      if (pagina.isEmpty) break;
      for (final linha in pagina) {
        await _aplicador.aplicar(tabela, Map<String, Object?>.from(linha));
      }
      if (pagina.length < _tamanhoPagina) break;
      inicio += _tamanhoPagina;
    }
  }
```

> Adapte ao formato real de `_baixarDoSupabase` (usa `select()` + `_upsertLocal`). A decisão de
> **não** reconciliar remoções fica registrada no doc dono.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sync/supabase_bootstrap_test.dart test/features/sync/`

- [ ] **Step 5: Update the doc owner**

`docs/03-sincronizacao-offline.md` §7 — histórico de preços é local e é limpo na troca de usuário;
download pagina em blocos; remoção remota não reconcilia (a app só faz soft delete).

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test test/features/sync/`

- [ ] **Step 7: Commit**

```bash
git add lib/features/sync/data/supabase_bootstrap.dart test/features/sync/supabase_bootstrap_test.dart docs/03-sincronizacao-offline.md
git commit -m "F43-T04: limpa historico de precos no logout e pagina o download (G-16, G-18)"
```

---

### Task 6 (F43-T05) — Repositórios: escrita local + fila atômicas

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (métodos de escrita)
- Modify: `docs/03-sincronizacao-offline.md` §3
- Test: `test/features/listas/listas_repository_test.dart`

**Interfaces:**
- Consumes: `ListasRepository` (criarLista, renomear, excluir, arquivar, adicionarItem, editarItem, remover, desmarcarTodos, limparConcluidos, definirOrcamento…), `OutboxMutacoes`.
- Produces: mesmas APIs; cada método passa a executar dentro de `_db.transaction`.

- [ ] **Step 1: Write the failing test**

Padrão (usar um `OutboxMutacoes`/fake que falhe injetado, ou um hook de falha no repositório):

```dart
  test('deve_reverter_write_local_quando_enfileirar_falha', () async {
    // com um outbox que lança, criarLista não deve deixar lista no Drift.
  });
```

> Se `OutboxMutacoes` não for injetável, adicione um parâmetro opcional
> `OutboxMutacoes? outbox` ao construtor (`late final _outbox = outbox ?? OutboxMutacoes(_db)`),
> sem mudar o uso existente — é a menor mudança testável.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listas/listas_repository_test.dart`
Expected: FAIL — a lista fica gravada mesmo com o enfileiramento falhando.

- [ ] **Step 3: Write minimal implementation**

Envolver o par write+fila de cada método em `_db.transaction`:

```dart
  Future<Lista> criarLista({required String titulo, required String donoId}) async {
    return _db.transaction(() async {
      final id = _uuid.v4();
      final agora = DateTime.now().toUtc();
      await _db.into(_db.listaLocal).insert(ListaLocalCompanion.insert(/* ... */));
      await _outbox.enfileirar(/* ... */);
      return Lista(/* ... */);
    });
  }
```

Aplicar o mesmo padrão aos demais métodos de escrita (o corpo é movido para dentro do `transaction`,
sem alterar lógica).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/listas/`
Expected: PASS.

- [ ] **Step 5: Update the doc owner**

`docs/03-sincronizacao-offline.md` §3 — registrar que write local + enfileiramento são atômicos.

- [ ] **Step 6: Format, analyze e suíte**

Run: `dart format . && flutter analyze && flutter test test/features/listas/`

- [ ] **Step 7: Commit**

```bash
git add lib/features/listas/data/listas_repository.dart test/features/listas/listas_repository_test.dart docs/03-sincronizacao-offline.md
git commit -m "F43-T05: escrita local e fila atomicas no repositorio (G-17)"
```

---

### Task 7 (F43-T06) — RLS: `deletado_em` imutável para editor

**Files:**
- Create: `supabase/migrations/0023_protege_deletado_em_lista.sql`
- Modify: `docs/02-seguranca-rls.md` §3/§4.1, `docs/01-banco-de-dados.md` §6
- Test: `supabase/tests/rls_tests.sql`

**Interfaces:**
- Consumes: `listas_update_editores` (0002/0012), `protege_arquivo_dono` (0018) como padrão.
- Produces: policy recriada + trigger `protege_deletado_em`/`trg_listas_deletado_em_dono`.

- [ ] **Step 1: Write the failing SQL test**

Em `supabase/tests/rls_tests.sql`, adicionar (seguindo o estilo dos casos N-xx, que fazem `set role`/`request.jwt.claims` e esperam exceção):

```sql
-- N-23: editor não pode alterar deletado_em de lista (G-03)
do $$
begin
  perform 1 from public.listas where id = :lista_editor;
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', :editor_id)::text, true);
  update public.listas set deletado_em = now() where id = :lista_editor;
  raise exception 'N-23 FALHOU: editor soft-deletou a lista';
exception
  when insufficient_privilege or check_violation or others then
    -- esperado: policy/trigger barra
    null;
end $$;
```

> Ajustar às variáveis/IDs que o arquivo já prepara no início (dono/editor/listas de teste). O caso
> deve falhar antes da migration (0 linhas barradas) e passar depois.

- [ ] **Step 2: Run to verify it fails**

Run: `supabase db reset; psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_tests.sql`
Expected: FAIL em N-23 (o UPDATE passa).

- [ ] **Step 3: Write the migration**

```sql
-- 0023_protege_deletado_em_lista.sql — editor não soft-deleta/ressuscita a lista
-- (G-03, doc 02 §3/§4.1). Defesa em profundidade: policy + trigger.

drop policy "listas_update_editores" on public.listas;

create policy "listas_update_editores"
  on public.listas for update
  using (public.papel_na_lista(id) in ('dono', 'editor'))
  with check (
    public.papel_na_lista(id) in ('dono', 'editor')
    and dono_id = (select l.dono_id from public.listas l where l.id = listas.id)
    and (
      public.papel_na_lista(id) = 'dono'
      or deletado_em is not distinct from (
        select l.deletado_em from public.listas l where l.id = listas.id
      )
    )
  );

create or replace function public.protege_deletado_em()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deletado_em is distinct from old.deletado_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_EXCLUIR';
  end if;
  return new;
end;
$$;

create trigger trg_listas_deletado_em_dono
  before update on public.listas
  for each row execute function public.protege_deletado_em();
```

- [ ] **Step 4: Run to verify it passes**

Run: `supabase db reset; psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_tests.sql`
Expected: PASS (N-23 barrado; P-xx de UPDATE do dono/editor de outras colunas seguem verdes).

- [ ] **Step 5: Update the docs owners**

`docs/02-seguranca-rls.md` §3/§4.1 — `deletado_em` só muda pelo dono (policy + trigger).
`docs/01-banco-de-dados.md` §6 — registrar `protege_deletado_em`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0023_protege_deletado_em_lista.sql supabase/tests/rls_tests.sql docs/02-seguranca-rls.md docs/01-banco-de-dados.md
git commit -m "F43-T06: editor nao soft-deleta lista (G-03, RF-13)"
```

---

### Task 8 (F43-T07) — Banco: PII, `revoke` e CHECK de convites

**Files:**
- Create: `supabase/migrations/0024_pii_e_rpc_convites.sql`
- Modify: `docs/01-banco-de-dados.md` §4.2/§4.4, `docs/02-seguranca-rls.md` §4.4/§4.7, `docs/06-mvp-entregas.md` §3.3.1
- Test: `supabase/tests/excluir_conta_tests.sql`, `supabase/tests/aceitar_convite_tests.sql`

**Interfaces:**
- Consumes: `excluir_conta()` (0013), `aceitar_convite(uuid)` (0007), tabela `convites`.
- Produces: `excluir_conta` limpa convites por e-mail; grant reduzido; CHECK `convites_tipo_email_check`.

- [ ] **Step 1: Write the failing SQL tests**

Em `excluir_conta_tests.sql`, novo caso E-06: criar convite `tipo='email'` para o e-mail do titular
de uma conta de teste, executar `excluir_conta()` e conferir que o convite sumiu (e que um convite de
terceiro permanece). Em `aceitar_convite_tests.sql`, adicionar: `anon` não executa (sem grant); e
INSERT de `tipo='email'` com `email null` é rejeitado pelo CHECK.

- [ ] **Step 2: Run to verify they fail**

Run: `supabase db reset; psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/excluir_conta_tests.sql; psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/aceitar_convite_tests.sql`
Expected: FAIL — convite do titular permanece; anon ainda executa; `tipo=email` sem e-mail aceito.

- [ ] **Step 3: Write the migration**

```sql
-- 0024_pii_e_rpc_convites.sql — PII de convites na exclusão, grant de
-- aceitar_convite e CHECK tipo↔email (G-04, G-22, G-24).

create or replace function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  email_uid text;
begin
  if uid is null then
    raise exception 'autenticacao necessaria';
  end if;

  select u.email into email_uid from auth.users u where u.id = uid;

  perform set_config('app.excluindo_conta', 'true', true);

  if email_uid is not null then
    delete from public.convites where lower(email) = lower(email_uid);
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;

revoke execute on function public.aceitar_convite(uuid) from public, anon;
grant execute on function public.aceitar_convite(uuid) to authenticated;

alter table public.convites
  add constraint convites_tipo_email_check
  check (
    (tipo = 'link' and email is null)
    or (tipo = 'email' and email is not null)
  ) not valid;
alter table public.convites validate constraint convites_tipo_email_check;
```

> Ajustar `aceitar_convite` para comparar e-mail de forma explícita (link, `email is null`, segue
> aceitando qualquer autenticado). Se houver dados em produção violando o CHECK, o `validate` falha:
> nesse caso, normalizar antes (registrar no PR).

- [ ] **Step 4: Run to verify they pass**

Run: `supabase db reset` + as duas suítes.
Expected: PASS (E-01…E-06; A-01…A-08).

- [ ] **Step 5: Update the docs owners**

`docs/01` §4.2/§4.4, `docs/02` §4.4/§4.7, `docs/06` §3.3.1 — PII removida na exclusão; CHECK
tipo↔email; grant de `aceitar_convite` só a `authenticated`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0024_pii_e_rpc_convites.sql supabase/tests/ docs/01-banco-de-dados.md docs/02-seguranca-rls.md docs/06-mvp-entregas.md
git commit -m "F43-T07: PII de convites na exclusao e CHECK tipo-email (G-04, G-22, G-24)"
```

---

### Task 9 (F43-T08) — Banco: higiene de policies/limites e `search_path`

**Files:**
- Create: `supabase/migrations/0025_higiene_policies_limites.sql`
- Modify: `lib/drift/tables/item_local.dart`, `lib/drift/database.dart` (schemaVersion 9 + migração v8→v9)
- Modify: `docs/01-banco-de-dados.md`, `docs/02-seguranca-rls.md`, `docs/03-sincronizacao-offline.md` §5, `docs/05-app-flutter.md` §2
- Test: `supabase/tests/rls_tests.sql`, `supabase/tests/push_tokens_tests.sql`, `test/drift/database_test.dart`

**Interfaces:**
- Consumes: policies `membros_update_papel_dono` (0009), `convites_insert_dono` (0007), `push_tokens.token` (0021), `itens_lista.quantidade` (0001).
- Produces: policies restritas, CHECKs de tamanho, definers com `search_path = ''`; `ItemLocal` com CHECK de teto.

- [ ] **Step 1: Write the failing tests**

SQL: `membros_update` rejeita UPDATE que altere `user_id`/`lista_id`; `convites_insert` rejeita
`estado='aceito'`/`expira_em` no passado; `push_tokens.token` acima de 4096 rejeitado; `quantidade`
acima do teto rejeitado; negações de anon em `lista_membros`/`convites`/`push_tokens`; `agora_servidor`
executável só por `authenticated`.
Dart: teste de migração v8→v9 e teste negativo do CHECK de `quantidade`.

- [ ] **Step 2: Run to verify they fail**

Run: as suítes SQL + `flutter test test/drift/database_test.dart`
Expected: FAIL nos casos novos.

- [ ] **Step 3: Write the migration + Drift**

```sql
-- 0025_higiene_policies_limites.sql — G-26, G-27, G-29, G-30, G-23.

drop policy "membros_update_papel_dono" on public.lista_membros;
create policy "membros_update_papel_dono"
  on public.lista_membros for update
  using (public.is_dono_de(lista_id) and user_id <> auth.uid())
  with check (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
    and papel in ('editor', 'leitor')
    and user_id = (select m.user_id from public.lista_membros m where m.id = lista_membros.id)
    and lista_id = (select m.lista_id from public.lista_membros m where m.id = lista_membros.id)
  );

drop policy "convites_insert_dono" on public.convites;
create policy "convites_insert_dono"
  on public.convites for insert
  with check (
    criado_por = auth.uid()
    and estado = 'pendente'
    and expira_em > now()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

alter table public.push_tokens
  add constraint push_tokens_token_tamanho
  check (char_length(token) between 1 and 4096);

alter table public.itens_lista
  add constraint itens_lista_quantidade_teto
  check (quantidade <= 1000000) not valid;
alter table public.itens_lista validate constraint itens_lista_quantidade_teto;
```

`search_path=''`: recriar **cada** definer trocando `set search_path = public` por `set search_path = ''`
e qualificando os identificadores internos. Lista das funções (auditar com
`grep -rn "security definer" supabase/migrations`): `papel_na_lista`, `is_member`, `is_dono_de`,
`email_autenticado`, `excluir_conta`, `transferred`/`transferir_dono`, `aceitar_convite`,
`agora_servidor`, `meus_convites_pendentes`, `recusar_convite`, `registrar_push_token`,
`notificar_push`, `sync_dono`, `protege_arquivo_dono`, `protege_deletado_em`.
Ao final, `select proname, proconfig from pg_proc where prosecdef` não deve conter `search_path=public`.

Drift: `ItemLocal.customConstraints` ganha `'CHECK (quantidade <= 1000000)'`; `database.dart` sobe
`schemaVersion` para 9 e adiciona o passo `from < 9` com `alterTable(TableMigration(itemLocal))`.

- [ ] **Step 4: Run to verify they pass**

Run: `supabase db reset` + suítes SQL + `flutter test test/drift/database_test.dart`
Expected: PASS.

- [ ] **Step 5: Document the accepted risks (G-25, G-28)**

`docs/03` §5 — `updated_at` sem teto é risco aceito (o LWW depende do relógio do cliente; a detecção
do relógio adiantado é client-side). `docs/01` §7 — push sem rate-limit é risco aceito (volume é do
dono da lista).

- [ ] **Step 6: Update the docs owners**

`docs/01`/`docs/02` — policies e CHECKs novos; `docs/05` §2 — paridade Drift do teto; `03`/`01` —
riscos aceitos.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0025_higiene_policies_limites.sql supabase/tests/ lib/drift/ test/drift/database_test.dart docs/01-banco-de-dados.md docs/02-seguranca-rls.md docs/03-sincronizacao-offline.md docs/05-app-flutter.md
git commit -m "F43-T08: higiene de policies, limites e search_path dos definers (G-23, G-26, G-27, G-29, G-30)"
```

---

## Auto-revisão do plano A

- **Cobertura do spec:** G-01/G-10→T01; G-02→T02; G-12…G-15/G-19/G-20→T03; G-16/G-18→T04;
  G-17→T05; G-03→T06; G-04/G-22/G-24→T07; G-23/G-26/G-27/G-29/G-30→T08; G-25/G-28→T08 (docs);
  G-21→sem código (limite documentado). Sem lacunas no escopo de dados/segurança.
- **Sem placeholders:** todas as tasks têm teste que falha, implementação e commit; onde o helper do
  arquivo precisa ser conferido, o plano diz qual é e por quê (mesmo estilo do plano da F20).
- **Consistência de tipos:** `BackupRestauracaoException`, `_mesclarEDevolver`, `protege_deletado_em`,
  `0023`–`0025`, `schemaVersion 9` são usados uma única vez e de forma coerente.
