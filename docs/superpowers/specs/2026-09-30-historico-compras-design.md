# Frente — Histórico de Compras e Estatísticas (design)

> **Status:** aprovado em 30/09/2026 (decisões registradas na Seção 10)
> **Fases:** 50 (registrar idas + histórico) e 51 (estatísticas) · **Requisito:** RF-34 (histórico de compras: idas + estatísticas)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX, Drift), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [15](../15-design-system.md) (componentes, se necessário),
> [09](../09-runbook-operacoes.md) (dependência), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

Hoje o app já registra **preço por item** (RF-21), **orçamento** (RF-28) e uma
**comparação pontual** de preço por nome (RF-29), mas **não guarda o histórico das compras**:
cada lista é um estado vivo, sem memória de "idas" passadas. A persona **P1 (Comprador solo)**
não consegue responder "quanto gastei este mês?", "o que compro sempre?" ou "o arroz está
subindo?".

**A feature é 100% offline.** As idas são um snapshot local no Drift; nada trafega e não há
sync (o app é local, F48).

## 2. Escopo

**Dentro:**
- RF-34: ação **"Finalizar compra"** que grava uma **ida** (snapshot dos itens concluídos).
- Aba **Histórico**: lista de idas + detalhe da ida.
- **Estatísticas:** gasto por período (gráfico), gasto por categoria, itens mais comprados,
  evolução de preço por item, ticket médio e total geral.

**Fora:** receitas/menus, cupons, OCR, sync entre aparelhos, exportação específica do histórico
(o backup já cobre o banco), edição de idas passadas.

## 3. Modelo (Drift local — migração v11 → v12)

`lib/drift/tables/`:

- **`idas_compra`**
  | Campo | Tipo | Notas |
  | :-- | :-- | :-- |
  | `id` | text (uuid) | PK |
  | `lista_id` | text, nullable | referência informativa (a lista pode mudar/excluir) |
  | `titulo` | text | **snapshot** do título da lista |
  | `finalizada_em` | datetime | momento da finalização |
  | `total_centavos` | int | soma dos subtotais dos itens **com preço** |
  | `itens_count` | int | nº de itens concluídos gravados |

- **`itens_ida`**
  | Campo | Tipo | Notas |
  | :-- | :-- | :-- |
  | `id` | text (uuid) | PK |
  | `ida_id` | text | FK → `idas_compra.id` (`ON DELETE CASCADE`) |
  | `nome` | text | |
  | `quantidade` | real | `> 0` (CHECK) |
  | `unidade` | text | enum fechado (`unidade.dart`) |
  | `categoria` | text | enum fechado (`categoria.dart`) |
  | `preco_centavos` | int, nullable | `null` = item sem preço |

**Snapshot imutável:** a ida **não** referencia `item_local` — guarda cópias dos campos, para
permanecer fiel mesmo que a lista ou os itens sejam editados/excluídos depois. Não há fila/sync.

## 4. Fluxo "Finalizar compra"

Na tela da lista (`tela_lista_screen.dart`), ação no menu `⋮` **e** botão no rodapé (habilitada
apenas quando há ≥ 1 item concluído):

1. **Confirmação** com resumo ("N itens · Total R$ X · M sem preço").
2. `HistoricoComprasRepository.finalizar(listaId)` grava `idas_compra` + `itens_ida` numa
   **transação**, a partir dos itens da lista com `concluido = true` (snapshot de nome,
   quantidade, unidade, categoria e preço).
3. **Diálogo pós-finalizar:** **"Limpar concluídos"** (reusa `ListasRepository.limparConcluidos`)
   **ou "Manter a lista"**. Nada é removido sem essa escolha.
4. `total_centavos` = soma de `quantidade × preço` dos itens **com preço** (itens sem preço
   somam 0 e são contados em "sem preço", mesma regra do `totalCarrinho`/RF-21).

**Pré-condição:** ≥ 1 item concluído. Por defesa, `finalizar` lança `StateError` se não houver
concluídos (a UI nunca chama sem habilitar).

## 5. Tela Histórico (aba)

Nova aba no `AppShell` (hoje 2 destinos) → rota **`/historico`** (`HistoricoScreen`) e detalhe
**`/historico/ida/:idaId`**.

