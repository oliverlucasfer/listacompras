# 05 — App Flutter (Arquitetura, Telas, UX e Design)

> Navegação: [← 04 Importação](04-importacao-lista.md) · [06 MVP & Entregas →](06-mvp-entregas.md)

**Este documento é o dono da arquitetura do app, da navegação/UX e do design system.** Regras de negócio de sync moram em [03](03-sincronizacao-offline.md); schema em [01](01-banco-de-dados.md).

---

## 1. Pacotes principais

| Pacote | Uso |
| :--- | :--- |
| `flutter_riverpod` / `riverpod_annotation` | State management (ADR-002) |
| `drift` + `drift_dev` | Banco local (ADR-003) |
| `supabase_flutter` | Auth, PostgREST, Realtime, Functions |
| `go_router` | Navegação declarativa + deep links |
| `connectivity_plus` | Detecção online/offline |
| `uuid` | Geração de UUID v4 no cliente (ADR-006) |
| `sentry_flutter` | Observabilidade ([07](07-qualidade-ci.md)) |

---

## 2. Estrutura de pastas (feature-first)

```
lib/
├── main.dart
├── router.dart                      # go_router (rotas, guards de auth)
├── core/
│   ├── config/                      # links por plataforma (ADR-012)
│   ├── rede/                        # tratamento de erro de rede (nativo/web)
│   ├── web/                         # URL strategy (web/nativa)
│   ├── theme/                       # tema, tokens (Seção 7)
│   ├── widgets/                     # componentes compartilhados
│   └── utils/                       # formatação, extensões
├── features/
│   ├── auth/
│   │   ├── data/                    # SupabaseAuthRepository
│   │   ├── providers/               # authStateProvider
│   │   └── ui/                      # Login, Registro, RecuperarSenha
│   ├── listas/
│   │   ├── data/                    # ListasRepository (Drift + Supabase)
│   │   ├── domain/                  # modelos Lista, Item; enums Unidade, CategoriaItem
│   │   ├── providers/               # listasProvider, itensProvider(consulta)
│   │   └── ui/                      # MinhasListas, TelaLista, modais
│   └── sync/
│       ├── data/                    # SyncEngine, fila (Drift)
│       └── providers/               # syncStatusProvider
└── drift/
    ├── database.dart                # AppDatabase (tabelas locais)
    ├── conexao/                     # abrirBancoLocal (nativa/web, ADR-012)
    └── tables/                      # ListaLocal, ItemLocal, MutacaoPendente
```

**Regra:** `ui` só fala com `providers`; `providers` só falam com `data` (repositórios). Repositórios de leitura expõem **Streams do Drift** (UI reativa offline-first).

### 2.1. Banco e links por plataforma (ADR-012)

A partir da Fase 18 o app roda em **Android, iOS, Web e Desktop (Windows/Linux/macOS)** a partir do mesmo código Flutter. As diferenças ficam confinadas a imports condicionais — nenhuma regra de negócio muda por plataforma.

* **Banco local — fábrica `abrirBancoLocal()`:** `lib/drift/database.dart` não importa mais `dart:io`; a conexão vem de `lib/drift/conexao/conexao.dart`, que exporta condicionalmente:
  * `conexao_nativa.dart` (nativo/desktop): `NativeDatabase` em arquivo no diretório de documentos (`lista_compras.sqlite`).
  * `conexao_web.dart` (navegador): `WasmDatabase.open` com `sqlite3.wasm` + `drift_worker.js`; persistência em **OPFS** quando disponível, **IndexedDB** como fallback. `LazyDatabase` mantém a inicialização fora do caminho de build da UI.
  * Offline-first inalterado: toda escrita vai ao Drift + fila ([03](03-sincronizacao-offline.md)); a UI nunca bloqueia em rede.
