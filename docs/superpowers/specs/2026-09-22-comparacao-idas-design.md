# D1b — Comparação de preços entre idas (RF-29) (design)

> **Status:** aprovado em 22/09/2026 (decisões na Seção 7)
> **Fase:** 37 · **Requisito:** RF-29 (novo) · **Doc dono:** [05](../05-app-flutter.md), [03](../03-sincronizacao-offline.md), [10](../10-wireframes-telas.md), [12](../12-prd.md)
> **Onda D (D1):** preço/total (RF-21, F25) e orçamento (RF-28, F36) já entregues; esta é a última parte do D1.

---

## 1. Motivação

Falta ao usuário saber se o preço de hoje está melhor que o da última compra. O histórico local de preços por item (por dispositivo) permite mostrar "Última compra: R$X" e a variação (↑/↓) **no momento de digitar o preço**, sem custo de servidor e sem sincronização.

## 2. Escopo

**Dentro:**
- Tabela **local (Drift-only)** `HistoricoPrecoLocal` — **não** sincronizada, sem Postgres/RLS/payload.
- Registro do preço ao **marcar o item como comprado** (com preço).
- Exibição no **editor do item**: "Última compra: R$X (dd/mm)" + variação vs o preço atual.
- RF-29 no doc 12 + docs donos (05/03/10) e fechamento (14/16).

**Fora:**
- Sincronizar/compartilhar o histórico entre membros/devices (é **por dispositivo**).
- Histórico por lista, gráficos, média, comparação entre lojas.
- Nova migration/RLS/sync; sem novo RF além do RF-29.

## 3. Modelo local (Drift)

- Nova tabela `HistoricoPrecoLocal`:
  | Coluna | Tipo | Descrição |
  | :--- | :--- | :--- |
  | `nomeNormalizado` | `text` (PK) | `normalizarTexto(nome)` (`lib/core/texto/normalizar.dart`) |
  | `precoCentavos` | `integer` | Último preço pago em centavos |
  | `unidade` | `text` | Valor do enum `Unidade` no momento do registro |
  | `registradoEm` | `dateTime` | Quando foi registrado |
- `schemaVersion` 6 → **7**; `onCreate` cria a tabela; `onUpgrade` `if (de < 7) await m.createTable(historicoPrecoLocal);`.
- **Sem migration Postgres, sem RLS, sem payload de sync** — a tabela é local e não entra no `mutacao_pendente`/aplicador.

## 4. Registro (app)

- Centralizado em `ListasRepository.editarItem`: quando o item resultante fica **`concluido == true` e tem preço**, faz upsert em `HistoricoPrecoLocal` (`nomeNormalizado`, `precoCentavos`, `unidade`, `registradoEm = agora`). Cobre o checkbox da lista, o modo mercado e o editor (que conclui via `editarItem`).
- Marcar sem preço **não** registra (nada a comparar). Desmarcar **não** apaga o histórico.
- Escrita local pura (sem fila/sync): não gera mutação remota.

## 5. Exibição (app/wireframe)

- No diálogo de editar item (`_DialogoEditarItem`): ler `historicoPrecoProvider(nomeNormalizado)` (nome do item no momento de abrir o editor) e, quando existir entrada:
  - Linha "**Última compra: R$X (dd/mm)**" (com a unidade do registro).
  - **Variação** ↑/↓ `R$<diferença>` vs o preço atual **apenas quando as unidades casam**; se a unidade diferir, mostra só o último preço (sem variação). Preço atual ausente → só a linha do último preço.
  - Igual → "mesmo preço" (sem ↑/↓).
- Sem entrada → nada é exibido (comportamento atual do editor).
- Wireframe: [10 §3.1](../10-wireframes-telas.md) (editor de item).

## 6. Documentos donos no mesmo PR
- `05 §6.3` (linha no editor + nota "histórico **local**, não sincroniza"), `03` (nota de que a tabela é local-only, fora do sync), `10 §3.1`, `12` (RF-29 + rastreabilidade), `14` (Fase 37), `16` (D1 concluído).

## 7. Decisões registradas (22/09/2026)

1. Modelo **local por dispositivo** (Drift-only) — sem schema/RLS/sync novos.
2. Registro **ao marcar como comprado** com preço.
3. Exibição **no editor do item** (último preço + variação; variação só com unidade igual).
4. Novo requisito **RF-29**; Fase **37**; sem ADR novo.

## 8. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) §6.3 · [10 Wireframes](../10-wireframes-telas.md) §3.1
- [03 Sincronização](../03-sincronizacao-offline.md) (o que sincroniza) · [12 PRD](../12-prd.md) (RF-29)
- [14 Tarefas](../14-tarefas.md) (Fase 37) · [16 Roadmap](../16-roadmap-pos-mvp.md) (Onda D, D1)
