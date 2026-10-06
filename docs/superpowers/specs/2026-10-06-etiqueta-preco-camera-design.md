# Frente — Preço por etiqueta (OCR da prateleira) (design)

> **Status:** aprovado em 06/10/2026 (decisões registradas na Seção 9)
> **Fase:** 59 · **Requisito:** RF-40 (ler a etiqueta de prateleira com OCR on-device e preencher/criar item com preço)
> **Docs donos:** [05](../../05-app-flutter.md) (app/UX), [10](../../10-wireframes-telas.md) (layout),
> [12](../../12-prd.md) (requisitos), [09](../../09-runbook-operacoes.md) (dependências/permissões),
> [15](../../15-design-system.md) (componentes), [13](../../13-premodelo-tecnico.md) (resumo),
> [14](../../14-tarefas.md) (tarefas), [16](../../16-roadmap-pos-mvp.md) (frente)

---

## 1. Motivação

A persona **P1** (comprador solo) usa o celular **no mercado**. Hoje o preço unitário (RF-21)
é digitado à mão no editor — no corredor, com o produto na mão, isso é lento e sujeito a erro.
Uma **etiqueta de prateleira** já traz o preço (e às vezes o nome); reconhecê-la pela **câmera**
e preencher o preço (ou criar o item) sem digitar encurta o fluxo, reaproveitando toda a
infraestrutura de **OCR on-device** da importação por foto (RF-37).

**A feature é 100% offline.** O OCR roda **no aparelho** (ML Kit, modelo bundled); a imagem
**não é armazenada** nem enviada a lugar algum.

> **Não é leitura de código de barras.** O PRD mantém o *scan de código de barras* **fora de
> escopo** (§7 do 12): sem rede/banco de produtos não há como obter nome/preço de um EAN. Esta
> frente lê o **texto** da etiqueta (OCR), no mesmo espírito do RF-37.

## 2. Escopo

**Dentro:**
- **RF-40:** com a câmera, ler a etiqueta da prateleira e obter **preço** (e, best-effort, **nome**),
  oferecendo **três usos** em contexto de compra:
  1. **Criar item novo** já com nome/preço (no modo mercado);
  2. **Aplicar o preço a um item existente** da lista;
  3. **Preencher o campo "Preço (R$)"** do editor do item aberto.
- Um **parser puro e determinístico** (`analisarEtiqueta`) que extrai preço (preço cheio; valor
  por kg só como *fallback*) e um nome opcional do texto do OCR.
- **Preview editável** antes de gravar (padrão do "Importar", RF-16): nada é gravado sem
  confirmação.
- Reuso da captura de imagem/OCR já existente (`OcrTexto` + `FonteImagem`), com um helper
  **compartilhado** com o "Importar por foto".

**Fora:** código de barras/EAN e catálogo de produtos; múltiplas fotos por leitura (1 imagem);
armazenamento/anexo da imagem; reconhecer etiquetas de outros países/formatações fora de
`R$`/pt-BR; Web/Desktop (o botão só aparece onde há OCR); mudar o parser de lista (RF-16)
ou o limite `maxCaracteresImportLocal`.

## 3. Arquitetura (domínio puro + reuso do OCR)

### 3.1. Domínio novo (testável, sem plugin)

`lib/features/etiqueta/domain/etiqueta.dart`:

```dart
class EtiquetaLida {
  final String? nome;              // best-effort; pode ser null
  final int precoCentavos;         // preço do item (>0; <= teto do RF-21)
  final int? precoPorKgCentavos;   // valor "por kg" detectado, se houver
}

/// Determinístico, offline, sem plugin. Devolve null se nenhum preço for achado.
EtiquetaLida? analisarEtiqueta(String texto);
```

O parser **reusa** `parsePrecoParaCentavos` (`lib/features/listas/domain/preco.dart`) para a
conversão de cada valor e o teto `R$ 999.999,99` (CHECK do RF-21). É o único ponto com lógica
"arriscada" e é coberto por testes unitários.

### 3.2. Captura compartilhada (refatoração leve, sem mudar comportamento)

Extrair do `modal_importar.dart` (RF-37) o **bottom sheet câmera/galeria + OCR** para um helper
compartilhado, por exemplo `lib/features/ocr/ui/captura_foto.dart`:

```dart
sealed class ResultadoCaptura {}
class CapturaTexto    extends ResultadoCaptura { final String texto; }
class CapturaCancelada extends ResultadoCaptura {}
class CapturaVazia     extends ResultadoCaptura {}  // OCR sem texto
class CapturaFalha     extends ResultadoCaptura {}  // permissão/picker/OCR

Future<ResultadoCaptura> capturarTextoDeFoto(BuildContext context, WidgetRef ref);
```