* **Assets WASM no build web:** `web/sqlite3.wasm` e `web/drift_worker.js` são versionados no repositório (release `drift-2.34.4`) e precisam ser servidos junto do `build/web` — regeneração em [07 §3](07-qualidade-ci.md).
* **URL strategy:** `usarPathUrlStrategy()` (import condicional em `core/web/`) usa path limpo no web (`/entrar?token=…`, `/login-callback`); no nativo/desktop é no-op. Chamada em `main.dart` antes do `Supabase.initialize`.
* **Links (`core/config/links.dart`):**
  * **Origem:** `origemWeb()` devolve `Uri.base.origin` no web e a constante `APP_WEB_URL` (`--dart-define=APP_WEB_URL=https://<domínio>`, default `http://localhost:8080`) no nativo.
  * **Auth:** `redirectAuth()` devolve `<origem>/login-callback` no web (http em dev, https em produção) e `br.com.oliverlucas.listacompras://login-callback` no nativo — usado no cadastro (verificação de e-mail) e na recuperação de senha.
  * **Convite:** `linkConviteDe(token)` devolve `https://<origem>/entrar?token=…` no web e `br.com.oliverlucas.listacompras://entrar?token=…` no nativo ([08 §1.1](08-compartilhamento-colaborativo.md)).
  * No web o deep link de convite chega como URL normal ao `go_router`; a ponte `deeplinkConviteProvider` só escuta o `app_links` no nativo.
* **Rota `/login-callback`:** rota pública que exibe um indicador de progresso enquanto o `supabase_flutter` processa o retorno do link (o redirect seguinte decide a tela). Registrada no `router.dart` para o web, onde o retorno do Supabase é uma URL https e não um deep link.
* **Erros de rede:** `core/rede/erro_rede.dart` exporta por plataforma `erro_rede_nativa.dart` (`SocketException`/`TimeoutException`) e `erro_rede_web.dart` (`ClientException`), mantendo o mapeamento para "sem conexão" único para a UI.
* **Voz (RF-26, F30):** permissões de plataforma do microfone — Android `RECORD_AUDIO` (`android/app/src/main/AndroidManifest.xml`; `INTERNET` já existe) e iOS `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` (`ios/Runner/Info.plist`). O botão de ditar só aparece em **Android/iOS**; Web/Desktop ocultam (§6.3).

---

## 3. Providers Riverpod (por feature)

| Provider | Tipo | Responsabilidade |
| :--- | :--- | :--- |
| `authStateProvider` | StreamProvider | Sessão atual (login/logout/refresh) |
| `appDatabaseProvider` | Provider | Instância única do Drift |
| `listasProvider` | StreamProvider | Listas ativas do usuário (Drift → UI) |
| `itensDaListaProvider(listaId)` | StreamProvider.family | Itens ativos; ordenação de exibição por categoria e `ordem` (Fase 6) |
| `itensFrequentesProvider(listaId)` | StreamProvider.family | Ranking de sugestões de itens frequentes derivado do Drift (F22/RF-19): agrupa por nome normalizado, peso 2 para ocorrências na lista aberta e 1 para as demais, exclui os **pendentes** da lista aberta, limiar ≥ 2 e limite de 8 |
| `syncStatusProvider` | StreamProvider | Estado de sync ([03 §6](03-sincronizacao-offline.md)) |
| `conectividadeProvider` | StreamProvider | Online/offline (dispara flush) |
| `sugestaoCategoriasProvider` | Provider | Cadeia de sugestão local (Fase 6/RF-15) |
| `redefinindoSenhaProvider` | NotifierProvider (bool) | true no evento `passwordRecovery`: força o redirect a `/redefinir-senha` até `concluir()` (F14-T03) — assinado antes do refresh do router (ordem de listeners) |

**Sugestão de categoria em camadas (Fase 6, ADR-011, spec §4)** — `SugestaoCategorias.sugerirCategoria(nome)`, zero rede:

1. **Memória por nome:** categoria do item ativo mais recente com o mesmo nome (qualquer lista do usuário no dispositivo; comparação sem acento/caixa; `updated_at` DESC).
2. **Dicionário estático** (`core/categorias/dicionario_categorias.dart`, ~230 termos pt-BR versionados no repo): casa quando **todas** as palavras do termo aparecem no nome; multi-palavra casa antes de palavra única ("leite condensado" → Mercearia antes de "leite" → Laticínios), empate por ordem alfabética.
3. **Fallback:** `outros`.

