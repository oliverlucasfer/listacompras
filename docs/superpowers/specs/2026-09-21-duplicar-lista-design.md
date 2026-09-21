# Frente — Duplicar Lista ("Comprar de novo") (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 7)
> **Fase:** 23 · **Requisito:** RF-20 (duplicar lista)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

Comprar é recorrente: a lista da semana passada costuma repetir boa parte da próxima. Hoje o
app só oferece criar do zero ou, um a um, tocar nos chips de **itens frequentes** (RF-19). Não
há como reaproveitar uma lista inteira de uma vez.

As personas **P1 (Comprador solo)** e **P2 (Casal/família)** são quem mais sente isso: quem já
tem o hábito de "fazer a compra de novo" precisa redigitar tudo.

**A feature é 100% offline e não toca schema, RLS ou sync.** É um método de domínio sobre o
Drift existente que reusa as escritas normais (`criarLista` + `adicionarItem`) e a fila de
mutações do [03](../03-sincronizacao-offline.md).

## 2. Escopo

**Dentro:**
- RF-20: duplicar uma lista a partir dos seus **itens pendentes**, pelo menu do painel de listas.
- Sheet de confirmação com contagem e **título editável** (pré-preenchido com o título da origem).
- Após criar, abrir a lista nova.

**Fora (frentes seguintes):** arquivar/desarquivar listas, escolher itens na hora, puxar itens
de outra lista, duplicação no servidor (RPC), histórico de compras como tela.

## 3. Domínio

Novo método em `ListasRepository` (`lib/features/listas/data/listas_repository.dart`):

```dart
Future<Lista> duplicarLista({
  required String origemId,
  required String titulo,
  required String donoId,
});
```

Comportamento:

1. Lê os itens da lista de origem com `deletado_em IS NULL` **e** `concluido = false`,
   ordenados por `ordem` ASC e `id` ASC (mesmo critério de `watchItensDaLista`).
2. Cria a lista nova (novo **UUID v4** no cliente, `created_at`/`updated_at` = agora) via
   `criarLista(titulo:, donoId:)` — mesmo caminho de `abrirSheetNovaLista`.
3. Para cada item pendente, na ordem original, chama
   `adicionarItem(listaId: novoId, nome:, quantidade:, unidade:, categoria:)` — que copia os
   campos e atribui `ordem` sequencial (0..n-1) via `_proximaOrdem`; `concluido` entra sempre
   `false`.
4. **Não altera a lista de origem** (apenas leitura).
5. Enfileira as mutações (`INSERT` da lista + `INSERT` de cada item) — o Sync Engine sobe ao
   reconectar; a cópia funciona sem rede.
6. Retorna a `Lista` criada (para a UI navegar).

**Pré-condição:** existir ao menos um item pendente. A UI nunca chama com zero (o item de menu
só aparece quando há pendentes); por defesa, o método lança `StateError` se não houver
pendentes, em vez de criar uma lista vazia silenciosamente.

**Decisão de reuso:** implementar em Dart lendo o Drift e reusando `criarLista`/`adicionarItem`
(Abordagem A) — sem transação em lote nem RPC. O custo de N mutações é o mesmo do fluxo normal
de digitação e irrelevante no tamanho típico de uma lista.

## 4. UI (painel de listas)

Arquivo: `lib/features/listas/ui/painel_listas.dart` (menu `PopupMenuButton` por card).

- Novo item de menu **"Comprar de novo"** (`AppStrings.comprarDeNovo`) em **ambos** os menus:
  `_itensDono` (dono) e `_itensMembro` (membro). Quem enxerga a lista pode duplicá-la para si
  — a cópia nasce com o usuário atual como dono. Para `leitor`, é uma forma legítima de usar a
  lista de referência sem escrever na original.
- **Visibilidade:** o item só aparece quando há pendentes. O card já recebe
  `ListaComContagem` (`totalItens` e `concluidos`), então pendentes = `totalItens - concluidos`
  — sem consulta extra.
- **Ação:** abre o sheet de título com uma **descrição de contexto**:
  - `AppStrings.duplicarDescricao(n)` → ex.: `"3 itens pendentes serão copiados."` /
    `"1 item pendente será copiado."`
  - título do sheet: `AppStrings.comprarDeNovo`; rótulo do botão: `AppStrings.criarLista`;
    `valorInicial`: o título da lista de origem (editável); mensagem de sucesso:
    `AppStrings.listaCriada`.
- **Confirmação:** `onSalvar` chama `duplicarLista(...)` e, em seguida,
  `papelRepositoryProvider.atualizar(novoId, Papel.dono)` (papel local imediato, igual a
  `abrirSheetNovaLista`). O id criado é capturado por closure; **após o sheet fechar**
  (`await abrirSheetTitulo(...)`), a UI faz `context.push('/lista/$novoId')` se houve criação.
  Cancelar não cria nada.
- **Falha de escrita local** (caso raro): o próprio `SheetTituloLista` já exibe `AppStrings.
  erroGenerico` e mantém o sheet aberto.

## 5. Reuso e mudança mínima

- Estender `SheetTituloLista` / `abrirSheetTitulo` (`lib/features/listas/ui/sheet_titulo_lista.dart`)
  com um parâmetro **opcional** `String? descricao`, renderizado como texto de apoio
  (`bodyMedium`) acima do campo. Chamadas existentes (`nova lista`, `renomear`) ficam intactas.
- Nenhum componente `App*` novo é necessário (reusa `AppCampoTexto`, `AppBotao`, `AppSheet`).

## 6. Testes

**Unit — `test/features/listas/duplicar_lista_test.dart`** (Drift in-memory, padrão do repo):
- `deve_copiar_somente_pendentes_quando_duplica` — concluídos da origem ficam de fora.
- `deve_preservar_nome_quantidade_unidade_categoria_quando_duplica`.
- `deve_preservar_a_ordem_dos_itens_quando_duplica`.
- `deve_enfileirar_mutacao_de_lista_e_de_cada_item_quando_duplica` (1 `listas` + N `itens_lista`).
- `deve_deixar_a_lista_original_intacta_quando_duplica`.
- `deve_atribuir_o_novo_dono_quando_duplica`.
- `deve_falhar_quando_nao_ha_pendentes` (`StateError`, nada é criado).

**Widget — painel (`test/features/listas/`, seguindo os testes atuais do painel):**
- `nao_deve_mostrar_comprar_de_novo_quando_sem_pendentes`.
- `deve_mostrar_comprar_de_novo_quando_ha_pendentes`.
- `deve_preencher_descricao_e_titulo_quando_abre_o_sheet`.
- `deve_criar_e_navegar_para_a_lista_nova_quando_confirma`.
- `nao_deve_criar_quando_cancela`.

## 7. Decisões registradas (21/09/2026)

1. Duplicação **no cliente** (Abordagem A, Drift + fila); **sem schema/RLS/sync** e **sem ADR novo**.
2. Copia **apenas pendentes**, sempre entrando como pendentes.
3. Gatilho no **menu do painel** (dono **e** membro), visível só quando há pendentes.
4. Sheet com **contagem + título editável** pré-preenchido com o título da origem.
5. Após criar, **abre a lista nova** (`push`).
6. Reuso do `SheetTituloLista` com parâmetro opcional `descricao`.
7. Fase **23**, requisito **RF-20**.

## 8. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — telas, rotas e providers
- [10 Wireframes](../10-wireframes-telas.md) — menu do painel e sheet
- [12 PRD](../12-prd.md) — RF-20
- [14 Tarefas](../14-tarefas.md) — Fase 23