- Reusa `OcrTexto.extrair`, `FonteImagem.daCamera()/daGaleria()` e o padrão de manter o
  `ocrTextoProvider` (`autoDispose`) vivo via `listenManual` enquanto o OCR roda.
- O **"Importar por foto" passa a usar o helper** e mapeia cada `ResultadoCaptura` para o
  `AppBanner`/estado que já exibe hoje (comportamento preservado; regressão coberta por testes).
- O **helper não grava nada** e **não persiste a imagem**.

## 4. Fluxo e UI

### 4.1. Modo mercado (`mercado_screen.dart`, RF-18)

1. **Botão de câmera** no `AppBar` (ícone `photo_camera_outlined`), visível **apenas** quando
   `plataformaComOcr()`.
2. Toque → `capturarTextoDeFoto` → `analisarEtiqueta(texto)`:
   - **sem texto** → aviso (`etiquetaNenhumTexto`);
   - **texto sem preço** (`null`) → aviso (`etiquetaNaoReconhecida`);
   - **falha** → aviso (`ocrFalha`, reusado).
3. **Preço encontrado** → abre o **bottom sheet "Etiqueta lida"** (preview editável, §4.3).

### 4.2. Editor do item (`sheet_editar_item.dart`, RF-21/F25)

1. **Ícone de câmera** junto ao campo **"Preço (R$)"**, visível **apenas** quando `plataformaComOcr()`.
2. Toque → `capturarTextoDeFoto` → `analisarEtiqueta`:
   - erro/vazio/sem preço → aviso amigável (campos intactos);
   - preço encontrado → preenche `_preco` (formatado pt-BR); se `_nome` estiver **vazio**, preenche
     com o nome reconhecido; se o preço vier **do fallback por kg**, ajusta a unidade para `kg`.
3. **Não há tela nova**: o próprio editor **é o preview editável**; o usuário revisa e confirma em
   **Salvar** (que já grava `preco_centavos`).

### 4.3. Preview editável "Etiqueta lida" (modo mercado)

Bottom sheet com os mesmos campos/blocos do editor (nome, quantidade, unidade, categoria, preço),
pré-preenchidos pela leitura:

- **Nome** (editável; pode vir vazio), **Preço (R$)** (obrigatório, validado como hoje),
  **Quantidade** (padrão `1`), **Unidade** (padrão `un`; `kg` quando o preço veio do fallback
  por kg) e **Categoria** (sugerida pela cadeia local `sugerirCategoria`, editável).
- **Origem** (segmented): **"Novo item"** (padrão) | **"Item existente"**.
  - **Novo item:** grava com a **dedup do app** (`adicionarItemDedup`) e aplica o **preço** ao item
    resultante (se o nome já existir, o item é somado/substituído e o preço, atualizado).
  - **Item existente:** lista os itens da lista (pendentes primeiro) para escolher um; ao escolher,
    grava `editarItem(itemId, precoCentavos)`.
- **Confirmar** grava; **Cancelar** não grava. Preço inválido → erro inline (como no editor).

> A gravação do preço junto com a criação: o contrato público de escrita já aceita
> `precoCentavos` (RF-21/F25-T02). "Novo item" usa essa via ou cria via dedup e em seguida aplica o
> preço — a ser fixado no plano (F59) sem alterar o comportamento da dedup (RF-10).

## 5. Regras e casos-limite

### 5.1. Extração (parser)

- **Valor monetário:** um token só conta como **preço** se for precedido de `R$` ou tiver
  **separador decimal** (`5,49`, `5.49`, `R$ 1.234,56`, `1.234`); um **inteiro solto**
  (`200`, `50`) é quantidade/modelo/peso (ex.: `200g`, `5kg`), não preço.
- **Marcação por kg/unidade (por token):** um número só é "por kg" se o texto **imediatamente
  após** ele casar com o marcador — `<número>/kg` (com ou sem espaços), `por kg`, `por 100 g`
  ou `por unidade`. O contexto é decidido **por token**, não por linha: em
  `R$ 39,90 R$ 79,80/kg` só o segundo valor vai para `precoPorKgCentavos` (o primeiro é o
  preço do item).
- **Escolha do preço do item** (determinística):
  1. valor após **"por"** (promo "de **R$ 9,99** por **R$ 6,99**") → o segundo;
  2. senão, o **maior** valor **não-kg** da etiqueta (o preço cheio costuma ser o mais destacado);
  3. se **não houver** valor não-kg, usa o valor **por kg** como **fallback** (`precoCentavos`) e
     sinaliza unidade sugerida `kg`.
