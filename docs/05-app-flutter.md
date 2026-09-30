# 05 — App Flutter (Arquitetura, Telas, UX e Design)

> Navegação: [← 04 Importação](04-importacao-lista.md) · [06 MVP & Entregas →](06-mvp-entregas.md)

**Este documento é o dono da arquitetura do app, da navegação/UX e do design system.** O app é **único e local** ("Minhas Listas", RF-31): sem conta, sem nuvem e sem sincronização (ADR-015). O Drift é a fonte da verdade.

---

## 1. Pacotes principais

| Pacote | Uso |
| :--- | :--- |
| `flutter_riverpod` / `riverpod_annotation` | State management (ADR-002) |
| `drift` + `drift_dev` | Banco local (ADR-003) |
| `go_router` | Navegação declarativa |
| `uuid` | Geração de UUID v4 no cliente (ADR-006) |
| `sqlite3` | Dependência **direta** usada por `test/drift/database_test.dart` (abre o SQLite nativo para inspecionar o banco); **não** remover (G-53) |
| `qr_flutter` | Geração do QR do código da lista (RF-33, F49) — puro Dart, offline, todas as plataformas |
| `mobile_scanner` | Leitura de QR por câmera (RF-33, F49) — Android/iOS; isolada por `plataformaComCamera()`; sem `INTERNET` |

---

## 2. Estrutura de pastas (feature-first)

```
lib/
├── main.dart
├── router.dart                      # go_router (rotas)
├── core/
│   ├── dominio/                     # shared kernel: Unidade, CategoriaItem, quantidade (F39)
│   ├── categorias/                  # dicionário + sugestão local de categoria
│   ├── importacao/                  # parser local de lista (F11)
│   ├── l10n/                        # strings (pt-BR) e política de privacidade
│   ├── navigation/                  # shell de navegação e voltar-ao-início
│   ├── texto/                       # normalização, busca e validação (F39)
│   ├── theme/                       # tema, tokens (Seção 7)
│   ├── utils/                       # utilitários de tempo
│   ├── web/                         # URL strategy (web/nativa)
│   └── widgets/                     # componentes compartilhados (App*)
├── features/
│   ├── compartilhamento/            # domain/ data/ providers/ ui/ (F49/RF-33)
│   ├── configuracoes/               # ui/ (inclui backup)
│   ├── design_system/               # ui/ (catálogo, só em debug)
│   ├── importacao/                  # ui/ (a lógica vive em core/importacao)
│   ├── listas/                      # domain/ data/ providers/ ui/
│   ├── onboarding/                  # providers/ ui/
│   ├── tour/                        # motor do tour guiado (F46)
│   └── voz/                         # domain/ data/ providers/ (F30)
└── drift/
    ├── database.dart                # AppDatabase (tabelas locais, schemaVersion 11)
    ├── conexao/                     # abrirBancoLocal (nativa/web, ADR-012)
    └── tables/                      # ListaLocal, ItemLocal, HistoricoPrecoLocal
```

**Regra:** `ui` só fala com `providers`; `providers` só falam com `data` (repositórios). Repositórios de leitura expõem **Streams do Drift** (UI reativa offline-first).

### 2.2. Forma dos módulos e barreiras locais

* **Shared kernel (`core/dominio/`):** o vocabulário fechado (`Unidade`, `CategoriaItem` e os
  helpers de `quantidade`) é compartilhado pela UI, pelos repositórios e pelo parser local (ADR-005/ADR-011,
  [13 §3](13-premodelo-tecnico.md)). Ele **não** pertence a uma feature: fica em `core/dominio/`, e
  `core/` nunca importa `features/` (F39).
* **Forma dos módulos:** o padrão é `domain/ data/ providers/ ui/`, mas nem todo módulo tem as
  quatro camadas — módulos sem entidade local (`configuracoes`, `importacao`, `design_system`) são
  só `ui/`, e `onboarding` não tem `domain/`/`data/`. O que é obrigatório é a direção da dependência:
  `ui → providers → data` (§2).
* **Barreiras locais no Drift:** o banco replica as regras dos dados (`itens_lista`: `quantidade > 0`
  e `quantidade <= 1000000`, `unidade`/`categoria` no enum, `preco_centavos` em faixa; `listas`:
  `orcamento_centavos` em faixa; índice único parcial `uq_item_ativo`). A migração **`schemaVersion 10 → 11`** (F48-T05)
  dropa a tabela `mutacao_pendente` (a antiga fila de sincronização, que deixou de existir) e ajusta a
  dedup de itens ativos para não referenciá-la (ordenação por `updated_at DESC, rowid DESC`). Os passos
  históricos (`de < 2 … de < 10`) permanecem para quem vem de versões antigas.
* **`quantidade` é `real` no Drift:** a precisão efetiva da app é ≤ 3 casas decimais (tolerância 0,001, [05 §6.3]).

### 2.1. Banco e plataformas (ADR-012)

O app roda em **Android, iOS, Web e Desktop (Windows/Linux/macOS)** a partir do mesmo código Flutter. As diferenças ficam confinadas a imports condicionais — nenhuma regra de negócio muda por plataforma.

