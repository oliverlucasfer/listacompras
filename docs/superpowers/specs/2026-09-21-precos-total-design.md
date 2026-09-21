# Frente — Preço por Item e Total no Carrinho (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 25 · **Requisito:** RF-21 (preço por item + total no carrinho)
> **Docs donos:** [01](../01-banco-de-dados.md) (schema), [03](../03-sincronizacao-offline.md) (payload/sync),
> [05](../05-app-flutter.md) (UI), [10](../10-wireframes-telas.md) (layout), [12](../12-prd.md) (requisitos), [14](../14-tarefas.md)

---

## 1. Motivação

A lista diz **o que** comprar, mas não **quanto custa**. Quem faz a compra não sabe o total acumulado enquanto enche o carrinho, e o casal não enxerga o mesmo valor. Preço por item e um total ao vivo dos itens **já marcados** resolvem isso com uma coluna a mais no item — sem subsistema novo, 100% offline-first.

Preço/orçamento está hoje no "fora de escopo" do MVP ([12 §7](../12-prd.md)); esta frente entrega a fatia de maior valor (preço + total) e deixa **orçamento/limite** e **comparação entre idas** para cortes seguintes.

## 2. Escopo

**Dentro:**
- Preço **unitário opcional** por item (em centavos inteiros).
- **Total ao vivo** dos itens **marcados** (o "no carrinho"), exibido no rodapé da tela da lista **e** no modo mercado.
- Entrada do preço no **editor do item** (mesmo diálogo de nome/quantidade/unidade/categoria).

**Fora (cortes seguintes):** orçamento/limite com alerta, comparação entre idas (histórico/total pago), preço por embalagem/peso, múltiplas moedas (BRL fixo).

## 3. Banco — migration `0017_preco_item.sql`

```sql
alter table public.itens_lista
  add column preco_centavos integer
  check (preco_centavos is null or (preco_centavos >= 0 and preco_centavos <= 99999999));
```

- **Sem policy nova:** a coluna herda as policies de `itens_lista` (quem edita item edita preço — `dono`/`editor`).
- `null` = **sem preço** (item fora do total); `0` é preço válido (R$ 0,00). Negativo rejeitado pelo CHECK.
- Teto `99999999` (R$ 999.999,99) para caber em `int` sem surpresa.
- O `unique index uq_item_ativo (lista_id, lower(nome))` não é afetado.

## 4. Drift e domínio

- `lib/drift/tables/item_local.dart`: `IntColumn get precoCentavos => integer().nullable()();`
- Regenerar `lib/drift/database.g.dart` com `dart run build_runner build --delete-conflicting-outputs`.
- `lib/features/listas/domain/item.dart`: `final int? precoCentavos;` + mapeamento em `Item.fromLocal`.
- `lib/features/listas/data/listas_repository.dart`:
  - `_payloadItem` passa a incluir `'preco_centavos': i.precoCentavos`;
  - `adicionarItem` ganha `int? precoCentavos` (default `null`);
  - `editarItem` ganha `int? precoCentavos` (com sentinela para "limpar": usar um parâmetro `bool limparPreco` ou `Value` — ver §5);
  - `duplicarLista` copia o preço junto dos demais campos (RF-20 + RF-21).
- `lib/features/sync/data/aplicador_remoto.dart` (`_aplicarItem`): mapear `preco_centavos` com **tolerância** — ausente/não-numérico → `null` (linha gravada por app antigo chega sem a coluna), no mesmo padrão de `categoria`.
- `lib/features/sync/data/sync_engine.dart`: nada muda (o payload vem do repositório).

## 5. UI

### 5.1. Editor do item
O diálogo de edição (`tela_lista_screen.dart`, aberto pelo toque/swipe) ganha um campo **"Preço (R$)"** opcional:
- máscara/parse pt-BR via `parsePrecoParaCentavos` (aceita `5,49`, `5.49`, `5`; vazio → `null`);
- validação inline (negativo/ inválido → erro no campo, no padrão de `AppCampoTexto`);
- `editarItem` precisa distinguir "não mexer no preço" de "limpar o preço": o método ganha `int? precoCentavos` **e** um flag `bool limparPreco = false` (quando `true`, grava `null`). Alternativa idiomática: receber `Value<int?>`; o plano decide e mantém o padrão do arquivo.

