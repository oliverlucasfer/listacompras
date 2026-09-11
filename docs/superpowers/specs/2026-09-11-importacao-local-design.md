# Spec — Importação de Lista por Texto sem IA (Parser Local)

> Navegação: [← 12 PRD](../../12-prd.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-11 · Status: aprovada

## 1. Objetivo

Permitir importar uma lista a partir de texto livre **sem depender de IA/rede**, com um parser local determinístico, preservando a pré-visualização editável. A IA continua disponível como modo opcional. Requisito novo: **RF-16** ([12](../../12-prd.md)).

## 2. Decisões (2026-09-11)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Relação com a IA | **Local é o padrão; IA opcional** | Funciona offline e sem cota (R-02); IA segue para textos bagunçados |
| Entrada | **Um botão "Importar lista"** com `SegmentedButton` Rápido \| IA (Rápido padrão) | Um fluxo, dois motores; mesma textarea e pré-visualização |
| Robustez do parser | **Núcleo determinístico** (sem extenso/frações) | Previsível e 100% testável |
| Onde vive o parser | `lib/core/importacao/` (puro), espelhando `core/categorias` | Sem rede/DB; consistente com o repo |
| Tipos compartilhados | `ItemExtraido`/`RespostaParse` movem para `core/importacao` | Nome genérico; IA importa do core |
| Nomes | Renomear para genérico (sem "Ia" nos arquivos de importação) | A importação não é exclusiva da IA |
| Limite de caracteres | **Local: 10.000**; IA: 2.000 (inalterado) | Local não tem custo; IA tem teto de custo/latência |
| Categoria | Cadeia local existente (memória → dicionário → `outros`) | ADR-011; categoriza offline |
| Dependências | **Nenhuma nova** | Parser em Dart puro |

## 3. Parser local (`lib/core/importacao/parser_lista_local.dart`)

`List<ItemExtraido> analisarListaLocal(String texto)` — puro, síncrono, sem rede/DB.

1. **Segmentação**: quebra por linha, `,`, `;` e pelo token ` e ` (`\s+e\s+`, case-insensitive).
2. **Por segmento**, detecta `quantidade [unidade]` no **início** ou no **fim** do segmento, removendo conectivos (`de`, `do`, `da`, `em`) entre quantidade e nome. O restante é o **nome**.
3. **Quantidade** ausente → `1`. Números aceitam `,` ou `.` como decimal (`1,5` → `1.5`).
4. **Unidade** ausente → `Unidade.un`. Sinônimos (normalizados, sem acento/caixa) → enum fechado:
   * `un, unidade(s)` → `un`
   * `kg, quilo(s), quilograma(s)` → `kg`
   * `g, grama(s)` → `g`
   * `l, litro(s)` → `l`
   * `ml, mililitro(s)` → `ml`
   * `caixa(s), cx` → `caixa`
   * `pacote(s), pct` → `pacote`
   * `dz, dúzia(s)` → `dz`
5. **Nome**: limpa espaços, remove pontuação nas pontas, mantém o texto do usuário (sem singularizar — o usuário edita na pré-visualização). Nome vazio → segmento descartado.
6. **Categoria** inicial `outros` (o fluxo de entrada enriquece — §4).
7. Segmentos vazios/whitespace são ignorados; texto vazio → lista vazia.
8. **Aviso**: se algum item ficou com a quantidade padrão (sem número explícito), devolver aviso amigável (ver §4).

Normalização de texto (acento/caixa/espaços) é extraída para `lib/core/texto/normalizar.dart` (`normalizarTexto`) e reusada por `SugestaoCategorias`.

## 4. Fluxo de importação (`lib/features/importacao/ui/`)

- **`ModalImportar`** (era `ModalImportarIa`): textarea + contador + `SegmentedButton<ModoImportacao>{ rapido, ia }` (padrão `rapido`) + botão "Extrair itens".
  - **Rápido** (offline): `analisarListaLocal` → enriquece categorias com `SugestaoCategorias.sugerirCategoria` (por item) → devolve `RespostaParse` (mesma rota da pré-visualização). Sem estado de carregamento.
  - **IA**: fluxo atual (`ParseListaClient`, loading/erros do contrato [04 §2](../../04-ia-edge-function.md)). Se offline, a chamada devolve erro amigável (`iaSemConexao`).
  - Limite de caracteres por modo: Rápido 10.000; IA 2.000 (contador e bloqueio do botão).
- **`ModalPrevisaoImportacao`** (era `ModalPrevisaoIa`): inalterado em comportamento; `confirmarItensImportados` (já genérico) grava os itens no repositório local.
- **Tela da lista**: o botão "Importar por IA" passa a **"Importar lista"** (`abrirModalImportar`).

## 5. Arquivos

**Criar**
- `lib/core/importacao/resposta_import.dart` — `ItemExtraido`, `RespostaParse`, `maxCaracteresImportLocal`
- `lib/core/importacao/parser_lista_local.dart` — `analisarListaLocal`
- `lib/core/texto/normalizar.dart` — `normalizarTexto`
- `lib/features/importacao/ui/modal_importar.dart` — `ModalImportar`, `abrirModalImportar`, `ModoImportacao`
- `lib/features/importacao/ui/modal_previsao_importacao.dart` — `ModalPrevisaoImportacao`
- Testes: `test/core/importacao/parser_lista_local_test.dart`; movem/renomeiam `test/features/importacao/...`

**Mover/renomear**
- `features/ia/ui/modal_importar_ia.dart` → `features/importacao/ui/modal_importar.dart`
- `features/ia/ui/modal_previsao_ia.dart` → `features/importacao/ui/modal_previsao_importacao.dart`
- `features/ia/domain/resposta_parse.dart` → **dividir**: `ItemExtraido`/`RespostaParse` vão para `core/importacao/resposta_import.dart`; `ErroIa`, `mensagemContratoIa`, `maxCaracteresEntradaIa` ficam em `features/ia/domain/contrato_ia.dart`.
- Testes `test/features/ia/modal_*` → `test/features/importacao/modal_*`.

**Modificar**
- `features/ia/data/parse_lista_client.dart`, `features/ia/providers/ia_providers.dart` — imports.
- `features/listas/ui/tela_lista_screen.dart` — botão/entry imports.
- `core/categorias/sugestao_categorias.dart` — reusar `normalizarTexto`.
- `core/l10n/app_strings.dart` — strings do seletor/limite local.

## 6. Strings novas

`importarLista` ("Importar lista"), `modoRapido` ("Rápido"), `modoIa` ("IA"), `importLocalAvisoPadrao` ("Itens sem quantidade entraram com 1 un."), `importLocalTextoLongo` ("Texto muito longo. Envie até 10.000 caracteres.").

## 7. Erros e estados

- Rápido: nunca falha por rede; texto vazio → `iaTextoVazio`; acima de 10.000 → `importLocalTextoLongo`.
- IA: inalterado (contrato [04 §2](../../04-ia-edge-function.md)).
- Pré-visualização: editável (nome/quantidade/unidade/categoria), cancelar não grava.

## 8. Testes

- **Unit** (`parser_lista_local_test.dart`): `"1kg de arroz"` → Arroz/1/kg; `"2 leites"` → 2/un; `"500g queijo prato"` → 500/g/queijo prato; `"arroz 1kg"`; separadores (`,`/`;`/linha/` e `); sem quantidade → 1 un (com aviso); sinônimos (quilo, gramas, litros, cx, pct, dúzia); acento/caixa; texto vazio → vazio; conectivos `de/do/da`.
- **Widget** (`modal_importar_lista_test`): modo Rápido extrai e abre a pré-visualização (sem rede); modo IA mantém o fluxo com fake client; contador/limite por modo.
- Manter os testes de IA renomeados.

## 9. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **12 PRD** | Novo **RF-16** (importação por texto sem IA) + matriz de rastreabilidade |
| **05 §6.4** | Dois modos (Rápido/IA); RF-16 |
| **10 §4.1** | Wireframe com o seletor de modo |
| **04 §1** | Nota: a IA é opcional; há modo local |
| **14** | Tarefas da Fase 11 |

## 10. Fora de escopo

- Quantidades por extenso/frações; singularização de nomes; parsing de marca/preço.
- Alterar o contrato da Edge Function ou o enum de unidades/categorias.

## 11. Critério de pronto

Parser local puro com testes cobrindo os casos da §8; modal com seletor Rápido/IA (Rápido padrão, offline); pré-visualização reusada; RF-16 e docs 05/10/04/14 atualizados; `dart format` + `flutter analyze` + `flutter test` verdes.