O dicionário não cobre produto incomum: cai em `outros` e passa a ser lembrado pela memória (a cadeia "aprende" pelo uso, sem tabela nova). Proteínas frescas (carne, frango, peixe, ovos) ficam em **Frios** por convenção do dicionário.

---

## 4. Rotas (go_router)

| Rota | Tela | Guard |
| :--- | :--- | :--- |
| `/login` | Login (aceita `?next=` para voltar ao fluxo pós-login, ex. `/entrar?token=...`) | redirect se autenticado → `/listas` |
| `/registro` | Registro (propaga `?next=` para o login na tela "Verifique seu e-mail") | idem |
| `/recuperar-senha` | Recuperação de senha | público |
| `/redefinir-senha` | Definir nova senha (destino do link de recuperação) | público (mesmo autenticado — exceção como `/entrar`) |
| `/entrar` | Aceite de convite (doc [08 §3](08-compartilhamento-colaborativo.md)): lê `?token=`; sem sessão mostra contexto e vai ao login/registro com `?next=`; com sessão aceita (RPC idempotente) e navega à lista | público |
| `/listas` | Minhas Listas (shell) — listas em que o usuário é dono | exige autenticação |
| `/compartilhadas` | Compartilhadas (shell) — listas em que participa (não dono); AppBar "Entrar com código" (`person_add`): colar token → aceite → navega à lista | exige autenticação |
| `/configuracoes` | Configurações (shell) — aparência, conta, logout, excluir conta | exige autenticação |
| `/lista/:listaId` | Tela da Lista (fora do shell) | exige autenticação + pertencimento |
| `/mercado/:listaId` | Modo mercado (fora do shell) — entrada pelo botão `shopping_cart_checkout` da AppBar da lista, visível só a dono/editor (F22/RF-18) | exige autenticação + pertencimento |
| `/membros/:listaId` | Membros da lista (fora do shell) | exige autenticação + pertencimento |
| `/design` | Design System (só `kDebugMode`) | público em debug |

* **Navegação por abas (F10):** `NavigationBar` inferior com 3 destinos (**Minhas**, **Compartilhadas**, **Configurações**) que vira `NavigationRail` a partir de ~600dp; o `StatefulShellRoute.indexedStack` preserva o estado de cada aba e o AppBar de cada aba usa o mesmo texto do destino.
* **Abrir lista/membros (`push` sobre o shell):** a tela cobre a barra (tela cheia) e o voltar retorna à **aba de origem**. Sem pilha (deep link/aceite de convite), a seta e o voltar do sistema vão para `/listas` (dono) ou `/compartilhadas` (membro) — helper `core/navigation/voltar_para_inicio.dart`.
* **Títulos:** painel segue o destino ("Minhas Listas"/"Compartilhadas"/"Configurações"); a tela da lista usa o título da lista (fallback "Lista" em carregando/erro/não encontrada); membros usa `Membros · {título}`. Título em **24sp bold** e, nas telas de topo, a **marca do app** (`AppLogo`, 28dp) à esquerda do texto (F13-T02/T03, doc [15 §1/§6](15-design-system.md)).
* **Redirect global:** não autenticado → `/login`; autenticado em rota pública → `/listas`, **exceto `/entrar`** (permanece pública — a tela decide) **e `/redefinir-senha`** (o link de recuperação autentica o usuário, mas ele ainda precisa definir a senha).
* **Recuperação de senha (F14-T03):** o link do Supabase volta pelo `deepLink` `...://login-callback` (o mesmo do cadastro). O app reage a `AuthChangeEvent.passwordRecovery`, marca a sessão como "redefinindo senha" e o `redirect` leva a `/redefinir-senha`; o sucesso limpa a marca e volta a `/listas`. Link expirado → erro amigável com "Pedir novo link".
* Deep link de convite (`br.com.oliverlucas.listacompras://entrar?token=...`, intent-filter com host `entrar`): o supabase_flutter escuta os deep links via app_links mas só consome os que têm parâmetros de auth; links de convite são traduzidos para `/entrar?token=...` pela ponte `deeplinkConviteProvider` ([08 §1.1](08-compartilhamento-colaborativo.md)).
* Wireframes (layout) de todas as telas: **[10 Wireframes](10-wireframes-telas.md)**.

