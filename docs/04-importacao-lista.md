# 04 — Importação de lista (parser local)

> Navegação: [← 03 Sincronização](03-sincronizacao-offline.md) · [05 App Flutter →](05-app-flutter.md)

**Este documento é o dono do contrato da importação de lista por texto (RF-16): parser local determinístico, limites de entrada, enums e sugestão de categoria.** O app é offline-first: a extração acontece inteiramente no dispositivo, sem rede e sem IA.

---

## 1. Visão geral

```
Texto colado ou digitado ─► analisarListaLocal()  (lib/core/importacao/parser_lista_local.dart)
                          │ parser determinístico, offline
                          ▼
                    Sugestão de categoria (memória → dicionário → outros)
                          │
                    Pré-visualização editável ─► confirmação ─► gravação local (fila)
```

Fluxo de UX completo (modal, pré-visualização, confirmação) está em [05 §6.4](05-app-flutter.md) e [10 §4](10-wireframes-telas.md).

---

## 2. Contrato

- **Entrada:** texto livre em português, até **10.000 caracteres** (`maxCaracteresImportLocal`).
- **Saída:** `RespostaParse { itens: List<ItemExtraido>, aviso: String? }`.
- **Erro:** quando nenhum item é reconhecido, `ErroImportacao` com mensagem amigável (`AppStrings.importRespostaInvalida`); a UI nunca vê exceção crua.
- **Rede:** nenhuma. Não há chamada HTTP, Edge Function, API key ou rate limit.
- **`aviso`:** preenchido quando algum item entra com quantidade padrão (`AppStrings.importLocalAvisoPadrao`).

## 3. Algoritmo do parser

`analisarListaLocal(texto)`:

1. Normaliza a vírgula **entre dígitos** como decimal (`1,5` → `1.5`) e só então segmenta o texto por `,`, `;`, quebra de linha e o conectivo ` e ` — vírgula entre itens continua separador (`arroz, leite` → 2 itens).
2. Para cada segmento, lê quantidade/unidade no **início** ou no **fim** (`1kg de arroz`, `arroz 1kg`, `2 leites`, `leite 2`). A quantidade aceita decimal pt-BR (`1,5`), **fração numérica** (`1/2`), **mista** (`1 1/2`) e **glifos** (`½`, `1½`) — RF-25.
3. Sem quantidade → `1 un` e marca `aviso`; quantidade **`≤ 0`** é tratada como ausente (entra `1` com a unidade explícita do texto, ex.: `0 kg de arroz` → `1 kg`) e também marca `aviso` — `ItemExtraido.quantidade` é sempre `> 0`.
4. Converte quantidade com vírgula (`1,5` → `1.5`); capitaliza o nome; ignora segmentos vazios.
5. `interpretarItemAvulso(texto, {unidadePadrao})` é usado pelo campo "Adicionar item" (F12-T06): unidade explícita do texto vence; sem unidade, usa a do seletor.

**Frações (RF-25, F29):** a quantidade é interpretada por `parseQuantidade` (`lib/core/dominio/quantidade.dart`) e o parser reconhece fração numérica (`1/2 kg`), **mista separada** (`1 1/2 kg` → inteiro + fração) e glifos (`½ kg`, `1½ kg`), com ou sem unidade colada (`½kg`). `parseQuantidade` trata **um token único**; o misto espaçado é combinado pelo parser. Fração inválida (`1/0`) não quebra o fluxo: cai na regra de quantidade ausente (`1` + token no nome, unidade `un`, com `aviso`; a unidade explícita do texto também é descartada). O contrato vale para a **entrada rápida** e a **importação** — unidade e demais campos ficam inalterados.

## 4. Enums

- **Unidades** (fonte única [01 §3.1](01-banco-de-dados.md)): `un, kg, g, l, ml, caixa, pacote, pct, dz` — replicado em `lib/core/dominio/unidade.dart`.
- **Categorias** (fonte única [01 §3.2](01-banco-de-dados.md)): `hortifruti, mercearia, frios, laticinios, congelados, padaria, bebidas, pet, limpeza, higiene, outros`.

As frações (RF-25) **não alteram** os enums: a quantidade continua `numeric` e a unidade segue esta mesma lista.

## 5. Sugestão de categoria

Cadeia local em camadas (RF-15): memória por nome → dicionário estático → `outros` (`lib/core/categorias/sugestao_categorias.dart`). Não há IA; o usuário pode editar a categoria na pré-visualização.

**Desempate do dicionário (R-08, F20-T09):** quando mais de um termo casa, vence (a) o de **mais palavras** ("leite condensado" → mercearia sobre "leite" → laticínios); depois (b) o **núcleo do nome**, isto é, o termo que aparece **primeiro** na frase ("suco de laranja": "suco" na posição 0 vence "laranja" na posição 2 — antes o desempate era alfabético e dava hortifruti); depois (c) o termo mais longo; (d) ordem alfabética. O match continua exigindo que **todas** as palavras do termo apareçam, em sequência.

## 6. Estrutura no repositório

```
lib/core/importacao/
├── parser_lista_local.dart   # parser determinístico (RF-16)
├── resposta_import.dart      # ItemExtraido / RespostaParse / limite
└── erro_importacao.dart      # ErroImportacao (mensagem amigável)

test/core/importacao/parser_lista_local_test.dart
test/features/importacao/modal_importar_test.dart
```

## 7. Testes

- `flutter test test/core/importacao/parser_lista_local_test.dart` (unit do parser)
- `flutter test test/features/importacao/` (modal + pré-visualização)
- `flutter test` — suíte completa; CI verde ([07](07-qualidade-ci.md)).

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — enums (fonte única)
- [05 App Flutter](05-app-flutter.md) — modal de importação e pré-visualização
- [12 PRD](12-prd.md) — RF-16
