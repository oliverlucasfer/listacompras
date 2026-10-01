# Frente — Preço por Mercado e Alertas de Orçamento (design)

> **Status:** aprovado em 30/09/2026 (decisões registradas na Seção 11)
> **Fases:** 52 (preço por mercado) e 53 (alertas de orçamento)
> **Requisitos:** RF-35 (preço por mercado) e RF-36 (alertas de orçamento)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX, Drift), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [15](../15-design-system.md) (componentes, se necessário),
> [09](../09-runbook-operacoes.md) (dependência/permissão), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

Hoje o preço é **único por item** (RF-21) e o histórico é **por nome** (RF-29), sem noção de
**onde** a compra foi feita: o usuário não sabe se o feijão estava mais barato no mercado A ou B,
nem quanto gasta por mercado. E o orçamento (RF-28) só avisa **depois** de estourar.

**A feature é 100% offline.** O mercado é um campo local na ida; os preços por mercado são
**derivados** das idas já registradas (RF-34). As notificações são **locais** (sem push/rede).

## 2. Escopo

**Dentro:**
- **RF-35 (Fase 52):** registrar o **mercado** (loja) por ida, de forma opcional; **preço derivado por
  mercado** (último + mais barato, mesma unidade) no editor do item; rótulo no detalhe da ida;
  visão "Gasto por mercado" nas estatísticas; chip do mercado da última ida na tela da lista.
- **RF-36 (Fase 53):** **alertas de orçamento** — estado progressivo no total do carrinho
  (normal → aviso a partir de **80%** → acima em **100%**), **SnackBar ao cruzar** o limite,
  **orçamento por categoria** e **notificação local** ao ultrapassar (Android/iOS).

**Fora:** cadastro de mercados com tabela de preços própria; preço por mercado no card de cada
item (só no editor/detalhe/estatísticas); sincronização/compartilhamento (o app é local);
iOS na distribuição (a notificação iOS fica implementada mas fora de distribuição).

## 3. Modelo (Drift)

**Fase 52 — migração v12 → v13 (aditiva):**
- `idas_compra` ganha **`mercado`** (text, **nullable**). `null` = ida sem mercado informado.
  Não há tabela de preços nova: **os preços por mercado são derivados** de
  `itens_ida × idas_compra.mercado` (último e mínimo por `(nome, unidade, mercado)`).
  `historico_precos` (RF-29) permanece **inalterado**.

**Fase 53 — migração v13 → v14 (aditiva):**
- Nova tabela **`orcamento_categoria`**: `categoria` (text, PK — enum fechado), `limite_centavos`
  (int, `>= 0`, teto `99999999`).

## 4. Fatos e atributos

- **Mercado** é texto livre normalizado para comparação (reusa `normalizarTexto`); preserva a
  caixa da primeira ocorrência para exibição.
- **Preço por mercado** só considera itens **com preço** e a **mesma unidade** (regra do RF-29).
- **Gasto por mercado** = soma de `idas_compra.total_centavos` agrupada por `mercado`
  (idas sem mercado viram um grupo "Sem mercado").

## 5. Fluxo — Mercado (Fase 52)

- **Finalizar compra:** novo campo **opcional "Mercado"** no diálogo, com autocompletar dos
  mercados já usados (`mercadosUsados`). `finalizar(listaId, {String? mercado})` grava na ida.
- **Editor do item:** abaixo de "Última compra: R$ … (dd/mm)" (RF-29), uma linha **"Por mercado"**
  com os últimos preços por mercado para aquele **item + unidade**, e destaque do **mais barato**.
- **Detalhe da ida:** rótulo do mercado quando presente.
- **Estatísticas:** nova seção **"Gasto por mercado"** (soma por mercado, com o grupo "Sem mercado").
- **Chip do mercado:** na tela da lista, chip informativo com o mercado da **última ida** da lista
  (oculto quando não houver); sem ação (ou abre o detalhe da última ida).

## 6. Fluxo — Alertas de orçamento (Fase 53)

- **Progressivo (`TotalCarrinho`):** normal (< 80%) → **aviso** (≥ 80% e < 100%) → **acima** (≥ 100%),
  refletido em cor/ícone e na barra de progresso. Sem orçamento → comportamento atual.