- **Resumo (topo):** total geral, **ticket médio** (total geral ÷ nº de idas), nº de idas.
- **Aba "Idas":** lista por `finalizada_em` desc — data, título, nº de itens e total; toque abre
  o **detalhe da ida** (`/historico/ida/:id`) com os itens (nome, `quantidade unidade`,
  categoria, preço, subtotal) e o total.
- **Vazio:** `AppEstadoVazio` explicativo ("Nenhuma compra finalizada ainda") com dica de como
  finalizar.
- **Aba "Estatísticas":** ver Seção 6.

## 6. Estatísticas (Fase 51)

Sobre `idas_compra`/`itens_ida`, via consultas de agregação + funções puras de agrupamento:

- **Gasto por período:** gráfico de **barras por mês** (últimos 12 meses) e total do período.
- **Gasto por categoria:** soma dos subtotais por categoria (com % do total).
- **Itens mais comprados:** frequência por **nome normalizado** (top N), com opção por gasto acumulado.
- **Evolução de preço por item:** série `(data, preço unitário)` por item — **só com a mesma
  unidade** (regra do RF-29); lista + mini gráfico; item nunca comprado → vazio.
- **Ticket médio / total geral:** já no resumo; reforçados aqui.

As estatísticas são **do aparelho** (local), calculadas na hora a partir das idas.

## 7. Regras e casos-limite

- Sem itens concluídos → ação de finalizar desabilitada (`StateError` por defesa).
- Itens sem preço entram na ida e não somam no total; contagem "N sem preço" exibida.
- Orçamento (RF-28) **não** vai para a ida.
- Estados vazios explicativos para cada visão sem dados.
- Unidade divergente na evolução de preço → não compara.
- Ordenação determinística: `finalizada_em` desc, desempate por `id`.

## 8. Acessibilidade e dependências

- Componentes/`AppStrings`/tokens do design system; alvos ≥ 48dp; contraste AA; rótulos a11y.
- **Dependência nova:** **`fl_chart`** (puro Dart, offline) para os gráficos. Alternativa sem
  dependência seria `CustomPaint`. Nenhuma permissão nova; sem rede.
- Tudo local; privacidade inalterada (nada sai do aparelho).

## 9. Testes

**Unit — repositório (Drift in-memory):**
- `deve_gravar_ida_e_itens_quando_finaliza` (snapshot dos concluídos).
- `deve_somar_somente_itens_com_preco_quando_calcula_total`.
- `deve_contar_itens_sem_preco_quando_finaliza`.
- `deve_falhar_quando_nao_ha_concluidos` (`StateError`, nada gravado).
- `deve_limpar_concluidos_quando_escolhe_limpar` / `deve_manter_a_lista_quando_escolhe_manter`.
- Agregações: `deve_agrupar_gasto_por_mes`, `deve_agrupar_gasto_por_categoria`,
  `deve_contar_itens_mais_comprados`, `deve_serie_de_evolucao_por_item_somente_mesma_unidade`.

**Unit — funções puras:** agrupamento mês/categoria, ticket médio, série de evolução.

**Widget:** botão/confirmação/diálogo pós-finalizar; aba Histórico (lista e vazio); detalhe da ida;
telas de estatística com e sem dados.

Sem golden.

## 10. Decisões registradas (30/09/2026)

1. Ida criada por **ação "Finalizar compra"** (não automática).
2. A ida guarda **itens concluídos + preços + total** (snapshot imutável).
3. Após finalizar, **perguntar**: limpar concluídos **ou** manter a lista.
4. Estatísticas incluem as **6 visões** (idas+detalhe, gasto por período, por categoria, mais
   comprados, evolução de preço, ticket/total).
5. Aba nova **`/historico`** com detalhe `/historico/ida/:id`; gráficos com **`fl_chart`**.
6. Plano em **duas fases**: F50 (registrar idas + histórico) e F51 (estatísticas).
7. **Fase 50/51**, requisito **RF-34**.

## 11. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — telas, rotas, Drift e repositórios
- [10 Wireframes](../10-wireframes-telas.md) — aba Histórico, detalhe e estatísticas
- [12 PRD](../12-prd.md) — RF-34
- [14 Tarefas](../14-tarefas.md) — Fases 50 e 51
- [16 Roadmap](../16-roadmap-pos-mvp.md) — origem da frente
