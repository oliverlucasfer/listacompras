# Refactor: domínio desacoplado do Drift + quebra do god-class ListasRepository

> **For agentic workers:** execute task-by-task. Steps use checkbox (`- [ ]`).
> Refactor **behavior-preserving**: a suíte existente é o teste (Deve ficar verde em cada fase).

**Goal:** (1) tornar as entidades de domínio puras (sem `import drift/database.dart`), movendo os mapeamentos `fromLocal` para a camada de dados; (2) separar `ListasRepository` (listas + itens, 642 linhas) em `ListasRepository` (listas) e `ItensRepository` (itens), **sem churn de call sites/testes**.

**Architecture:** mapeamento por extensões em `data/mappers.dart` de cada feature. Repositórios: uma biblioteca única via `part`, com `_RepositorioBase` (campos `_db`/`_uuid`), `ItensRepository` e `ListasRepository extends ItensRepository` — a API pública permanece idêntica, então nenhum call site de UI/teste muda.

**Tech Stack:** Dart/Flutter, Drift, Riverpod.

**Spec:** revisão de arquitetura desta sessão (achados §3): domínio importando Drift; god-class `ListasRepository`.

## Global Constraints

- Offline-first: Drift é a fonte da verdade; nenhuma mudança de comportamento.
- `dart format . && flutter analyze` limpos; `flutter test` 100% verde.
- Sem novas dependências.
- Comentários de código apenas quando indispensáveis (pt-BR).

---

## Fase 1 — Desacoplar domínio do Drift

**Files:**
- Modify: `lib/features/listas/domain/item.dart` (remove import Drift + `Item.fromLocal`)
- Modify: `lib/features/listas/domain/lista.dart` (remove import Drift + `Lista.fromLocal`)
- Modify: `lib/features/listas/domain/historico_preco.dart` (remove import Drift + `HistoricoPreco.fromLocal`)
- Modify: `lib/features/historico/domain/ida.dart` (remove import Drift + `Ida.fromLocal` + `ItemDaIda.fromLocal`)
- Create: `lib/features/listas/data/mappers.dart` (extensões `toDomain()` para `ItemLocalData`, `ListaLocalData`, `HistoricoPrecoLocalData`)
- Create: `lib/features/historico/data/mappers.dart` (extensões `toDomain()` para `IdaCompraData`, `ItemIdaData`)
- Modify: `lib/features/listas/data/listas_repository.dart` (usar `.toDomain()`)
- Modify: `lib/features/listas/data/historico_precos_repository.dart` (usar `.toDomain()`)
- Modify: `lib/features/historico/data/historico_compras_repository.dart` (usar `.toDomain()`)
- Modify: `test/features/listas/listas_repository_test.dart:638,669` (`Item.fromLocal(fonte)` → `fonte.toDomain()` + import do mapper)

**Interfaces:**
- Produces: extensões `ItemLocalData.toDomain() -> Item`, `ListaLocalData.toDomain() -> Lista`, `HistoricoPrecoLocalData.toDomain() -> HistoricoPreco`, `IdaCompraData.toDomain() -> Ida`, `ItemIdaData.toDomain() -> ItemDaIda`.

- [ ] **Step 1:** criar os dois `mappers.dart` movendo os corpos de `fromLocal` **verbatim** para `extension ... on <Data> { ... toDomain() ... }`.
- [ ] **Step 2:** remover as factories `fromLocal` e o `import '../../../drift/database.dart';` das 4 entidades de domínio.
- [ ] **Step 3:** atualizar os 3 repositórios para importar o mapper da feature e chamar `.toDomain()`.
- [ ] **Step 4:** atualizar as 2 linhas de teste.
- [ ] **Step 5:** `dart format . && flutter analyze` (limpo) e `flutter test` (verde).

## Fase 2 — Separar `ListasRepository`

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (classe `ListasRepository` independente — sem herança/`part`; compõe `ItensRepository` e delega os métodos de itens para preservar a API histórica)
- Create: `lib/features/listas/data/itens_repository.dart` (classe `ItensRepository` independente, com os métodos de itens)
- Modify: `lib/features/listas/providers/listas_providers.dart` (novo `itensRepositoryProvider`; `itensDaListaProvider` e `itensFrequentesProvider` passam a usá-lo)
- Modify: call sites de itens em `lib/` (sheet_etiqueta, modal_finalizar_compra, modal_previsao_importacao, campo_adicionar_item, linha_item, lista_itens, mercado_screen, sheet_editar_item, tela_lista_screen) para `itensRepositoryProvider`
- Modify: fakes de teste que injetam repositório de itens (`mercado_screen_test`, `tela_lista_screen_test`) para `extends ItensRepository` + override de `itensRepositoryProvider`

**Interfaces:**
- Produces: `ItensRepository` independente (métodos: `watchItensDaLista`, `watchItensFrequentes`, `adicionarItem`, `adicionarItemDedup`, `adicionarItensDedup`, `editarItem`, `removerItem`, `restaurarItem`, `reordenarItens`, `desmarcarTodos`, `limparConcluidos`, internos `_proximaOrdem`/`_lerItem`) + `itensRepositoryProvider`.
- Produces: `ListasRepository` independente (métodos: `watchListas`, `watchLista`, `watchListasComContagem`, `criarLista`, `renomearLista`, `excluirLista`, `definirArquivada`, `definirOrcamento`, `duplicarLista`) que **delega** os métodos de itens a um `ItensRepository` interno — a API acumulada segue idêntica, então os ~400 call sites de teste não mudam.

- [ ] **Step 1:** tornar `ItensRepository` independente e `ListasRepository` uma composição (has-a) com métodos delegados; remover `part`/`extends`.
- [ ] **Step 2:** adicionar `itensRepositoryProvider` e migrar os call sites de itens em `lib`.
- [ ] **Step 3:** apontar os fakes de teste de itens para `ItensRepository`/`itensRepositoryProvider`.
- [ ] **Step 4:** `dart format . && flutter analyze` (limpo) e `flutter test` (verde).

> Execução escolhida pelo usuário: **composição + `itensRepositoryProvider`** (zero quebra nos call sites de teste). A alternativa de separação sem delegação exigiria reescrever ~35 arquivos de teste.

## Fase 3 — Remover a delegação de itens de `ListasRepository` (executada)

Depois de estabilizar a Fase 2, a delegação foi removida:

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (remove os métodos delegados; expõe `final ItensRepository itens;` público)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (`desmarcarTodos` via `itensRepositoryProvider`; era o único item ainda sobre `listasRepositoryProvider`)
- Modify: 32 arquivos de teste (receptores de itens `repo`/`listas`/`listasRepo`/`repoOrigem` → `<recv>.itens.<método>`; 304 chamadas)

- [x] **Step 1:** remover a delegação e expor `itens` (composição) — `ListasRepository` ficou só com listas.
- [x] **Step 2:** migrar os receptores de itens nos testes para `recv.itens.<método>`.
- [x] **Step 3:** `dart format . && flutter analyze` (limpo) e `flutter test` (696/696 verde).

## Self-review

- Cobertura: os 4 arquivos de domínio acoplados (achado §3) e o god-class (achado §3) tratados.
- Sem placeholders.
- Consistência de tipos: `toDomain()` e os construtores públicos das entidades inalterados.