- **SnackBar ao cruzar:** ao marcar um item que faz o total passar de ≤ 100% para > 100%, mostra
  um aviso (uma vez por cruzamento).
- **Orçamento por categoria:** diálogo para definir/limpar limites por categoria; alerta quando o
  subtotal **marcado** da categoria ultrapassa o limite.
- **Notificação local:** ao cruzar o orçamento, emite uma notificação **local** (uma vez por lista
  enquanto o estado "acima" persistir). Android/iOS; Web/Desktop sem notificação do SO.

## 7. Regras e casos-limite

- Mercado vazio → ida sem mercado; não quebra o fluxo.
- Preço por mercado: item sem preço em algum mercado é ignorado naquele mercado; item sem nenhum
  preço → linha "Por mercado" oculta.
- Estado do orçamento: sem itens marcados ou sem orçamento → sem alerta; orçamento `0` → qualquer
  total marcado já é "acima".
- Cruzamento: só dispara ao **passar** o limite (não re-dispara ao permanecer acima).
- Notificação: requer permissão; negada → sem notificação, mantendo os alertas in-app.
- Tudo local; nenhum dado sai do aparelho.

## 8. Dependências e permissões

- **Fase 53:** `flutter_local_notifications` (local, offline) + permissão Android
  **`POST_NOTIFICATIONS`** (Android 13+) e pedido de permissão iOS. Gate `plataformaComNotificacao()`
  (Android/iOS; Web/Desktop sem SO). Notificação testada com **fake injetável** (sem tocar o plugin).
- Sem rede, sem push; sem ADR de backend.

## 9. Testes

**Unit — repositório (Drift in-memory):**
- `deve_gravar_mercado_quando_finaliza_com_mercado` / `deve_deixar_mercado_nulo_quando_nao_informado`.
- `deve_listar_mercados_usados_quando_ha_idas`.
- `deve_derivar_preco_por_mercado_quando_ha_compras` (último + mais barato, mesma unidade).
- `deve_agrupar_gasto_por_mercado_quando_ha_idas` (inclui grupo "Sem mercado").
- `deve_gravar_orcamento_por_categoria_quando_define` / limpar.

**Unit — funções puras:** estado do orçamento (`normal`/`aviso`/`acima`, limiar 80%) e detecção de
cruzamento (`cruzouLimite(antes, depois, orcamento)`).

**Widget:** campo Mercado no finalizar; linha "Por mercado" no editor; chip na lista; seção "Gasto
por mercado"; `TotalCarrinho` progressivo; SnackBar ao cruzar; orçamento por categoria; notificação
local com fake.

Sem golden; plugin real só smoke em device.

## 10. Governança

- `12`: **RF-35** e **RF-36** (tabela + matriz + fora de escopo).
- `05`: telas/rotas/Drift (mercado na ida; orçamento por categoria; alerts) e árvore.
- `10`: wireframes (campo Mercado; "Por mercado" no editor; chip; "Gasto por mercado"; estados do total).
- `09`: dependência `flutter_local_notifications` + permissão `POST_NOTIFICATIONS`.
- `15`: se entrar componente de estado de orçamento.
- `14`: Fases 52 e 53; `16`: frente.

## 11. Decisões registradas (30/09/2026)

1. **Mercado por ida** (opcional no "Finalizar compra"), preços **derivados** das idas — sem tabela
   de preços nova.
2. Mercado aparece em: **editor do item**, **detalhe da ida**, **estatísticas** e **chip na lista**.
3. **Alertas:** progressivo (80%/100%), SnackBar ao cruzar, **orçamento por categoria** e
   **notificação local** (SO).
4. Limiar de aviso **80%** (fixo nesta versão).
5. Notificação é **local** (Android/iOS), com fake nos testes; sem push/rede.
6. Duas fases: **F52 (mercado)** e **F53 (alertas)**; requisitos **RF-35**/ **RF-36**.

## 12. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md)
- [14 Tarefas](../14-tarefas.md) · [16 Roadmap](../16-roadmap-pos-mvp.md)