* **Banco local — fábrica `abrirBancoLocal()`:** `lib/drift/database.dart` não importa `dart:io`; a conexão vem de `lib/drift/conexao/conexao.dart`, que exporta condicionalmente:
  * `conexao_nativa.dart` (nativo/desktop): `NativeDatabase` em arquivo no diretório de documentos (`lista_compras.sqlite`).
  * `conexao_web.dart` (navegador): `WasmDatabase.open` com `sqlite3.wasm` + `drift_worker.js`; persistência em **OPFS** quando disponível, **IndexedDB** como fallback. `LazyDatabase` mantém a inicialização fora do caminho de build da UI.
  * Offline-first: toda escrita vai apenas ao Drift; a UI nunca bloqueia.
* **Assets WASM no build web:** `web/sqlite3.wasm` e `web/drift_worker.js` são versionados no repositório (release `drift-2.34.4`) e precisam ser servidos junto do `build/web` — regeneração em [07 §3](07-qualidade-ci.md).
* **URL strategy:** `usarPathUrlStrategy()` (import condicional em `core/web/`) usa path limpo no web; no nativo/desktop é no-op.
* **Voz (RF-26, F30):** permissões de plataforma do microfone — Android `RECORD_AUDIO` (`android/app/src/main/AndroidManifest.xml`) e iOS `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` (`ios/Runner/Info.plist`). O botão de ditar só aparece em **Android/iOS**; Web/Desktop ocultam (§6.3).

### 2.3. App único (F48)

Há **um único app** (`main.dart` → `bootstrap()`), 100% local, com a identidade **"Minhas Listas"**: índigo `#4F46E5`, símbolo de cesta, escolhida por `IdentidadeVisual` para o tema, o `AppLogo` e o título do app. Não há conta, nuvem, colaboração, sync nem push — o dono de toda lista é a constante `idLocal = 'local'` e o backup é sempre local (`BackupRepository(donoLocal: true, enfileirar: false)`). Decisões em [superpowers/specs/2026-09-29-app-unico-lite-sem-supabase-design.md](superpowers/specs/2026-09-29-app-unico-lite-sem-supabase-design.md).

**Política de privacidade (RF-31/RF-32):** o app exibe a versão Lite (sem conta/nuvem, com voz e backup local); a página pública (`site/privacidade.html`, publicada via GitHub Pages) tem o mesmo texto ([06 §3.3.2](06-mvp-entregas.md)).

---

## 3. Providers Riverpod (por feature)

| Provider | Tipo | Responsabilidade |
| :--- | :--- | :--- |
| `appDatabaseProvider` | Provider | Instância única do Drift |
| `listasProvider` | StreamProvider | Listas ativas (Drift → UI) |
| `itensDaListaProvider(listaId)` | StreamProvider.family | Itens ativos; ordenação de exibição por categoria e `ordem` |
| `itensFrequentesProvider(listaId)` | StreamProvider.family | Ranking de sugestões de itens frequentes derivado do Drift (F22/RF-19): agrupa por nome normalizado, peso 2 para ocorrências na lista aberta e 1 para as demais, exclui os **pendentes** da lista aberta, limiar ≥ 2 e limite de 8 |
| `sugestaoCategoriasProvider` | Provider | Cadeia de sugestão local (RF-15) |
| `compartilhamentoRepositoryProvider` | Provider | `CompartilhamentoRepository` sobre o Drift: exportar/importar lista (F49/RF-33) |
| `leitorQrProvider` | Provider | Leitor de QR injetável (`LeitorQr`): real via `mobile_scanner`, fake nos testes (F49/RF-33) |

**Sugestão de categoria em camadas (ADR-011, spec §4)** — `SugestaoCategorias.sugerirCategoria(nome)`, zero rede:

1. **Memória por nome:** categoria do item ativo mais recente com o mesmo nome (qualquer lista **ativa** no dispositivo — itens de listas com `deletado_em` não entram; comparação sem acento/caixa; `updated_at` DESC).
2. **Dicionário estático** (`core/categorias/dicionario_categorias.dart`, ~230 termos pt-BR versionados no repo): casa quando **todas** as palavras do termo aparecem no nome; multi-palavra casa antes de palavra única ("leite condensado" → Mercearia antes de "leite" → Laticínios), empate por ordem alfabética.
3. **Fallback:** `outros`.

O dicionário não cobre produto incomum: cai em `outros` e passa a ser lembrado pela memória (a cadeia "aprende" pelo uso, sem tabela nova). Proteínas frescas (carne, frango, peixe, ovos) ficam em **Frios** por convenção do dicionário.

---

## 4. Rotas (go_router)

Rotas finais do app único (spec §3): sem `/login`, `/registro`, `/recuperar-senha`, `/redefinir-senha`, `/login-callback`, `/entrar`, `/compartilhadas` nem `/membros/:listaId`. Não há `redirect` global nem `RouterRefreshStream`.

