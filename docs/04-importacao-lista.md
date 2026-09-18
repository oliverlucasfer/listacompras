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
2. Para cada segmento, lê quantidade/unidade no **início** ou no **fim** (`1kg de arroz`, `arroz 1kg`, `2 leites`, `leite 2`).
3. Sem quantidade → `1 un` e marca `aviso`.
4. Converte quantidade com vírgula (`1,5` → `1.5`); capitaliza o nome; ignora segmentos vazios.
5. `interpretarItemAvulso(texto, {unidadePadrao})` é usado pelo campo "Adicionar item" (F12-T06): unidade explícita do texto vence; sem unidade, usa a do seletor.

## 4. Enums

- **Unidades** (fonte única [01 §3.1](01-banco-de-dados.md)): `un, kg, g, l, ml, caixa, pacote, pct, dz` — replicado em `lib/features/listas/domain/unidade.dart`.
- **Categorias** (fonte única [01 §3.2](01-banco-de-dados.md)): `hortifruti, mercearia, frios, laticinios, congelados, padaria, bebidas, pet, limpeza, higiene, outros`.

## 5. Sugestão de categoria

Cadeia local em camadas (RF-15): memória por nome → dicionário estático → `outros` (`lib/core/categorias/sugestao_categorias.dart`). Não há IA; o usuário pode editar a categoria na pré-visualização.

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
