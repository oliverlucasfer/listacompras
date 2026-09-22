# Frente — Quantidades em Fração (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 7)
> **Fase:** 29 · **Requisito:** RF-25 (quantidades em fração)
> **Docs donos:** [04](../04-importacao-lista.md) (contrato do parser), [05](../05-app-flutter.md),
> [10](../10-wireframes-telas.md), [12](../12-prd.md), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

Comprar "meio quilo" é comum, mas o app só aceita números decimais: digitar `0,5` é chato e a **exibição** mostra `0.5` (e, para terços, `0.3333333333333333`). O usuário pensa em frações (`½ kg`, `1 1/2 kg`), não em decimais.

A feature é 100% local: **entrada** aceita frações e **exibição** mostra glifos — sem schema, RLS ou sync.

## 2. Escopo

**Dentro:**
- Entrada aceita fração simples (`1/2`), mista (`1 1/2`), glifos unicode (`½`, `1½`) — na **entrada rápida**, no **editor do item** e na **importação** (mesmo parser).
- Exibição com glifos comuns (`½ ¼ ¾ ⅓ ⅔`, mistos como `1½`) e corte de decimais longos (≤ 3 casas).

**Fora:** palavras (`meio`/`meia`), embalagem ("pacote de 5"), mudança de schema (a quantidade continua `numeric`).

## 3. Domínio (funções puras)

`lib/features/listas/domain/quantidade.dart` (hoje só tem `formatarQuantidade`):

```dart
/// Interpreta uma quantidade: inteiro/decimal pt-BR (`2`, `1,5`, `1.5`),
/// fração simples (`1/2`), glifo (`½`) ou mista colada (`1½`). Processa um
/// **token único** — o misto espaçado (`1 1/2`) é combinado pelo parser.
/// `null` se não for quantidade (ou inválida: denominador 0, negativo).
double? parseQuantidade(String texto);

/// Formata para exibição: inteiro → `2`; parte fracionária que casa um glifo
/// comum (½ ¼ ¾ ⅓ ⅔, com tolerância) → misto (`1½`, `1¼`, `2⅓`); senão
/// arredonda para ≤ 3 casas e corta zeros (`1.2`, `0.143`).
String formatarQuantidade(double q);
```

- Glifos: `½ ¼ ¾ ⅓ ⅔` (mais comuns). Casamento com tolerância de `0.001` (ex.: `1/3` e `0.333` ≈ `0.3333…` → `⅓`).
- Misto: parte inteira + glifo (`1½`, `1¼`, `2⅓`); sem parte inteira → só o glifo (`½`).
- Corte: só depois de descartar a tolerância de glifo; `q.toStringAsFixed(3)` com remoção de zeros finais (`1.200` → `1.2`, `1/7` → `0.143`). Valores que casam um glifo viram glifo antes do corte (`1.25` → `1¼`, `0.333` → `⅓`).
- `parseQuantidade` trata **um token**; o **misto espaçado** (`1 1/2`) é combinado pelo parser, não por ela.
- `formatarQuantidade` é a **fonte única** já usada pela linha do item, editor, modo mercado, importação e "adicionar de outra lista" — a mudança vale para todos.

## 4. Parser compartilhado (`lib/core/importacao/parser_lista_local.dart`)

A leitura da quantidade (`_qtdInicio`/`_qtdFim` e os regex `_soNumero`/`_numeroColado`) passa a reconhecer frações, reusando `parseQuantidade`:
- **Token único**: `½`, `1½`, `1/2` (com ou sem unidade colada: `½kg`).
- **Misto separado**: `1 1/2 kg` → tokens `['1','1/2','kg']`; o parser combina o inteiro inicial com a fração seguinte (e então lê a unidade).
- Mantém a proteção de decimais (`_protegerDecimais`) e a regra `quantidade ≤ 0 → 1` com aviso (doc 04 §3, R-02).

Isso beneficia **entrada rápida** (`interpretarItemAvulso`) e **importação** (`analisarListaLocal`) sem código duplicado.

## 5. Editor do item

- `_quantidadeLida` (`tela_lista_screen.dart`) passa a usar `parseQuantidade` — aceita `1/2` e `½` digitados.
- O texto inicial do campo já usa `formatarQuantidade` → mostra o glifo.
- Os steppers (`+`/`−`) continuam somando/subtraindo 1 (a fração é preservada no restante).

## 6. Testes

**Unit — `quantidade.dart`:**
- `parseQuantidade`: `2`→2; `1,5`/`1.5`→1.5; `1/2`→0.5; `½`→0.5; `1½`→1.5; **token único** — o misto espaçado (`1 1/2`) é combinado pelo parser, então aqui → `null`; inválido (`abc`, `1/0`, negativo)→null.
- `formatarQuantidade`: `2`→`2`; `0.5`→`½`; `1.5`→`1½`; `0.25`→`¼`; `1/3`→`⅓`; `1.25`→`1¼`; por tolerância, `0.333` também → `⅓`; fora dos glifos corta para ≤ 3 casas (`1/7`→`0.143`, `1.2`→`1.2`).

**Parser (`parser_lista_local_test.dart`):**
- `deve_ler_fracao_quando_glifo` (`½ kg de queijo` → 0.5 kg).
- `deve_ler_fracao_quando_numerica` (`1/2 kg` → 0.5).
- `deve_ler_misto_quando_espacado` (`1 1/2 kg` → 1.5).
- `deve_ler_misto_quando_colado` (`1½ kg` → 1.5).
- Regressão: `1,5 kg` continua 1.5; `2 pct` continua `Unidade.pct`.

**Editor (widget):**
- `deve_aceitar_fracao_quando_digitada` (`1/2` → item com quantidade 0.5).
- `deve_exibir_glifo_quando_item_meio_quilo` (linha mostra `½`).

## 7. Documentos donos no mesmo PR
- `04 §3/§4`: o contrato do parser passa a aceitar frações (formas e exemplos).
- `05 §6.3` (entrada/editor) e `10` (nota de exibição): frações aceitas e exibidas com glifos.
- `12` (RF-25 + rastreabilidade), `14` (Fase 29 + progresso), `16` (A5).

## 8. Decisões registradas (21/09/2026)

1. Entrada aceita fração numérica (`1/2`), mista (`1 1/2`), glifos (`½`, `1½`); **sem palavras**.
2. Exibição: glifos comuns (½ ¼ ¾ ⅓ ⅔) + corte de decimais longos (≤3 casas) — `formatarQuantidade` como fonte única.
3. Mesmo parser para entrada rápida, editor e importação; `04` atualizado.
4. Quantidade continua `numeric`; **sem schema/RLS/sync**; sem ADR novo. Fase **29**, requisito **RF-25**.

## 9. Documentos relacionados
- [04 Importação](../04-importacao-lista.md) — contrato do parser
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — entrada/exibição
- [12 PRD](../12-prd.md) — RF-25
- [14 Tarefas](../14-tarefas.md) — Fase 29
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda A (A5)