| Rota | Tela | Observação |
| :--- | :--- | :--- |
| `/listas` | Minhas Listas (shell) | Aba inicial; todas as listas são locais |
| `/configuracoes` | Configurações (shell) | Aparência, categorias, backup, sobre, tutorial |
| `/lista/:listaId` | Tela da Lista (fora do shell) | Abre por `push` sobre o shell |
| `/mercado/:listaId` | Modo mercado (fora do shell) | Entrada pelo botão `shopping_cart_checkout` da AppBar da lista (F22/RF-18) |
| `/boas-vindas` | Boas-vindas (primeiro acesso — RF-27) | Aberta uma vez pela home |
| `/categorias` | Ordenar categorias (fora do shell) | RF-24 |
| `/receber-lista` | Receber lista (fora do shell) | `push` pela ação "Receber lista" do painel (RF-33/F49) |
| `/design` | Design System (só `kDebugMode`) | Público em debug |

* **Navegação por abas (F10):** `NavigationBar` inferior com **2 destinos** (**Minhas**, **Configurações**) que vira `NavigationRail` a partir de ~600dp; o `StatefulShellRoute.indexedStack` preserva o estado de cada aba e o AppBar de cada aba usa o mesmo texto do destino.
* **Abrir lista/mercado (`push` sobre o shell):** a tela cobre a barra (tela cheia) e o voltar retorna à **aba de origem**. Sem pilha, a seta e o voltar do sistema vão para `/listas` — helper `core/navigation/voltar_para_inicio.dart`.
* **Títulos:** painel segue o destino ("Minhas Listas"/"Configurações"); a tela da lista usa o título da lista (fallback "Lista" em carregando/erro/não encontrada). Título em **24sp bold** e, nas telas de topo, a **marca do app** (`AppLogo`, 28dp) à esquerda do texto (F13-T02/T03, doc [15 §1/§6](15-design-system.md)).
* Wireframes (layout) de todas as telas: **[10 Wireframes](10-wireframes-telas.md)**.

---

## 5. Fluxo de Navegação e UX

```
[ Painel "Minhas Listas" ] ───► (Criar nova lista / Selecionar existente)
          │
          ▼
[ Tela da Lista de Compras ]
          │
          ├───► [Entrada Manual Direta]:
          │     Digita o nome -> Ajusta quantidade -> Salva imediatamente
          │
          ├───► [Importação de lista (parser local)]:
          │     Clica em "Importar lista" -> Cola frase livre ->
          │     Abre Modal de Pré-visualização -> Confirma e insere na lista
          │
          └───► [Uso no Supermercado]:
                Marca/Desmarca checkboxes no modo mercado (100% local)
```

## 6. Especificação das telas

### 6.2. Painel "Minhas Listas"
* Lista de cards: título, contagem de itens pendentes/total, atualização relativa ("há 5 min"). A consulta do painel (`watchListasComContagem`/`ListaComContagem`) inclui `orcamento_centavos` da lista (G-43), exposto por `ListaComContagem.orcamentoCentavos`.
* Cabeçalho das telas de topo exibe a marca (`AppLogo`) à esquerda do título (F13-T02).
* FAB "Nova lista" → bottom sheet com campo de título. O título (novo ou renomeado) é limitado a **120 caracteres**, com limite aplicado no próprio campo e contador visível (F43-T11/G-50).
* **Ações do card:** botão `⋮` com renomear / excluir / comprar de novo / arquivar (com confirmação); o **long-press abre o mesmo menu** (F14-T06).
* Feedback: SnackBar curto "Lista criada" / "Lista renomeada" (F14-T05). As mensagens de exclusão usam **uma única** copy em `AppStrings` (`excluirListaTitulo`/`excluirListaMensagem(nItens)`).
* Estado vazio: ilustração simples + CTA de criação.
* Lista com `deletado_em` nunca aparece (tombstone invisível).
* **Busca (F16, RF-17):** a lupa na AppBar revela um campo no topo do corpo que filtra os cards pelo **título** (offline, sem acento/caixa); sem resultado → `AppEstadoVazio` "Nenhuma lista encontrada" (sem CTA); ✕ limpa e fecha; campo com rótulo acessível (label) e hint de exemplo.
* **Comprar de novo (RF-20, F23):** o menu `⋮` ganha o item "Comprar de novo" quando a lista tem itens **pendentes**; abre o sheet de título (com a contagem de pendentes, título pré-preenchido com o da origem, editável) e cria uma lista nova copiando os pendentes — nome/quantidade/unidade/categoria, na ordem original, todos pendentes — com o dono `idLocal`; a lista nova abre em seguida. Escrita só no Drift.
* **Arquivar listas (RF-22, F26):** botão "Mostrar arquivadas" na AppBar do painel (ícone `inventory_2_outlined`, estado efêmero, acessível) — por padrão as listas arquivadas (`arquivadaEm != null`) ficam **ocultas**; o menu `⋮` ganha "Arquivar" (lista ativa) ou "Desarquivar" (arquivada e visível), via `definirArquivada(...)` com SnackBar "Lista arquivada."/"Lista desarquivada."; o card arquivado exibe o chip "Arquivada" ([15](15-design-system.md)); a busca (RF-17) respeita o toggle.
* **Receber lista (RF-33, F49):** a AppBar do painel ganha a ação **"Receber lista"** (ícone `qr_code_scanner`, com `tooltip`), que abre `/receber-lista` por `push` — fluxo distinto do "Importar lista" (RF-16), que adiciona itens a uma lista existente (§6.4/§6.12).

