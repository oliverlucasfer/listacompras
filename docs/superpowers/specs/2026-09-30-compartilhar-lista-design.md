# Frente — Compartilhar Lista sem Nuvem (design)

> **Status:** aprovado em 30/09/2026 (decisões registradas na Seção 9)
> **Fase:** 49 · **Requisito:** RF-33 (compartilhar lista — exportar/importar texto, arquivo e QR/código)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [15](../15-design-system.md) (componentes, se necessário),
> [04](../04-importacao-lista.md) (reuso do parser), [09](../09-runbook-operacoes.md) (permissões nativas),
> [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

A lista de compras costuma nascer de uma conversa: alguém anota, a outra pessoa
precisa receber. Hoje o app só permite **exportar o banco inteiro** (backup, RF-31) ou
**importar texto colado** dentro de uma lista existente (RF-16). Não há como passar
**uma lista específica** de forma direta e independente da nuvem.

A persona **P1 (Comprador solo)** é quem mais sente: quer mandar a lista para outra pessoa
comprar ou levar a própria lista para outro aparelho **sem conta**.

**A feature é 100% offline.** Nada trafega: o texto, o arquivo e o código/QR são gerados e
lidos no próprio aparelho. O compartilhamento por WhatsApp/e-mail usa o share sheet do sistema
e só sai do aparelho por ação explícita do usuário. **Sem schema, sem RLS, sem sync** (não existem).

## 2. Escopo

**Dentro:**
- RF-33: **enviar** uma lista em três formatos — **texto legível**, **arquivo `.json`** e
  **QR/código**.
- RF-33: **receber** uma lista por qualquer um dos três caminhos, sempre criando uma **lista nova**.
- Reuso do parser de texto livre (RF-16) para o formato texto.

**Fora (frentes seguintes):** mesclar em lista existente; compartilhar o banco inteiro (já existe:
RF-31); colaboração/sincronização (removida na F48); OCR de foto/nota (frente futura).

## 3. Modelo e formatos

**Domínio** (`lib/features/compartilhamento/domain/lista_compartilhada.dart`):

```dart
class ItemCompartilhado {
  final String nome;
  final double quantidade;   // > 0
  final Unidade unidade;     // enum fechado (lib/core/dominio/unidade.dart)
  final CategoriaItem categoria;
  final bool concluido;
  final int ordem;
  final int? precoCentavos;  // opcional
}

class ListaCompartilhada {
  static const versao = 1;
  final int versao;
  final String titulo;
  final List<ItemCompartilhado> itens;
}
```

Não carrega `id`, `dono_id` nem orçamento: a importação **gera UUIDs novos** (lista nova), então
não há colisão com dados existentes.

**Três representações, uma fonte de verdade:**

1. **JSON** (arquivo):
   ```json
   {"tipo":"minhas-listas/lista","versao":1,"titulo":"...","itens":[
     {"nome":"arroz","quantidade":2,"unidade":"kg","categoria":"mercearia",
      "concluido":false,"ordem":0,"preco_centavos":null}
   ]}
   ```
   O campo `tipo` distingue de um backup (que não o possui). `versao` permite evolução.
2. **Código/QR:** `ML1:` + `base64url(utf8(json))`. O prefixo identifica formato **e** versão;
   a leitura valida prefixo, base64 e versão.
3. **Texto legível:** uma linha por item, na ordem:
   `"<quantidade> <unidade> <nome>"` (ex.: `2 kg arroz`, `1 un Leite`), usando
   `formatarQuantidade` e `Unidade.valor`. **Concluídos entram como linhas comuns**
   (o parser RF-16 os recria como pendentes). **Sem preço e sem título** no texto.

**Decisão do texto:** o formato texto é **apenas os itens** — assim continua compatível com o
parser existente (colar no "Importar lista" também funciona). O título não vai no texto; a lista
nova recebe um título padrão editável (Seção 7).

## 4. Domínio de aplicação (repositório)

`CompartilhamentoRepository` (`lib/features/compartilhamento/data/`):

- `Future<ListaCompartilhada> exportarLista(String listaId)` — lê a lista e **todos** os itens
  ativos (`deletado_em IS NULL`), ordenados por `ordem` ASC e `id` ASC.
- `String codificar(ListaCompartilhada)` — devolve o `ML1:…`.
- `ListaCompartilhada decodificar(String codigo)` — valida prefixo/base64/versão/JSON.
- `String gerarTexto(ListaCompartilhada)` — as linhas legíveis.
- `Future<Lista> importarLista(ListaCompartilhada origem, {required String titulo})` — cria uma
  **lista nova** (UUID v4), com **Novos** UUIDs para cada item, **preservando** `quantidade`,
  `unidade`, `categoria`, `concluido`, `ordem` e `preco_centavos`; título = `titulo`.
  Escreve numa **transação**; retorna a `Lista` criada (para a UI navegar).

**Erros** (`CompartilhamentoInvalidoException`): prefixo `ML1:` ausente, base64 inválido, versão
desconhecida, JSON malformado, item com nome vazio ou `quantidade <= 0`, ou lista sem título.
Nada é gravado quando a entrada é inválida.

**Limite do código/QR:** sem compressão. Se `codificar(...).length` exceder
`limiteCodigoBytes` (≈ 2000), o envio por QR/código é bloqueado com aviso
("Lista grande — use texto ou arquivo."); texto e arquivo seguem disponíveis.

## 5. UI — Enviar

Na tela da lista (`tela_lista_screen.dart`), menu `⋮` → novo item **"Compartilhar"**
(`AppStrings.compartilhar`). Abre um **bottom sheet** (`AppSheet`) com três ações:

- **"Enviar como texto"** — `SharePlus.instance.share(ShareParams(text: gerarTexto(...)))`.
- **"Enviar arquivo"** — `XFile.fromData` (nome `<titulo-sanitizado>.json`,
  `application/json`), via o mesmo tratamento de indisponibilidade do backup
  (`MissingPluginException`/`UnimplementedError` → `AppStrings.compartilharIndisponivel`).
- **"QR code"** — sheet/tela com o QR gerado (`qr_flutter`) + botão **"Copiar código"**
  (copia o `ML1:…` para a área de transferência) e o aviso do limite quando excedido.

## 6. UI — Receber

Novo fluxo **"Receber lista"** (rota `push`, ex.: `/receber-lista`), acionado por ação no
painel (`painel_listas.dart`). É **distinto** do "Importar lista" (que adiciona a uma lista
existente, RF-16). Tela com:

- **Campo único** que **auto-detecta**: começa com `ML1:` → código; senão → texto livre (RF-16).
- Botão **"Arquivo"** (`file_selector`, sem filtro de tipo — mesma razão do backup; lê o JSON
  `ListaCompartilhada`).
- Botão **"Escanear QR"** — visível só onde há câmera (Android/iOS); abre o leitor e preenche
  com o código lido.
- **Pré-visualização editável**: título **editável** (padrão `AppStrings.listaCompartilhada`)
  + lista de itens com opção de incluir/excluir (reusa o padrão de
  `ModalPrevisaoImportacao`); nos formatos estruturados mostra o estado "concluído".
- Confirmar → `importarLista(...)` → navega para `/lista/<novoId>`. Cancelar não grava nada.

## 7. Plataformas, dependências e permissões

**Dependências novas (locais, sem rede):**
- `qr_flutter` — gerar QR (puro Dart; todas as plataformas).
- `mobile_scanner` — ler QR por câmera (Android/iOS). **Risco:** suporte fraco a Web/Desktop —
  isolar com **import condicional** + gate de plataforma (`plataformaComCamera()`, no padrão de
  `plataformaComVoz()` da F30) para que `flutter build web`/`windows` continue compilando.
  No Android usa o barcode do MLKit (bundled, sem rede); aumenta o footprint nativo.
  **Não** adiciona `INTERNET`.

**Permissões:** Android `CAMERA` (usada só no toque em "Escanear"; negação → aviso amigável);
iOS `NSCameraUsageDescription` (pt-BR). Web/Desktop não usam câmera (colam código/texto/arquivo).

**Leitor injetável:** interface `LeitorQr` + `leitorQrProvider` com implementação real
(`mobile_scanner`) e fake nos testes — a câmera real não roda no CI.

## 8. Testes

**Unit** (`test/features/compartilhamento/`):
- `deve_roundtrip_de_lista_compartilhada_quando_codifica_e_decodifica`.
- `deve_falhar_quando_prefixo_invalido` / `base64_invalido` / `versao_desconhecida` / `json_malformado`.
- `deve_gerar_texto_uma_linha_por_item_quando_exporta`.
- `deve_criar_lista_nova_com_uuids_novos_quando_importa` (não colide com existentes).
- `deve_preservar_ordem_concluido_preco_categoria_quando_importa`.
- `nao_deve_gravar_quando_item_invalido` (nome vazio / `quantidade <= 0`).

**Widget:**
- sheet "Compartilhar" mostra as três opções; cópia de código funciona; aviso quando excede o limite.
- tela "Receber" auto-detecta código × texto; erro amigável para entrada inválida; pré-visualização
  com título editável; confirma → cria e navega; cancela → nada.

Sem golden; o parser RF-16 permanece coberto pela suíte atual.

## 9. Decisões registradas (30/09/2026)

1. Três formatos de **envio** (texto, arquivo, QR/código) e três caminhos de **recepção**
   (texto, arquivo, QR/câmera ou colar código).
2. Importar **sempre cria lista nova** (UUIDs novos); **nunca mescla** (mesclar é papel do backup).
3. Compartilha **todos os itens** (inclui concluídos); estado preservado nos formatos estruturados.
4. Texto legível = **só linhas de item** (compatível com o parser RF-16); sem título e sem preço.
5. Código/QR = `ML1:` + base64url(JSON), sem compressão, com limite e fallback para arquivo/texto.
6. QR **exibido em todas as plataformas**; leitura por câmera só Android/iOS; "colar código" em todas.
7. Fluxo "Receber lista" separado do "Importar lista" (RF-16).
8. Fase **49**, requisito **RF-33**.

## 10. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — telas, rotas e providers
- [10 Wireframes](../10-wireframes-telas.md) — sheet "Compartilhar" e tela "Receber"
- [12 PRD](../12-prd.md) — RF-33
- [14 Tarefas](../14-tarefas.md) — Fase 49
- [16 Roadmap](../16-roadmap-pos-mvp.md) — origem da frente