---

## 5. Fluxo de Navegação e UX

```
[ Tela de Autenticação ]
          │
          ▼
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
                Marca/Desmarca checkboxes com sincronização em tempo real
```

## 6. Especificação das telas

### 6.1. Tela de Autenticação
* E-mail + senha; botões: Entrar, Criar conta, Recuperar senha.
* Provedores sociais (Google) — estrutura pronta, ativação opcional na Fase 5.
* **Recuperação de senha e verificação de e-mail** obrigatórias no MVP (Fase 3).
* **Nova senha (F14-T03):** o link de recuperação abre `/redefinir-senha` (nova senha + confirmação, ambas com toggle; mínimo de 6 e igualdade); sucesso → SnackBar "Senha alterada" + `/listas`; link expirado → erro amigável com CTA "Pedir novo link".
* **Registro:** os dois campos de senha ganham toggle de mostrar/ocultar (paridade com o login; F14-T07) e "Reenviar link" passa a dar retorno (SnackBar) e a desabilitar durante o envio (F14-T05).
* Estados: carregando (spinner no botão), erro (mensagem inline amigável).

### 6.2. Painel "Minhas Listas"
* Lista de cards: título, contagem de itens pendentes/total, atualização relativa ("há 5 min").
* Cabeçalho das telas de topo exibe a marca (`AppLogo`) à esquerda do título (F13-T02).
* FAB "Nova lista" → bottom sheet com campo de título.
* **Ações do card:** botão `⋮` com renomear / excluir (com confirmação) — nas Compartilhadas, membros / sair da lista; o **long-press abre o mesmo menu** (atalho, não mais o único caminho) (F14-T06).
* Feedback: SnackBar curto "Lista criada" / "Lista renomeada" (F14-T05). As mensagens de exclusão usam **uma única** copy em `AppStrings` (`excluirListaTitulo`/`excluirListaMensagem(nItens, {temMembros})`: o trecho "para todos os participantes" aparece quando há membros conhecidos). A tela da lista consulta `membrosDaListaProvider` em best-effort (sem fetch extra; usa o que já estiver em cache) e o painel assume lista sem membros — F14-T08, [10 §3.4](10-wireframes-telas.md).
* Estado vazio: ilustração simples + CTA de criação.
* Lista com `deletado_em` nunca aparece (tombstone invisível).
* **Busca (F16, RF-17):** a lupa na AppBar revela um campo no topo do corpo que filtra os cards pelo **título** (offline, sem acento/caixa); sem resultado → `AppEstadoVazio` "Nenhuma lista encontrada" (sem CTA); ✕ limpa e fecha; campo com rótulo acessível (label) e hint de exemplo.
* **Comprar de novo (RF-20, F23):** o menu `⋮` — dono **e** membro — ganha o item "Comprar de novo" quando a lista tem itens **pendentes**; abre o sheet de título (com a contagem de pendentes, título pré-preenchido com o da origem, editável) e cria uma lista nova copiando os pendentes — nome/quantidade/unidade/categoria, na ordem original, todos pendentes — com o usuário atual como dono; a lista nova abre em seguida. Escrita local + fila, sem rede (doc 03).
* **Arquivar listas (RF-22, F26):** botão "Mostrar arquivadas" na AppBar do painel (ícone `inventory_2_outlined`, estado efêmero, acessível) — por padrão as listas arquivadas (`arquivadaEm != null`, [01 §4.1](01-banco-de-dados.md)) ficam **ocultas**, tanto em **Minhas** quanto em **Compartilhadas**; o menu `⋮` do **dono** ganha "Arquivar" (lista ativa) ou "Desarquivar" (arquivada e visível), via `definirArquivada(...)` com SnackBar "Lista arquivada."/"Lista desarquivada."; o card arquivado exibe o chip "Arquivada" ([15](15-design-system.md)); a busca (RF-17) respeita o toggle. A ação **não** aparece para membro/`leitor`.

