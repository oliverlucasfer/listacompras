# 05 — App Flutter (Arquitetura, Telas, UX e Design)

> Navegação: [← 04 IA / Edge Function](04-ia-edge-function.md) · [06 MVP & Entregas →](06-mvp-entregas.md)

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
│   ├── ia/
│   │   ├── data/                    # EdgeFunctionClient
│   │   └── ui/                      # ModalImportarTexto, ModalPrevisualizacao
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
| `importacaoIaProvider` | NotifierProvider | Estados do modal IA (idle/carregando/erro/prévia) |
| `conectividadeProvider` | StreamProvider | Online/offline (dispara flush) |
| `sugestaoCategoriasProvider` | Provider | Cadeia de sugestão local (Fase 6/RF-15) |

**Sugestão de categoria em camadas (Fase 6, ADR-011, spec §4)** — `SugestaoCategorias.sugerirCategoria(nome)`, zero rede:

1. **Memória por nome:** categoria do item ativo mais recente com o mesmo nome (qualquer lista do usuário no dispositivo; comparação sem acento/caixa; `updated_at` DESC).
2. **Dicionário estático** (`core/categorias/dicionario_categorias.dart`, ~230 termos pt-BR versionados no repo): casa quando **todas** as palavras do termo aparecem no nome; multi-palavra casa antes de palavra única ("leite condensado" → Mercearia antes de "leite" → Laticínios), empate por ordem alfabética.
3. **Fallback:** `outros`.

A IA **não** entra nesta cadeia — apenas refina o import (§6.4). O dicionário não cobre produto incomum: cai em `outros` e passa a ser lembrado pela memória (a cadeia "aprende" pelo uso, sem tabela nova). Proteínas frescas (carne, frango, peixe, ovos) ficam em **Frios** por convenção do dicionário.

---

## 4. Rotas (go_router)

| Rota | Tela | Guard |
| :--- | :--- | :--- |
| `/login` | Login (aceita `?next=` para voltar ao fluxo pós-login, ex. `/entrar?token=...`) | redirect se autenticado → `/listas` |
| `/registro` | Registro (propaga `?next=` para o login na tela "Verifique seu e-mail") | idem |
| `/recuperar-senha` | Recuperação de senha | público |
| `/entrar` | Aceite de convite (doc [08 §3](08-compartilhamento-colaborativo.md)): lê `?token=`; sem sessão mostra contexto e vai ao login/registro com `?next=`; com sessão aceita (RPC idempotente) e navega à lista | público |
| `/listas` | Minhas Listas — AppBar "Entrar com código" (`person_add`): colar token cru → aceite → navega à lista; erro via SnackBar | exige autenticação |
| `/listas/:id` | Tela da Lista | exige autenticação + pertencimento |

* **Redirect global:** não autenticado → `/login`; autenticado em rota pública → `/listas`, **exceto `/entrar`** (permanece pública — a tela decide).
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
          ├───► [Entrada por Texto Inteligente (IA)]:
          │     Clica em "Importar por IA" -> Cola frase livre ->
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
* Estados: carregando (spinner no botão), erro (mensagem inline amigável).

### 6.2. Painel "Minhas Listas"
* Lista de cards: título, contagem de itens pendentes/total, atualização relativa ("há 5 min").
* FAB "Nova lista" → bottom sheet com campo de título.
* Long-press no card: renomear / excluir (com confirmação).
* Estado vazio: ilustração simples + CTA de criação.
* Lista com `deletado_em` nunca aparece (tombstone invisível).