### 5.2. Faixa do total
Componente novo `TotalCarrinho` (em `lib/features/listas/ui/`), com `Semantics`:
- Texto: `No carrinho: R$ 42,30`; se houver marcados sem preço, acrescenta `· N sem preço`.
- Sem nenhum item marcado com preço: a faixa mostra `No carrinho: R$ 0,00` (ou fica oculta quando não há nenhum item marcado — o plano decide; recomenda-se **ocultar** quando não há marcados).
- Onde: **rodapé** da `tela_lista_screen` (fixo, acima da área segura) e no **modo mercado** (`mercado_screen.dart`, no topo junto do contador).
- Deriva de um provider/`Stream` do Drift: itens ativos da lista, `concluido = true` e `precoCentavos != null`.

## 6. Formatação e cálculo (funções puras)

Em `lib/core/texto/` (ou `lib/features/listas/domain/`), testáveis sem UI:

```dart
/// R$ 1.234,56 a partir de centavos. Negativo/absurdo não ocorre (CHECK).
String formatarReais(int centavos);

/// Aceita "5,49", "5.49", "5", "R$ 5,49"; vazio/nulo → null; negativo → lança.
int? parsePrecoParaCentavos(String? texto);

/// Total dos itens marcados: soma dos subtotais arredondados ao centavo.
/// subtotal(item) = round(quantidade * precoCentavos)
int totalCarrinho(Iterable<Item> itens);
```

- **Arredondamento:** cada subtotal é arredondado ao centavo (`round`) e depois somado — resultado previsível e estável entre dispositivos (quantidade é `numeric`, pode ser fracionária, ex.: 0,5 kg).
- Nada de `double` para dinheiro: preço é `int` (centavos) e a soma é inteira.

## 7. Testes

**Unit — formatação/parsing/total:**
- `deve_formatar_reais_quando_centavos` (`549` → `R$ 5,49`; `123456` → `R$ 1.234,56`).
- `deve_parsear_preco_quando_virgula_ponto_ou_inteiro`; `deve_retornar_null_quando_vazio`; `deve_rejeitar_quando_negativo`.
- `deve_somar_apenas_marcados_com_preco_quando_total` (ignora pendentes e sem preço).
- `deve_arredondar_subtotal_quando_quantidade_fracionaria` (ex.: 0,5 × 999 = 500).

**Unit — repositório (`listas_repository_test.dart`):**
- `deve_gravar_e_enfileirar_preco_quando_adicionar_item_com_preco` (payload tem `preco_centavos`).
- `deve_limpar_preco_quando_editar_com_limparPreco`; `deve_preservar_preco_quando_editar_outro_campo`.
- `deve_copiar_preco_quando_duplicar_lista` (RF-20).

**Unit — aplicador remoto:**
- `deve_mapear_preco_ausente_para_null_quando_linha_antiga`; `deve_mapear_preco_quando_presente`.

**Widget:**
- `deve_salvar_preco_quando_editor_preenchido` e erro inline com preço inválido.
- `deve_mostrar_total_no_rodape_quando_ha_marcados_com_preco`; `nao_deve_somar_sem_preco_quando_total`.
- `deve_mostrar_total_no_modo_mercado_quando_marca_item_com_preco`.
- Escala de texto 2.0 sem overflow na faixa.

**SQL:** `supabase/tests/` — o CHECK de `preco_centavos` (negativo rejeitado; `null` aceito; teto). Pode entrar em `rls_tests.sql` ou num script próprio citado no CI.

## 8. Decisões registradas (21/09/2026)

1. Preço como **coluna do item** (`preco_centavos integer`), propagado pelo caminho normal (Drift + fila + LWW); sem tabela nova.
2. **Centavos inteiros** (sem ponto flutuante); `null` = sem preço; `0` é válido; negativo rejeitado.
3. Total = **itens marcados** ("no carrinho"), arredondando cada subtotal ao centavo.
4. Entrada do preço no **editor do item**; faixa no **rodapé da lista + modo mercado**.
5. **Sem policy nova** (a coluna herda o RLS de `itens_lista`); sem ADR novo.
6. BRL fixo.
7. Fase **25**, requisito **RF-21**.

## 9. Documentos relacionados
- [01 Banco de Dados](../01-banco-de-dados.md) — coluna/check
- [03 Sincronização](../03-sincronizacao-offline.md) — payload de item
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — editor e faixa do total
- [12 PRD](../12-prd.md) — RF-21
- [14 Tarefas](../14-tarefas.md) — Fase 25