### 6.3. Tela da Lista de Compras
| Elemento | Comportamento |
| :--- | :--- |
| Campo "Adicionar item" | Fixo no topo; Enter salva imediatamente (escrita local + fila) com a categoria sugerida pelas camadas locais (§3, Fase 6). **Reconhece quantidade/unidade no texto** (`1kg de banana` → Banana, 1 kg) via parser local (RF-16); sem unidade no texto, usa a **unidade escolhida no seletor** do campo (menu com o enum, padrão `un`) — F12-T06; texto que o parser descarta (ex.: só pontuação) → erro inline "Não entendi o item" (F14-T07); aceita **frações** na quantidade (`1/2`, `½`, `1½`) e o **misto separado** (`1 1/2`, combinado pelo parser) — RF-25/F29; em Android/iOS (dono/editor) ganha um **microfone** que **preenche o campo** com o texto reconhecido **on-device** (pt-BR) — RF-26/F30 |
| Itens pendentes | **Agrupados por categoria** na **ordem salva** pelo usuário ([01 §3.2](01-banco-de-dados.md), fallback: ordem do enum — RF-24); header por grupo: `Frios (3)` com contagem de pendentes; grupos vazios não renderizam (Fase 6, RF-15) |
| Exibição | Ordenação determinística entre dispositivos: `(categoria na ordem salva, ordem, id)` |
| Item | Nome, quantidade + unidade, checkbox |
| Checkbox marcada | Item move para seção dobrável "Itens Concluídos (n)" — **sem divisão por categoria** (Fase 6) |
| Tocar no item | Abre o editor (mesmo diálogo do swipe): nome, quantidade, unidade, categoria, **Preço (R$)** e ação **Remover** com undo (F12-T06/F25); a quantidade aceita decimal pt-BR (`1,5`), fração (`1/2`) e glifos (`½`, `1½`) via `parseQuantidade` — RF-25/F29 (o misto separado `1 1/2` é combinado pelo parser, não pelo editor); nome vazio/quantidade inválida/preço inválido geram erro inline no campo (F14-T07) |
| Swipe direita/esquerda | Editar / Remover (com undo via SnackBar); edição inclui **dropdown de categoria** ao lado das unidades (Fase 6); o dropdown mantém a **ordem do enum**, não a ordem custom (RF-24) |
| Botão de importação | Abre modal (6.4) |
| Menu (⋮) | Ordem renderizada: "Desmarcar todos", "Limpar concluídos", "Renomear lista", "Adicionar de outra lista" (dono/editor), "Membros", "Convidar" (dono), "Excluir lista" (dono) |
| Ações em massa | Reaproveitar lista (desmarcar todos) e limpar concluídos — confirmação para destrutivas; "desmarcar" devolve o item ao seu grupo; **limpar concluídos tem undo** (SnackBar 3s, restaura `id`/`ordem` originais — F14-T05) |
| Indicador de sync | Estado de [03 §6](03-sincronizacao-offline.md) no **topo da tela da lista** e no **topo do painel de listas** (Minhas Listas e Compartilhadas — F21-T01, alinhado ao wireframe [10 §3.2](10-wireframes-telas.md)) |
| Chips de itens frequentes | Acima do campo "Adicionar item", em rolagem horizontal, quando o campo está **vazio** e há sugestões (`itensFrequentesProvider`, RF-19): toque adiciona o item com quantidade 1, unidade `un` e categoria pela cadeia local (§3); somem ao digitar o primeiro caractere e voltam ao limpar o campo |
| Botão do modo mercado | Ícone `shopping_cart_checkout` na AppBar (`tooltip` "Modo mercado"), **antes da lupa**; abre `/mercado/:listaId` via `push`. Visível apenas para dono/editor (papel efetivo com escrita); para `leitor` o botão não existe (RF-18) |
| Faixa do total | Componente `TotalCarrinho` no **rodapé** da tela da lista e no **modo mercado** (§6.5): "No carrinho: R$ …" somando **itens marcados com preço**; se houver marcados sem preço, acrescenta "· N sem preço". Oculta quando não há nenhum item marcado (RF-21, F25) |