### 6.3. Tela da Lista de Compras
| Elemento | Comportamento |
| :--- | :--- |
| Campo "Adicionar item" | Fixo no topo; Enter salva imediatamente (escrita local + fila) com a categoria sugerida pelas camadas locais (§3, Fase 6) |
| Itens pendentes | **Agrupados por categoria** na ordem do enum ([01 §3.2](01-banco-de-dados.md)); header por grupo: `Frios (3)` com contagem de pendentes; grupos vazios não renderizam (Fase 6, RF-15) |
| Exibição | Ordenação determinística entre dispositivos: `(categoria, ordem, id)` |
| Item | Nome, quantidade + unidade, checkbox |
| Checkbox marcada | Item move para seção dobrável "Itens Concluídos (n)" — **sem divisão por categoria** (Fase 6) |
| Swipe direita/esquerda | Editar / Remover (com undo via SnackBar); edição inclui **dropdown de categoria** ao lado das unidades (Fase 6) |
| Botão de importação IA | Abre modal (6.4) |
| Menu (⋮) | "Desmarcar todos", "Limpar concluídos", "Renomear lista", "Excluir lista" |
| Ações em massa | Reaproveitar lista (desmarcar todos) e limpar concluídos — confirmação para destrutivas; "desmarcar" devolve o item ao seu grupo |
| Indicador de sync | Estado de [03 §6](03-sincronizacao-offline.md) no AppBar |

* **Reordenar (Fase 6):** drag-and-drop restrito **ao grupo da categoria** — reordena só os itens do grupo (grava `ordem` local + fila); mudar de categoria é pelo dropdown do editar. Exibição continua `(categoria, ordem, id)` — sem coluna nova.
* Quantidades: stepper + input direto; unidades restritas ao enum ([01 §3.1](01-banco-de-dados.md)).
* Tentativa de item duplicado (mesmo nome ativo): sugerir aumento de quantidade em vez de bloquear.

### 6.4. Modal "Importar lista" (RF-06 + RF-16)

Um único modal com seletor de modo **Rápido** (padrão, local/offline, RF-16) e **IA** (RF-06):

1. Textarea + contador de caracteres (Rápido ≤ 10.000; IA ≤ 2.000 — [04 §2](04-ia-edge-function.md)).
2. Botão "Extrair itens":
   * **Rápido:** parser local puro (`lib/core/importacao/parser_lista_local.dart`), sem rede; categoria pela cadeia local (memória → dicionário → `outros`, [§3](05-app-flutter.md)); disponível offline.
   * **IA:** fluxo atual (Edge Function `parse-lista`, com carregamento e erros do contrato).
3. **Modal de pré-visualização (comum aos dois modos):** checkboxes para incluir/excluir cada item; edição inline de nome/quantidade/unidade/**categoria** (dropdown com o enum [01 §3.2](01-banco-de-dados.md)); `aviso` exibido como nota.
4. "Adicionar N itens à lista" → grava localmente (fila de INSERTs).
5. Erros da IA exibidos com as mensagens amigáveis do contrato ([04 §2](04-ia-edge-function.md)).

---

## 7. Design System

O design system (tokens, tipografia, componentes, motion, acessibilidade) é
propriedade do **[doc 15](15-design-system.md)**. Resumo: Material 3 Expressive
com seed verde, claro/escuro com paridade, modo Claro/Escuro/Sistema e fonte
Plus Jakarta Sans bundlada. Aqui ficam apenas os estados transversais:

| Estado | Componente padrão (doc 15) |
| :--- | :--- |
| Carregando | `AppBotao(carregando: true)` / `CircularProgressIndicator` |
| Vazio | `AppEstadoVazio` |
| Erro | `AppEstadoErro` (com retry) |
| Offline | `AppBanner.offline` ([03 §6](03-sincronizacao-offline.md)) |

* i18n: pt-BR hardcoded no MVP (strings centralizadas em `core/l10n/app_strings.dart` para facilitar futura tradução).

---

## 8. Checklist de validação (Fases 3–4)

- [ ] Guard de rotas redireciona corretamente (autenticado/não autenticado).
- [ ] CRUD manual funciona offline (avião) e reflete ao reconectar.
- [ ] Checkbox concluída move item para seção dobrável; "Desmarcar todos" reaproveita lista.
- [ ] Importação IA: pré-visualização editável; cancelar não grava nada.
- [ ] Tema escuro aplicado em todas as telas (sem tela esquecida).
- [ ] Estados vazio/erro/carregando implementados em todas as telas.
- [ ] Widget tests das telas críticas ([07](07-qualidade-ci.md)).

---

## Documentos relacionados
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — engine que os repositórios implementam
- [04 IA / Edge Function](04-ia-edge-function.md) — contrato consumido pelo modal de importação
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios de aceite destas telas