### 6.3. Tela da Lista de Compras
| Elemento | Comportamento |
| :--- | :--- |
| Campo "Adicionar item" | Fixo no topo; Enter salva imediatamente (escrita no Drift) com a categoria sugerida pelas camadas locais (§3). **Reconhece quantidade/unidade no texto** (`1kg de banana` → Banana, 1 kg) via parser local (RF-16); sem unidade no texto, usa a **unidade escolhida no seletor** do campo (menu com o enum, padrão `un`) — F12-T06; texto que o parser descarta (ex.: só pontuação) → erro inline "Não entendi o item" (F14-T07); aceita **frações** na quantidade (`1/2`, `½`, `1½`) e o **misto separado** (`1 1/2`, combinado pelo parser) — RF-25/F29; em Android/iOS ganha um **microfone** que **preenche o campo** com o texto reconhecido **on-device** (pt-BR) — RF-26/F30 |
| Itens pendentes | **Agrupados por categoria** na **ordem salva** pelo usuário (fallback: ordem do enum — RF-24); header por grupo: `Frios (3)` com contagem de pendentes; grupos vazios não renderizam (RF-15) |
| Exibição | Ordenação determinística: `(categoria na ordem salva, ordem, id)` |
| Item | Nome, quantidade + unidade, checkbox |
| Checkbox marcada | Item move para seção dobrável "Itens Concluídos (n)" — **sem divisão por categoria** |
| Tocar no item | Abre o editor em **bottom sheet** (mesmo do swipe): nome, quantidade, unidade, categoria, **Preço (R$)** e ação **Remover** com undo (F12-T06/F25); a quantidade aceita decimal pt-BR (`1,5`), fração (`1/2`) e glifos (`½`, `1½`) via `parseQuantidade` — RF-25/F29 (o misto separado `1 1/2` é combinado pelo parser, não pelo editor); nome vazio/quantidade inválida/preço inválido geram erro inline no campo (F14-T07) |
| Swipe direita/esquerda | Editar / Remover (com undo via SnackBar); edição inclui **dropdown de categoria** ao lado das unidades; o dropdown mantém a **ordem do enum**, não a ordem custom (RF-24) |
| Botão de importação | Abre modal (6.4) |
| Menu (⋮) | Ordem renderizada: "Desmarcar todos", "Limpar concluídos", "Renomear lista", "Adicionar de outra lista", "Orçamento", "Compartilhar", "Arquivar/Desarquivar", "Excluir lista" |
| Ações em massa | Reaproveitar lista (desmarcar todos) e limpar concluídos — confirmação para destrutivas; "desmarcar" devolve o item ao seu grupo; **limpar concluídos tem undo** (SnackBar 3s, restaura `id`/`ordem` originais — F14-T05) |
| Chips de itens frequentes | Acima do campo "Adicionar item", em rolagem horizontal, quando o campo está **vazio** e há sugestões (`itensFrequentesProvider`, RF-19): toque adiciona o item com quantidade 1, unidade `un` e categoria pela cadeia local (§3); somem ao digitar o primeiro caractere e voltam ao limpar o campo |
| Botão do modo mercado | Ícone `shopping_cart_checkout` na AppBar (`tooltip` "Modo mercado"), **antes da lupa**; abre `/mercado/:listaId` via `push` (RF-18) |
| Faixa do total | Componente `TotalCarrinho` no **rodapé** da tela da lista e no **modo mercado** (§6.5): "No carrinho: R$ …" somando **itens marcados com preço**; se houver marcados sem preço, acrescenta "· N sem preço". Com **orçamento** (RF-28, F36): "No carrinho: R$ X de R$ Y" + barra de progresso; ao ultrapassar, alerta. Oculta quando não há nenhum item marcado (RF-21, F25) |

