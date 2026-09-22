# D1a — Orçamento por lista (RF-28) (design)

> **Status:** aprovado em 22/09/2026 (decisões na Seção 7)
> **Fase:** 36 · **Requisito:** RF-28 (novo) · **Doc dono:** [01](../01-banco-de-dados.md), [02](../02-seguranca-rls.md), [03](../03-sincronizacao-offline.md), [05](../05-app-flutter.md), [10](../10-wireframes-telas.md), [12](../12-prd.md)
> **Onda D (D1):** o preço/total do RF-21 foi entregue na F25; a **comparação entre idas** fica para fase futura.

---

## 1. Motivação

O RF-21 já dá preço por item e o total ao vivo dos marcados ("no carrinho"). Falta o **orçamento**: um limite de gasto por lista que compara com esse total e avisa ao ultrapassar — útil durante a compra. Hoje o doc 12 lista "orçamento/limite" como **fora de escopo**; esta frente o promove a **RF-28**.

## 2. Escopo

**Dentro:**
- Coluna `listas.orcamento_centavos` (sincronizada, por lista) + validação.
- Editar/limpar o orçamento pela UI (dono **e** editor).
- Exibição do progresso do carrinho vs. orçamento (lista e modo mercado), com alerta visual ao ultrapassar.
- RF-28 no doc 12 + docs donos (01/02/03/05/10) e fechamento (14/16).

**Fora:**
- **Comparação entre idas** (histórico de preços) — fase futura.
- Orçamento **não bloqueia** a marcação (offline-first); sem modal/limite rígido.
- Sem policy/trigger RLS nova; sem novo RF além do RF-28.

## 3. Modelo de dados (01/02)

- Migration `0020_orcamento_lista.sql`:
  ```sql
  alter table public.listas
    add column orcamento_centavos integer
      check (orcamento_centavos is null
             or (orcamento_centavos >= 0 and orcamento_centavos <= 99999999));
  ```
- `null` = sem orçamento; `0` é válido; dinheiro em **centavos inteiros** (sem `float`), teto R$ 999.999,99 (mesmo padrão do `preco_centavos`, RF-21).
- **Sem policy nova**: herda o UPDATE de `listas` (`papel_na_lista(id) in ('dono','editor')`, [02 §4.1](../02-seguranca-rls.md)) — dono e editor definem/alteram, como o título. `leitor` não escreve.
- Testes SQL `ORC-01..ORC-03` (negativo rejeitado; acima do teto rejeitado; válido e `null` aceitos) + step no CI.

## 4. Sincronização (03)

- O payload de `listas` passa a incluir `orcamento_centavos`; o aplicador LWW tolera **ausente/não numérico → `null`** (mesmo contrato do preço do item).
- Escrita continua offline-first: UI grava no Drift + enfileira; o valor propaga aos membros pelo LWW/Realtime.

## 5. App (05) e wireframes (10)

- **Drift:** coluna `orcamentoCentavos` em `ListaLocal`; `schemaVersion` 5 → **6** (migração aditiva).
- **Domínio/repo:** `Lista.orcamentoCentavos` (`int?`); `editarLista(id, {orcamentoCentavos, limparOrcamento})` (payload com `orcamento_centavos`).
- **Definir/limpar:** item **"Orçamento"** no menu (⋮) da tela da lista → diálogo com campo "Orçamento (R$)" (reusa `parsePrecoParaCentavos`/`formatarReais`, erro inline para valor inválido) + ação "Remover orçamento". Visível para dono/editor; oculto para leitor.
- **Exibição:** `TotalCarrinho` estendido — com orçamento: "No carrinho: R$ X de R$ Y" + barra de progresso; ao ultrapassar: estilo de alerta (cor/ícone) + "acima do orçamento". Sem orçamento: comportamento atual (RF-21). Presente no **rodapé da lista** (§6.3) e no **modo mercado** (§6.5). Sem bloqueio.
- Wireframes: [10 §3.1](../10-wireframes-telas.md) (rodapé da lista) e [10 §3.5](../10-wireframes-telas.md) (mercado).

## 6. Documentos donos no mesmo PR
- `01 §4.1` (coluna), `02 §4.1` (nota "sem policy nova"), `03` (payload de `listas`), `05 §6.3/§6.5` (menu/faixa), `10 §3.1/§3.5`, `12` (RF-28 + rastreabilidade; remover "orçamento/limite" do fora-de-escopo), `14` (Fase 36), `16` (D1 parcial).

## 7. Decisões registradas (22/09/2026)

1. Orçamento compara com o **total do carrinho** (itens marcados com preço) — o `TotalCarrinho` do RF-21.
2. **Dono e editor** definem/alteram (herda a policy UPDATE de `listas`; sem policy nova).
3. Orçamento é **informativo** (não bloqueia) — offline-first.
4. Novo requisito **RF-28**; Fase **36**; sem ADR novo.

## 8. Documentos relacionados
- [01 Banco de Dados](../01-banco-de-dados.md) §4.1 · [02 Segurança RLS](../02-seguranca-rls.md) §4.1 · [03 Sincronização](../03-sincronizacao-offline.md)
- [05 App Flutter](../05-app-flutter.md) §6.3/§6.5 · [10 Wireframes](../10-wireframes-telas.md) §3.1/§3.5
- [12 PRD](../12-prd.md) (RF-28) · [14 Tarefas](../14-tarefas.md) (Fase 36) · [16 Roadmap](../16-roadmap-pos-mvp.md) (Onda D, D1)
