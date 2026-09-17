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
    └── tables/                      # ListaLocal, ItemLocal, MutacaoPendente
```

**Regra:** `ui` só fala com `providers`; `providers` só falam com `data` (repositórios). Repositórios de leitura expõem **Streams do Drift** (UI reativa offline-first).

---

## 3. Providers Riverpod (por feature)

| Provider | Tipo | Responsabilidade |
| :--- | :--- | :--- |
| `authStateProvider` | StreamProvider | Sessão atual (login/logout/refresh) |
| `appDatabaseProvider` | Provider | Instância única do Drift |
| `listasProvider` | StreamProvider | Listas ativas do usuário (Drift → UI) |
| `itensDaListaProvider(listaId)` | StreamProvider.family | Itens ativos; ordenação de exibição por categoria e `ordem` (Fase 6) |
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

### 6.3. Tela da Lista de Compras
| Elemento | Comportamento |
| :--- | :--- |
| Campo "Adicionar item" | Fixo no topo; Enter salva imediatamente (escrita local + fila) com a categoria sugerida pelas camadas locais (§3, Fase 6). **Reconhece quantidade/unidade no texto** (`1kg de banana` → Banana, 1 kg) via parser local (RF-16); sem unidade no texto, usa a **unidade escolhida no seletor** do campo (menu com o enum, padrão `un`) — F12-T06; texto que o parser descarta (ex.: só pontuação) → erro inline "Não entendi o item" (F14-T07) |
| Itens pendentes | **Agrupados por categoria** na ordem do enum ([01 §3.2](01-banco-de-dados.md)); header por grupo: `Frios (3)` com contagem de pendentes; grupos vazios não renderizam (Fase 6, RF-15) |
| Exibição | Ordenação determinística entre dispositivos: `(categoria, ordem, id)` |
| Item | Nome, quantidade + unidade, checkbox |
| Checkbox marcada | Item move para seção dobrável "Itens Concluídos (n)" — **sem divisão por categoria** (Fase 6) |
| Tocar no item | Abre o editor (mesmo diálogo do swipe): nome, quantidade, unidade, categoria e ação **Remover** com undo (F12-T06); nome vazio/quantidade inválida geram erro inline no campo (F14-T07) |
| Swipe direita/esquerda | Editar / Remover (com undo via SnackBar); edição inclui **dropdown de categoria** ao lado das unidades (Fase 6) |
| Botão de importação | Abre modal (6.4) |
| Menu (⋮) | "Desmarcar todos", "Limpar concluídos", "Renomear lista", "Excluir lista" |
| Ações em massa | Reaproveitar lista (desmarcar todos) e limpar concluídos — confirmação para destrutivas; "desmarcar" devolve o item ao seu grupo; **limpar concluídos tem undo** (SnackBar 3s, restaura `id`/`ordem` originais — F14-T05) |
| Indicador de sync | Estado de [03 §6](03-sincronizacao-offline.md) no AppBar |

* **Reordenar (Fase 6):** drag-and-drop restrito **ao grupo da categoria** — reordena só os itens do grupo (grava `ordem` local + fila); mudar de categoria é pelo dropdown do editar. Exibição continua `(categoria, ordem, id)` — sem coluna nova.
* Quantidades: stepper + input direto; unidades restritas ao enum ([01 §3.1](01-banco-de-dados.md)).
* Item duplicado (mesmo nome ativo, comparação normalizada): **mesma unidade → soma** a quantidade; **unidade diferente → atualiza** o item para a nova quantidade/unidade — nunca duplica o nome ativo (unique parcial no servidor) (F12-T06).
* **Rótulo do campo de nome (F14-T06):** no editor, o campo usa "Nome do item" — "Adicionar item" vale só para a entrada rápida.
* **Erro e vazio (F14-T04):** falha de carga usa `AppEstadoErro` **com retry** (não texto puro, como fazia); "Lista não encontrada" ganha CTA para `/listas`; o vazio do leitor **instrui** ("Peça a um editor para adicionar") em vez de apontar para um campo que ele não tem.
* **Banner de leitura (F14-T08):** usa `AppBannerTipo.leitura` ([15 §3](15-design-system.md)), não um `Container` manual.
* **Busca (F16, RF-17):** a lupa na AppBar (todas as roles) revela um campo que filtra os itens pelo **nome** (offline, sem acento/caixa); mantém os grupos de categoria (escondendo vazios) e a seção de concluídos (contagens filtradas); **drag desabilitado** enquanto filtra; ao **adicionar** um item a busca é limpa; sem resultado → `AppEstadoVazio` "Nenhum item encontrado" com "Limpar busca"; campo com rótulo acessível (label) e hint de exemplo.

### 6.4. Modal "Importar lista" (RF-16)

Um único modal de importação local (padrão, offline, RF-16):

1. Textarea + contador de caracteres (≤ 10.000 — [04 §2](04-importacao-lista.md)).
2. Botão "Extrair itens": parser local puro (`lib/core/importacao/parser_lista_local.dart`), sem rede; categoria pela cadeia local (memória → dicionário → `outros`, [§3](05-app-flutter.md)); disponível offline.
3. **Modal de pré-visualização:** checkboxes para incluir/excluir cada item; edição inline de nome/quantidade/unidade/**categoria** (dropdown com o enum [01 §3.2](01-banco-de-dados.md)), com erro inline de nome/quantidade (F14-T07); `aviso` exibido como nota.
4. "Adicionar N itens à lista" → grava localmente (fila de INSERTs).
5. Erros do parser exibidos com as mensagens amigáveis do contrato ([04 §2](04-importacao-lista.md)).

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