* **Reordenar:** drag-and-drop restrito **ao grupo da categoria** — reordena só os itens do grupo (grava `ordem`); mudar de categoria é pelo dropdown do editar. Exibição continua `(categoria na ordem salva, ordem, id)` — sem coluna nova. Falha de escrita ao reordenar exibe SnackBar genérico de erro, sem reordenar a exibição (F43-T11/G-47).
* **Quantidades e frações (RF-25, F29):** stepper + input direto; a **entrada rápida** e a **importação** aceitam decimal pt-BR (`1,5`), fração (`1/2`), glifos (`½`, `1½`) e **misto separado** (`1 1/2`, combinado pelo parser); o **editor** aceita os mesmos formatos **menos o misto separado** — lê a quantidade com `parseQuantidade`, que trata **um token único** (digitar `1 1/2` no editor gera erro inline). Unidades restritas ao enum (`lib/core/dominio/unidade.dart`). A exibição usa `formatarQuantidade` (`lib/core/dominio/quantidade.dart`): glifos comuns (`½ ¼ ¾ ⅓ ⅔`, mistos como `1½`, `1¼`) e, fora deles, arredonda para ≤ 3 casas (`1.2`, `0.143`).
* **Adicionar por voz (RF-26, F30):** o campo "Adicionar item" ganha um **microfone** (Android/iOS) que **preenche o campo** com o texto reconhecido **on-device** (pt-BR) via `ReconhecimentoVoz`/`reconhecimentoVozProvider`; o usuário confirma (Enter) e o parser local cuida do resto — a voz **não** adiciona item sozinha. O app **pede** on-device (`onDevice: true`) e nunca inicia chamada de rede própria, mas o `speech_to_text` **não expõe** forma de verificar/forçar, então no Android o **SO** pode usar o reconhecedor de rede quando não há modelo on-device (limitação do plugin/SO). Toque de novo para; ao sair da tela o ditado é cancelado; indisponível/permissão negada → SnackBar "Reconhecimento de voz indisponível neste aparelho."; Web/Desktop ocultam o botão.
* **Preço do item (RF-21, F25):** campo **"Preço (R$)"** opcional no editor; aceita `5,49`, `5.49`, `5`; vazio → sem preço (`null`); inválido/negativo → erro inline. Gravado em centavos (`preco_centavos`) via `editarItem(..., precoCentavos, limparPreco)`; `duplicarLista` copia o preço (RF-20).
* **Última compra (RF-29, F37):** quando há histórico local para o nome do item, o editor mostra uma linha **"Última compra: R$ X (dd/mm)"** abaixo do campo de preço; se o preço atual existir **e** a unidade atual for a mesma do registro, mostra também a **variação** — `↑ R$<diferença>`, `↓ R$<diferença>` ou "Mesmo preço"; com **unidade diferente** ou **sem preço atual**, exibe só a linha do último preço. O histórico (`HistoricoPrecoLocal`, Drift) é **local por dispositivo** — é gravado ao **marcar o item como comprado com preço** e nunca apagado ao desmarcar.
* **Faixa do total (RF-21, F25):** `TotalCarrinho` (`lib/features/listas/ui/total_carrinho.dart`, `Semantics` live region) deriva de `itensDaListaProvider` e mostra "No carrinho: R$ …" no rodapé da lista e no modo mercado; soma `round(quantidade × precoCentavos)` apenas de itens **marcados com preço**, com sufixo "· N sem preço" quando aplicável. Oculta sem marcados.
* **Orçamento na faixa do total (RF-28, F36):** quando `Lista.orcamentoCentavos` está definido (via `listaPorIdProvider`), `TotalCarrinho` passa a "No carrinho: R$ X de R$ **Y**" + `LinearProgressIndicator` (`total / Y`, limitado a 1); com `total > Y` o texto/progresso usam a **cor de erro**, um ícone de alerta e o rótulo "Acima do orçamento". `Y == 0` → qualquer total > 0 já está acima (sem barra). Sem orçamento, o comportamento é o do RF-21. Sem bloqueio de compra. `definirOrcamento` valida a faixa local `0..99999999` centavos e lança `ArgumentError` fora dela (F43-T11/G-49).
* Item duplicado (mesmo nome ativo, comparação normalizada): **mesma unidade → soma** a quantidade; **unidade diferente → atualiza** o item para a nova quantidade/unidade — nunca duplica o nome ativo (índice único parcial).
* **Rótulo do campo de nome (F14-T06):** no editor, o campo usa "Nome do item" — "Adicionar item" vale só para a entrada rápida.
* **Erro e vazio (F14-T04):** falha de carga usa `AppEstadoErro` **com retry**; "Lista não encontrada" ganha CTA para `/listas`.
* **Vazio da lista explicativo (RF-27, F31):** a lista sem itens não diz só "vazio" — a dica aponta os caminhos existentes: `Adicione no campo acima ou importe uma lista.` (adicionar no campo ou botão "Importar lista" no rodapé; a copy fica só em `AppStrings` e não cita voz, pois o microfone só existe onde `plataformaComVoz()` é verdadeiro).
* **Busca (F16, RF-17):** a lupa na AppBar revela um campo que filtra os itens pelo **nome** (offline, sem acento/caixa); mantém os grupos de categoria (escondendo vazios) e a seção de concluídos (contagens filtradas); **drag desabilitado** enquanto filtra; ao **adicionar** um item a busca é limpa; sem resultado → `AppEstadoVazio` "Nenhum item encontrado" com "Limpar busca"; campo com rótulo acessível (label) e hint de exemplo.
* **Adicionar de outra lista (RF-23, F27):** item no menu `⋮` abre o modal "Adicionar de outra lista" — seletor da lista de origem (todas as listas menos a atual; arquivadas rotuladas "Arquivada") e os **pendentes** da origem em multi-seleção com "Selecionar todos"; a ação "Adicionar" (estática; desabilitada com 0 selecionados) insere com a **dedup do app** (`adicionarItensDedup`, soma/replace) e a tela mostra um SnackBar com a contagem (`AppStrings.itensAdicionadosDeOutra`); **preço não é copiado**. Tudo local no Drift.

### 6.4. Modal "Importar lista" (RF-16)

Um único modal de importação local (offline, RF-16):