- **Nome:** primeira linha com ≥ 3 letras que **não** seja só preço/`R$`/`kg`/`por`; senão `null`.
- Sem nenhum valor monetário → `null` (a UI mostra `etiquetaNaoReconhecida`).

### 5.2. Comportamento geral

- **1 imagem** por leitura; a **imagem não é persistida**; só o texto extraído é usado.
- Cancelamento (fonte devolve `null`) → sem efeito.
- Gate `plataformaComOcr()` (Android/iOS); **Web/Desktop não mostram** os botões e não compilam os
  plugins de captura.
- Botão de câmera com **estado de carregando** enquanto o OCR roda; desabilitado durante a leitura.
- OCR é **best-effort**: o preview/editor sempre permitem corrigir antes de gravar (RNF-06/alvos ≥ 48dp).

## 6. Dependências, permissões e riscos

- **Sem dependência nova:** reusa `google_mlkit_text_recognition` e `image_picker` (já presentes,
  RF-37) atrás de `OcrTexto`/`FonteImagem`.
- **Sem permissão nova:** `CAMERA` (Android) e `NSCameraUsageDescription` (iOS) já declaradas
  (RF-33/RF-37); o guard de CI do manifest de release permanece válido (ML Kit permitido; sem
  `INTERNET`).
- **Tamanho do app:** inalterado (nenhuma lib nativa nova).
- **Risco de precisão:** fonte pequena/promo grudada em etiquetas reais → mitigado pelo **preview
  editável** e pelas mensagens amigáveis; o parser é determinístico e testado.

## 7. Testes

- **Unit — `analisarEtiqueta`:** preço cheio com `R$`; valor por kg ao lado (`R$/kg`); promo
  "de X por Y" (escolhe Y); separador de milhar; **só** valor por kg (fallback + unidade `kg`);
  texto sem preço → `null`; com/sem nome; teto do RF-21.
- **Widget — modo mercado** (com `FakeOcr`/`FonteImagemFake`): botão **visível** onde há OCR e
  **oculto** onde não; **criar item** com preço; **aplicar a item existente**; OCR vazio/sem preço →
  avisos; cancelar → sem efeito; preço inválido → erro inline.
- **Widget — editor do item:** ícone de câmera preenche o preço; preenche o nome só quando vazio;
  fallback por kg ajusta a unidade; avisos amigáveis.
- **Regressão:** o "Importar por foto" (RF-37) continua com o mesmo comportamento após a extração
  do helper de captura.
- **CI:** `dart format .` + `flutter analyze` + `flutter test` verdes; plugin real só em smoke device.

## 8. Governança

- `12`: **RF-40** (tabela + matriz de rastreabilidade + **fora de escopo** explicitando que
  *código de barras continua fora* e que isto é OCR de etiqueta).
- `05`: nova seção **§6.19 "Preço por etiqueta (OCR)"** + contratos/providers, gate e referência a
  partir de §6.3 (editor) e §6.5 (modo mercado).
- `10`: wireframe do **botão de câmera** (mercado), do **ícone no campo de preço** (editor) e do
  **preview "Etiqueta lida"**.
- `09`: nota de que **não há** dependência/permissão nova (reuso de RF-37).
- `15`: componentes usados (botão/ícone, bottom sheet de preview) e acessibilidade.
- `13`: resumo do fluxo e do parser.
- `14`: **Fase 59** com as tarefas, critérios de pronto e a linha da tabela de progresso.
- `16`: frente correspondente no roadmap pós-MVP.
- **i18n (RF-39):** strings novas em pt/en/es; **bump de versão** de `pubspec.yaml` com paridade em
  `web/version.json` e `flutter test` (guard `version_json_test`).

## 9. Decisões registradas (06/10/2026)

1. **Dois fluxos** atendidos: **preencher preço** de um item existente **e** **criar item novo**.
2. **Preview editável sempre** antes de gravar (nada é gravado sem confirmação).
3. **Preço cheio** é o preço do item; **valor por kg** só como *fallback*.
4. Pontos de entrada: **botão no modo mercado** (criar/aplicar) **e** **ícone no campo de preço
   do editor** (preencher; o editor é o preview).
5. **Reuso** de `OcrTexto`/`FonteImagem` (OCR on-device) com helper de captura **compartilhado**;
   **sem dependência/permissão nova**.
6. **Não é código de barras** — essa alternativa permanece **fora de escopo**.
7. Fase **59**, requisito **RF-40**.

## 10. Documentos relacionados
- [04 Importação de lista](../../04-importacao-lista.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md)
- [09 Runbook](../../09-runbook-operacoes.md) · [12 PRD](../../12-prd.md) · [14 Tarefas](../../14-tarefas.md) · [16 Roadmap](../../16-roadmap-pos-mvp.md)