* **Reordenar (Fase 6):** drag-and-drop restrito **ao grupo da categoria** — reordena só os itens do grupo (grava `ordem` local + fila); mudar de categoria é pelo dropdown do editar. Exibição continua `(categoria na ordem salva, ordem, id)` — sem coluna nova.
* **Quantidades e frações (RF-25, F29):** stepper + input direto; a **entrada rápida** e a **importação** aceitam decimal pt-BR (`1,5`), fração (`1/2`), glifos (`½`, `1½`) e **misto separado** (`1 1/2`, combinado pelo parser); o **editor** aceita os mesmos formatos **menos o misto separado** — lê a quantidade com `parseQuantidade`, que trata **um token único** (digitar `1 1/2` no editor gera erro inline). Unidades restritas ao enum ([01 §3.1](01-banco-de-dados.md)). A exibição usa `formatarQuantidade` (`lib/features/listas/domain/quantidade.dart`): glifos comuns (`½ ¼ ¾ ⅓ ⅔`, mistos como `1½`, `1¼`) e, fora deles, arredonda para ≤ 3 casas (`1.2`, `0.143`).
* **Adicionar por voz (RF-26, F30):** o campo "Adicionar item" ganha um **microfone** (dono/editor, Android/iOS) que **preenche o campo** com o texto reconhecido **on-device** (pt-BR) via `ReconhecimentoVoz`/`reconhecimentoVozProvider`; o usuário confirma (Enter) e o parser local cuida do resto — a voz **não** adiciona item sozinha. O app **pede** on-device (`onDevice: true`) e nunca inicia chamada de rede própria, mas o `speech_to_text` **não expõe** forma de verificar/forçar, então no Android o **SO** pode usar o reconhecedor de rede quando não há modelo on-device (limitação do plugin/SO). Toque de novo para; ao sair da tela o ditado é cancelado; indisponível/permissão negada → SnackBar "Reconhecimento de voz indisponível neste aparelho."; Web/Desktop ocultam o botão.
* **Preço do item (RF-21, F25):** campo **"Preço (R$)"** opcional no editor; aceita `5,49`, `5.49`, `5`; vazio → sem preço (`null`); inválido/negativo → erro inline. Gravado em centavos (`preco_centavos`, [01 §4.3](01-banco-de-dados.md)) via `editarItem(..., precoCentavos, limparPreco)`; o payload de sync inclui a coluna ([03 §3](03-sincronizacao-offline.md)) e `duplicarLista` copia o preço (RF-20).
* **Faixa do total (RF-21, F25):** `TotalCarrinho` (`lib/features/listas/ui/total_carrinho.dart`, `Semantics` live region) deriva de `itensDaListaProvider` e mostra "No carrinho: R$ …" no rodapé da lista e no modo mercado; soma `round(quantidade × precoCentavos)` apenas de itens **marcados com preço**, com sufixo "· N sem preço" quando aplicável. Oculta sem marcados.
* Item duplicado (mesmo nome ativo, comparação normalizada): **mesma unidade → soma** a quantidade; **unidade diferente → atualiza** o item para a nova quantidade/unidade — nunca duplica o nome ativo (unique parcial no servidor) (F12-T06).
* **Rótulo do campo de nome (F14-T06):** no editor, o campo usa "Nome do item" — "Adicionar item" vale só para a entrada rápida.
* **Erro e vazio (F14-T04):** falha de carga usa `AppEstadoErro` **com retry** (não texto puro, como fazia); "Lista não encontrada" ganha CTA para `/listas`; o vazio do leitor **instrui** ("Peça a um editor para adicionar") em vez de apontar para um campo que ele não tem.
* **Banner de leitura (F14-T08):** usa `AppBannerTipo.leitura` ([15 §3](15-design-system.md)), não um `Container` manual.
* **Busca (F16, RF-17):** a lupa na AppBar (todas as roles) revela um campo que filtra os itens pelo **nome** (offline, sem acento/caixa); mantém os grupos de categoria (escondendo vazios) e a seção de concluídos (contagens filtradas); **drag desabilitado** enquanto filtra; ao **adicionar** um item a busca é limpa; sem resultado → `AppEstadoVazio` "Nenhum item encontrado" com "Limpar busca"; campo com rótulo acessível (label) e hint de exemplo.
* **Adicionar de outra lista (RF-23, F27):** item no menu `⋮` (dono/editor) abre o modal "Adicionar de outra lista" — seletor da lista de origem (todas as listas do usuário menos a atual; arquivadas rotuladas "Arquivada") e os **pendentes** da origem em multi-seleção com "Selecionar todos"; a ação "Adicionar" (estática; desabilitada com 0 selecionados) insere com a **dedup do app** (`adicionarItensDedup`, soma/replace) e a tela mostra um SnackBar com a contagem (`AppStrings.itensAdicionadosDeOutra`); **preço não é copiado**. Tudo local + fila ([03](03-sincronizacao-offline.md)).