1. Textarea + contador de caracteres (≤ 10.000 — [04 §2](04-importacao-lista.md)).
2. Botão "Extrair itens": parser local puro (`lib/core/importacao/parser_lista_local.dart`), sem rede; categoria pela cadeia local (memória → dicionário → `outros`, [§3](05-app-flutter.md)); disponível offline.
3. **Modal de pré-visualização:** checkboxes para incluir/excluir cada item; edição inline de nome/quantidade/unidade/**categoria** (dropdown com o enum), com erro inline de nome/quantidade (F14-T07); `aviso` exibido como nota.
4. "Adicionar N itens à lista" → grava localmente no Drift.
5. Erros do parser exibidos com as mensagens amigáveis do contrato ([04 §2](04-importacao-lista.md)); falha genérica (ex.: Drift) também é capturada, mostra mensagem amigável e **sempre** libera o botão `_carregando` (F43-T11/G-52).

### 6.5. Modo mercado (RF-18)

Tela dedicada `/mercado/:listaId` para usar o celular no mercado, sem a densidade da tela da lista (wireframe [10 §3.3](10-wireframes-telas.md)):

* **AppBar** com título da lista e seta de voltar (sem menu).
* **Contador** `mercadoProgresso(marcados, total)` (ex.: "3 de 12"): marcados **nesta sessão** / total de itens ativos; é uma live region.
* **Faixa do total (RF-21):** `TotalCarrinho` logo abaixo do contador — "No carrinho: R$ …" dos itens marcados com preço (§6.3); com orçamento (RF-28), "de R$ Y" + progresso + alerta ao ultrapassar; oculta sem marcados.
* **Pendentes** em lista de altura generosa, com checkbox de alvo ≥48dp e toque na linha para marcar (`editarItem(concluido: true)`). **Sem** grupos de categoria, busca, drag, swipe, menu ou importação. Se a gravação falhar, a marcação da sessão é revertida e um SnackBar genérico de erro aparece (F43-T11/G-47).
* **Faixa "Marcados (n)"** recolhível no rodapé — é o undo do toque acidental: ao marcar, o item sai da área principal e entra na faixa, que abre automaticamente na primeira marcação da sessão; tocar num item da faixa desmarca e o devolve aos pendentes.
* **Estados:** carregando (`AppEsqueleto`), erro (`AppEstadoErro` com retry em `itensDaListaProvider`), lista não encontrada e "tudo comprado" (0 pendentes) com CTA para voltar.

### 6.7. Configurações — Aparência e Ordenar categorias (RF-24)

* **Aparência:** seletor de tema Claro/Escuro/Sistema (`SeletorTema`, doc [15 §2](15-design-system.md)).
* **Ordenar categorias (RF-24, F28):** item abaixo do seletor abre `/categorias` (fora do shell), a `TelaOrdenarCategorias` — lista arrastável das 11 categorias com ação **"Restaurar padrão"** (volta à ordem do enum, com confirmação). A preferência é **global** e **local** (SharedPreferences, chave `ordem_categorias`, como o tema). Detalhe em [10 §5.1](10-wireframes-telas.md).
* **Backup:** exportar/importar JSON local (§6.10).
* **Sobre:** política de privacidade, versão, "Ver tutorial".

### 6.8. Tela de boas-vindas (RF-27, F31)

Primeiro acesso ao app — apresenta o valor em **uma** página (rolável, escala de fonte respeitada, RNF-06) e sai de cena depois:

* **Rota:** `/boas-vindas` (top-level; não está na lista de rotas públicas). O guard fica na home (`MinhasListasScreen`): quando `onboardingVistoProvider` resolve **falso**, faz `context.push('/boas-vindas')` **uma única vez**; não mexe no `redirect` do `go_router`.
* **Flag local (F31-T01):** `onboardingVistoProvider` (`AsyncNotifierProvider<OnboardingNotifier, bool>`) lê/grava `SharedPreferences` (chave `onboarding_visto`), como o tema — sem rede/Drift/schema. `marcarVisto()` grava e nunca mais reabre.
* **Conteúdo:** marca (`AppLogo`) + título (`boasVindasTitulo`) e subtítulo; destaques com ícone (offline, importar por texto, ditar um item) e o botão **"Começar"** (`AppBotao`) → `marcarVisto()` + `context.go('/listas')`. Sem "Pular" (página única). O destaque **"Dite um item"** só aparece quando `plataformaComVoz()` é verdadeiro (Android/iOS); em Web/Desktop ficam os outros destaques. Wireframe em [10 §1.1](10-wireframes-telas.md).
* **Saída da tela:** a tela é dispensada/confirmada **apenas pelo "Começar"** (único caminho que grava `onboarding_visto` e vai para `/listas`). O **voltar do sistema Android** (`Navigator.pop`) retorna ao painel de listas **sem** marcar como visto — a flag continua falsa, então a tela **reabre no próximo cold start**.

### 6.10. Backup local (RF-31)

Em Configurações → "Backup": **Exportar backup** gera um `.json` (versão + listas + itens + histórico de preços)
e **Importar backup** restaura com merge por `id` e LWW por `updated_at` (comparação de timestamps local).

O export é **fiel ao banco**: inclui listas e itens com `deletado_em` preenchido (soft delete), para que
a restauração nunca encontre item órfão de lista e viole a FK. A UI separa **arquivo inválido**
(`BackupInvalidoException` → `AppStrings.backupInvalido`) de **falha ao restaurar**
(`BackupRestauracaoException`, ex.: FK/CHECK → `AppStrings.backupRestauracaoErro`).

> A importação é **somente local** (grava no Drift); o histórico de preços não é propagado (não há sync).

### 6.11. Tour guiado do primeiro uso (RF-27, F46)

Motor próprio em `lib/features/tour/` (sem dependência nova): `tour_step.dart`/`tour_keys.dart`/`tour_roteiro.dart`/`tour_controller.dart` + `ui/tour_overlay.dart` e `ui/tour_loader.dart`. O overlay vive na **raiz** (`MaterialApp.router.builder` em `app.dart`) — não dentro do `Scaffold.body` — porque o `Spotlight` lê coordenadas globais (`localToGlobal`); ancorado no corpo, o recorte desalinharia pela AppBar/safe area. Spec: [2026-09-28-tour-guiado-primeiro-uso-design.md](superpowers/specs/2026-09-28-tour-guiado-primeiro-uso-design.md).

* **Duas etapas:** a **etapa 1** (3 passos, na home de listas — criar lista, busca e configurações) começa **após as boas-vindas**; a **etapa 2** (8 passos, na tela da lista — nome, adicionar item, unidade, importar, marcar/editar, modo mercado, orçamento no menu `⋮` e convite) dispara ao abrir a **primeira lista com itens pendentes**. No app único, o passo de convite é pulado.
* **Alvo visível é pré-requisito:** `TourController.iniciar` só enfileira passos cujo alvo está **de fato visível** — rejeita `Offstage`/`Visibility` invisível, tamanho zero ou fora da tela (no `IndexedStack` do shell as abas ocultas seguem montadas). Assim, passos cujo alvo não está montado na tela corrente (ex.: o sheet de nome, que precisa estar aberto) são pulados; se nenhum passo sobra, a etapa não inicia.
* **Flags:** `tour_etapa1_visto` e `tour_etapa2_visto` (`SharedPreferences`, `TourVistoNotifier`, espelho do onboarding). `Pular` e `Concluir` (no último passo) marcam a etapa vista; `Pular` na etapa 1 **não** impede a etapa 2.
* **Gatilhos:** `TourLoader(etapa: primeira)` na `MinhasListasScreen` (após `onboardingVistoProvider` resolver) e `TourLoader(etapa: recursos)` na tela da lista; cada loader inicia a etapa **uma vez**, só se a flag respectiva ainda for falsa.
* **Reabrir:** Configurações → **"Ver tutorial"** (`AppStrings.tourAbrir`) ignora as flags e **navega para a home de listas** (`/listas`), onde inicia a etapa 1 (os alvos da etapa 2 vivem na tela da lista). A etapa 2 segue o fluxo normal e **volta a disparar sozinha** ao abrir uma lista com itens pendentes **enquanto a flag dela ainda for falsa**; não há como rodá-la de dentro de Configurações. Não reescreve de forma destrutiva a conclusão já registrada.
* **Interação e acessibilidade (RNF-06):** spotlight sobre o alvo + bolha (abaixo, com fallback acima/centro) com indicador `n/total` e botões `Pular`/`Anterior`/`Próximo` (vira `Concluir` no último). O overlay **não bloqueia** os toques fora da bolha — avança só pelos botões; a bolha é live region anunciada **"Passo n de m"** e a transição respeita `disableAnimations`. Layout e spots em [10 §2/§3/§5](10-wireframes-telas.md); tokens em [15 §3](15-design-system.md).

### 6.12. Compartilhar lista (RF-33, F49)

Enviar e receber **uma lista específica** sem nuvem — texto, arquivo `.json` ou QR/código — sempre **100% offline** (spec: [2026-09-30-compartilhar-lista-design.md](superpowers/specs/2026-09-30-compartilhar-lista-design.md)). É distinto do backup (RF-31, banco inteiro) e do "Importar lista" (RF-16, adiciona itens a uma lista existente). Wireframes em [10 §7](10-wireframes-telas.md).

* **Arquivos:** `lib/features/compartilhamento/` — `domain/lista_compartilhada.dart` (modelo `ListaCompartilhada`/`ItemCompartilhado` + `CompartilhamentoInvalidoException`), `domain/codec_lista.dart` (`codificarLista`/`decodificarLista`/`gerarTextoLista`), `domain/leitor_qr.dart` (contrato `LeitorQr`), `data/compartilhamento_repository.dart` (`exportarLista`/`importarLista`), `data/leitor_qr_plugin.dart` (impl. `mobile_scanner`), `providers/compartilhamento_providers.dart`, `ui/sheet_compartilhar.dart`, `ui/receber_lista_screen.dart`, `ui/modal_previsao_receber.dart` e `ui/tela_escanear_qr.dart`.
* **Enviar:** menu `⋮` da tela da lista (§6.3) → **"Compartilhar"** → bottom sheet (`AppSheet`) com **"Enviar como texto"** (`share_plus`), **"Enviar arquivo"** (`.json` via `XFile.fromData`, `application/json`) e **"QR code"** (`qr_flutter`), que abre um sheet com o QR + **"Copiar código"** (área de transferência). Indisponibilidade do share → SnackBar dedicada; demais falhas → genérica. O QR só é exibido se o código couber em `limiteCodigoBytes = 2000`; acima disso o QR é bloqueado com aviso ("Lista grande - use texto ou arquivo.") e texto/arquivo seguem disponíveis.
* **Formato do código:** `ML1:` + `base64Url(utf8(json))`, com JSON `{"tipo":"minhas-listas/lista","versao":1,"titulo":...,"itens":[...]}` (cada item: `nome`, `quantidade`, `unidade`, `categoria`, `concluido`, `ordem`, `preco_centavos`). O **texto legível** é uma linha por item (`"<quantidade> <unidade> <nome>"`) e **reusa o parser local** (RF-16, §6.4, [04 §2](04-importacao-lista.md)); sem título nem preço.
* **Receber:** rota `/receber-lista` (fora do shell), acionada pela ação **"Receber lista"** do painel (§6.2). Campo único que **auto-detecta** `ML1:` (código), `{` (JSON de arquivo) ou **texto livre** (parser RF-16 + sugestão de categoria da cadeia local, §3); botão **"Escolher arquivo"** (`file_selector`; arquivo ilegível → erro tratado) e botão **"Escanear QR"** (só onde `plataformaComCamera()`, via `leitorQrProvider`). O botão **"Continuar"** abre a **pré-visualização editável** (`modal_previsao_receber.dart`): **título editável** (no texto livre o padrão é `listaCompartilhada`; no código/arquivo vem do payload) e **lista de itens com incluir/excluir** (todos marcados por padrão; mesmo padrão do `ModalPrevisaoImportacao`); o confirmar **"Criar lista"** fica desabilitado com título vazio ou nenhum item incluído. Erro de entrada → Banner "Código ou arquivo inválido."; falha inesperada → genérica.
* **Sempre cria lista nova:** `importarLista` gera **UUIDs v4 novos** para a lista e para cada item numa **transação** (dono `idLocal`), preservando quantidade/unidade/categoria/`concluido`/`ordem`/preço — **nunca** mescla com listas existentes. Título = o confirmado na pré-visualização (payload no código/arquivo; `listaCompartilhada` como padrão no texto livre, sempre editável). Confirmar na prévia ("Criar lista") navega para `/lista/<novoId>`; cancelar (na tela ou na prévia) não grava.
* **Câmera:** permissões nativas `CAMERA` (Android) e `NSCameraUsageDescription` (iOS); dependências `qr_flutter` (exibir o QR em todas as plataformas) e `mobile_scanner` (ler só Android/iOS, atrás do contrato injetável `LeitorQr`; Web/Desktop colam código/texto/arquivo). Sem `INTERNET` — operação offline; detalhes em [09 §2.11](09-runbook-operacoes.md).

---

## 7. Design System

O design system (tokens, tipografia, componentes, motion, acessibilidade) é
propriedade do **[doc 15](15-design-system.md)**. Resumo: Material 3 Expressive
com seed índigo do Lite, claro/escuro com paridade, modo Claro/Escuro/Sistema e fonte
Plus Jakarta Sans bundlada. Aqui ficam apenas os estados transversais:

| Estado | Componente padrão (doc 15) |
| :--- | :--- |
| Carregando | `AppBotao(carregando: true)` / `CircularProgressIndicator` |
| Carregando (listas) | `AppEsqueleto` — placeholder estático (F14-T09) |
| Vazio | `AppEstadoVazio` |
| Erro | `AppEstadoErro` (com retry) |

* **Acessibilidade (RNF-06):** semântica/live region, alvos ≥48dp e escala de texto — regras e verificação por teste em [15 §4](15-design-system.md) (F14-T01/T02).
* i18n: pt-BR — strings centralizadas em `core/l10n/app_strings.dart` e **Material localizado** via `flutter_localizations` (`app.dart` com `Locale('pt','BR')`, `supportedLocales` e delegados `GlobalMaterial/Widgets/Cupertino`, F43-T09). String de UI fora do `AppStrings` é considerada bug (F14-T08).

---

## 8. Checklist de validação

- [ ] App abre direto em `/listas`, sem rotas de conta (`/login` etc. ausentes).
- [ ] CRUD manual funciona 100% local (modo avião) e persiste após reiniciar.
- [ ] Checkbox concluída move item para seção dobrável; "Desmarcar todos" reaproveita lista.
- [ ] Importação de lista: pré-visualização editável; cancelar não grava nada.
- [ ] Tema escuro aplicado em todas as telas (sem tela esquecida).
- [ ] Estados vazio/erro/carregando implementados em todas as telas.
- [ ] Acessibilidade (RNF-06): semântica/live region, alvos ≥48dp e escala de texto verificados por teste ([15 §4](15-design-system.md)).
- [ ] Backup exportar/importar funcionando (inclusive lista soft-deletada).
- [ ] Compartilhar/receber lista 100% offline (texto/arquivo/QR) sempre criando uma lista nova (RF-33).
- [ ] Widget tests das telas críticas ([07](07-qualidade-ci.md)).

---

## Documentos relacionados
- [04 Importação](04-importacao-lista.md) — contrato do parser local consumido pelo modal de importação
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios de aceite destas telas
- [10 Wireframes](10-wireframes-telas.md) — layout de cada tela
