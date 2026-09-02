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
│   │   ├── domain/                  # modelos Lista, Item
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
| `itensDaListaProvider(listaId)` | StreamProvider.family | Itens ativos ordenados por `ordem` |
| `syncStatusProvider` | StreamProvider | Estado de sync ([03 §6](03-sincronizacao-offline.md)) |
| `importacaoIaProvider` | NotifierProvider | Estados do modal IA (idle/carregando/erro/prévia) |
| `conectividadeProvider` | StreamProvider | Online/offline (dispara flush) |

---

## 4. Rotas (go_router)

| Rota | Tela | Guard |
| :--- | :--- | :--- |
| `/login` | Login | redirect se autenticado → `/listas` |
| `/registro` | Registro | idem |
| `/recuperar-senha` | Recuperação de senha | público |
| `/listas` | Minhas Listas | exige autenticação |
| `/listas/:id` | Tela da Lista | exige autenticação + pertencimento |

* **Redirect global:** não autenticado → `/login`; autenticado em rota pública → `/listas`.
* Deep link de convite (`/listas/entrar?token=...`) já previsto na rota — **fluxo completo de aceite planejado em [08 §3](08-compartilhamento-colaborativo.md)** (ativado na Fase 6).
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
| Campo "Adicionar item" | Fixo no topo; Enter salva imediatamente (escrita local + fila) |
| Item | Nome, quantidade + unidade, checkbox |
| Checkbox marcada | Item move para seção dobrável "Itens Concluídos (n)" |
| Swipe direita/esquerda | Editar / Remover (com undo via SnackBar) |
| Botão de importação IA | Abre modal (6.4) |
| Menu (⋮) | "Desmarcar todos", "Limpar concluídos", "Renomear lista", "Excluir lista" |
| Ações em massa | Reaproveitar lista (desmarcar todos) e limpar concluídos — confirmação para destrutivas |
| Indicador de sync | Estado de [03 §6](03-sincronizacao-offline.md) no AppBar |

* **Reordenar:** drag-and-drop atualiza `ordem` (persistência local + fila).
* Quantidades: stepper + input direto; unidades restritas ao enum ([01 §3](01-banco-de-dados.md)).
* Tentativa de item duplicado (mesmo nome ativo): sugerir aumento de quantidade em vez de bloquear.

### 6.4. Modal "Importar por IA"
1. Textarea + contador de caracteres (máx. 2.000 — ver contrato em [04 §2](04-ia-edge-function.md)).
2. Botão "Extrair itens" → estado de carregamento com feedback.
3. **Modal de pré-visualização:** checkboxes para incluir/excluir cada item extraído; edição inline de nome/quantidade/unidade; `aviso` da IA exibido como nota.
4. "Adicionar N itens à lista" → grava localmente (fila de INSERTs).
5. Erros da Edge Function exibidos com as mensagens amigáveis do contrato.

---

## 7. Design System

* **Material 3** com `useMaterial3: true` e `ColorScheme.fromSeed`.
* **Tema claro + escuro automático** (segue o sistema); dark mode manual fica para pós-MVP.
* Tipografia padrão do Material; sem fontes customizadas no MVP.
* Componentes padrão para estados transversais:

| Estado | Componente padrão |
| :--- | :--- |
| Carregando | `CircularProgressIndicator` central ou shimmer leve |
| Vazio | Ilustração + texto de orientação + CTA |
| Erro | Banner + botão "Tentar novamente" |
| Offline | Banner discreto persistente ([03 §6](03-sincronizacao-offline.md)) |

* Acessibilidade mínima: alvos de toque ≥ 48dp, contraste AA, textos respeitam escala do sistema.
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