### 6.4. Modal "Importar lista" (RF-16)

Um único modal de importação local (modo único, offline, RF-16):

1. Textarea + contador de caracteres (≤ 10.000 — [04 §2](04-importacao-lista.md)).
2. Botão "Extrair itens": parser local puro (`lib/core/importacao/parser_lista_local.dart`), sem rede; categoria pela cadeia local (memória → dicionário → `outros`, [§3](05-app-flutter.md)); disponível offline.
3. **Modal de pré-visualização:** checkboxes para incluir/excluir cada item; edição inline de nome/quantidade/unidade/**categoria** (dropdown com o enum [01 §3.2](01-banco-de-dados.md)), com erro inline de nome/quantidade (F14-T07); `aviso` exibido como nota.
4. "Adicionar N itens à lista" → grava localmente (fila de INSERTs).
5. Erros do parser exibidos com as mensagens amigáveis do contrato ([04 §2](04-importacao-lista.md)).

### 6.5. Modo mercado (RF-18)

Tela dedicada `/mercado/:listaId` para usar o celular no mercado, sem a densidade da tela da lista (wireframe [10 §3.5](10-wireframes-telas.md)):

* **AppBar** com título da lista e seta de voltar (sem menu); `IndicadorSync` no topo apenas no estado carregado — em carregando/erro/não encontrada o título é "Modo mercado" e o indicador não renderiza.
* **Contador** `mercadoProgresso(marcados, total)` (ex.: "3 de 12"): marcados **nesta sessão** / total de itens ativos; é uma live region.
* **Faixa do total (RF-21):** `TotalCarrinho` logo abaixo do contador — "No carrinho: R$ …" dos itens marcados com preço (§6.3); oculta sem marcados.
* **Pendentes** em lista de altura generosa, com checkbox de alvo ≥48dp e toque na linha para marcar (`editarItem(concluido: true)`). **Sem** grupos de categoria, busca, drag, swipe, menu ou importação.
* **Faixa "Marcados (n)"** recolhível no rodapé — é o undo do toque acidental: ao marcar, o item sai da área principal e entra na faixa, que abre automaticamente na primeira marcação da sessão; tocar num item da faixa desmarca e o devolve aos pendentes.
* **Estados:** carregando (`AppEsqueleto`), erro (`AppEstadoErro` com retry em `itensDaListaProvider`), lista não encontrada e "tudo comprado" (0 pendentes) com CTA para voltar; enquanto o papel não carrega, o default é leitor (somente leitura).
* O botão de entrada fica na AppBar da tela da lista e é **escondido para leitor** (§6.3).

### 6.6. Tela de Membros (RF-13/RF-14)

Rota `/membros/:listaId` (AppBar `Membros · {título}`). Lista os membros (UUID prefixado), o chip de papel e o menu `⋮` das ações do dono (mudar papel editor↔leitor, remover, **transferir dono**). Fluxo em [08 §8](08-compartilhamento-colaborativo.md); layout em [10 §3.7](10-wireframes-telas.md).

* **Transferir dono (RF-14, F24):** item "Transferir dono" no menu `⋮` de cada membro — visível **só para o dono** e **nunca no próprio usuário**. Abre **confirmação dupla** (a primeira explica que o dono deixará de ser dono e passará a `editor`; a segunda confirma). No sucesso, o papel local vira `editor` (o botão "Sair da lista" passa a aparecer), a lista de membros é recarregada e um SnackBar "Dono transferido." confirma. Operação **online-only** (papel não vive no Drift); offline → erro amigável.
* **Aviso ao novo dono (Realtime):** quem recebe a lista vê o SnackBar genérico "Você agora é dono de uma lista" na tela da lista (sem nome — o RLS não expõe perfis).

### 6.7. Configurações — Aparência e Ordenar categorias (RF-24)

* **Aparência:** seletor de tema Claro/Escuro/Sistema (`SeletorTema`, doc [15 §2](15-design-system.md)).
* **Ordenar categorias (RF-24, F28):** item abaixo do seletor abre `/categorias` (fora do shell), a `TelaOrdenarCategorias` — lista arrastável das 11 categorias com ação **"Restaurar padrão"** (volta à ordem do enum, com confirmação). A preferência é **global** e **local** (SharedPreferences, chave `ordem_categorias`, como o tema); sem schema/RLS/sync. Detalhe em [10 §5.1](10-wireframes-telas.md).

---

## 7. Design System

O design system (tokens, tipografia, componentes, motion, acessibilidade) é
propriedade do **[doc 15](15-design-system.md)**. Resumo: Material 3 Expressive
com seed verde, claro/escuro com paridade, modo Claro/Escuro/Sistema e fonte
Plus Jakarta Sans bundlada. Aqui ficam apenas os estados transversais:

| Estado | Componente padrão (doc 15) |
| :--- | :--- |
| Carregando | `AppBotao(carregando: true)` / `CircularProgressIndicator` |
| Carregando (listas) | `AppEsqueleto` — placeholder estático (F14-T09) |
| Vazio | `AppEstadoVazio` |
| Erro | `AppEstadoErro` (com retry) |
| Offline | `AppBanner.offline` ([03 §6](03-sincronizacao-offline.md)) |

* **Acessibilidade (RNF-06):** semântica/live region, alvos ≥48dp e escala de texto — regras e verificação por teste em [15 §4](15-design-system.md) (F14-T01/T02).
* i18n: pt-BR hardcoded no MVP (strings centralizadas em `core/l10n/app_strings.dart` para facilitar futura tradução). String de UI fora do `AppStrings` é considerada bug (F14-T08).

---

## 8. Checklist de validação (Fases 3–4)

- [ ] Guard de rotas redireciona corretamente (autenticado/não autenticado).
- [ ] CRUD manual funciona offline (avião) e reflete ao reconectar.
- [ ] Checkbox concluída move item para seção dobrável; "Desmarcar todos" reaproveita lista.
- [ ] Importação de lista: pré-visualização editável; cancelar não grava nada.
- [ ] Tema escuro aplicado em todas as telas (sem tela esquecida).
- [ ] Estados vazio/erro/carregando implementados em todas as telas.
- [ ] Acessibilidade (RNF-06): semântica/live region, alvos ≥48dp e escala de texto verificados por teste ([15 §4](15-design-system.md)).
- [ ] Recuperação de senha conclui o ciclo (link → `/redefinir-senha` → login).
- [ ] Widget tests das telas críticas ([07](07-qualidade-ci.md)).

---

## Documentos relacionados
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — engine que os repositórios implementam
- [04 Importação](04-importacao-lista.md) — contrato do parser local consumido pelo modal de importação
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios de aceite destas telas
