# 00 — Visão Geral, Stack, Setup, Riscos e Cronograma

> Navegação: [← Índice](../planejamento_lista_compras.md) · [01 Banco de Dados →](01-banco-de-dados.md)

Este documento concentra a visão do produto, a stack tecnológica, os pré-requisitos de ambiente, os riscos conhecidos, as decisões técnicas (ADRs) e o cronograma por fases.

---

## 1. Visão do Produto

Aplicação multiplataforma para criação, organização e execução de compras de supermercado. Combina gerenciamento manual com Inteligência Artificial para interpretar listas enviadas em texto livre, mantendo tudo sincronizado em tempo real entre dispositivos e usuários.

> **Escopo do MVP (Versão 1):** **Android, iOS e Web (SPA)**. As plataformas Desktop (Windows, macOS, Linux) serão contempladas em fase posterior (Fase 6), aproveitando que a base de código Flutter já as suporta.

### Funcionalidades-chave (resumo)
| Funcionalidade | Descrição resumida | Documento de referência |
| :--- | :--- | :--- |
| Gerenciamento manual de listas | Adição, quantidade/unidade, checkboxes, edição, ações em massa | [05 App Flutter](05-app-flutter.md) |
| Importação inteligente por texto | IA extrai itens de texto livre, com pré-visualização e confirmação | [04 IA / Edge Function](04-ia-edge-function.md) |
| Sincronização multi-dispositivo | Efeito "Google Docs" via Realtime (WebSockets) | [03 Sincronização](03-sincronizacao-offline.md) |
| Offline-first | Uso pleno sem conexão, com sincronização posterior | [03 Sincronização](03-sincronizacao-offline.md) |
| Listas compartilhadas | Arquitetura pronta; UI de convites na Fase 6 | [01 Banco de Dados](01-banco-de-dados.md) |

---

## 2. Stack Tecnológica

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER (Frontend)                       │
│         (Android, iOS, Web SPA — MVP; Desktop depois)       │
│         State management: Riverpod                          │
└──────┬───────────────────┬──────────────────────┬────────────┘
       │                   │                      │
       │ (1) Texto para    │ (2) Sincronização    │ (0) Cache local
       │     extração      │     Realtime         │     Drift/SQLite
       │                   │     (WebSockets)     │     (offline-first)
       ▼                   ▼                      ▼
┌─────────────────────┐  ┌──────────────────────────────────────┐
│ SUPABASE EDGE       │  │          SUPABASE BACKEND            │
│ FUNCTIONS           │  │  - PostgreSQL Database               │
│ (TypeScript / Deno) │  │  - Auth (Login / Registro)           │
│ - Intermediador     │  │  - Realtime Engine                   │
│   seguro da API Key │  │  - RLS (Segurança)                   │
│ - Rate limiting     │  └──────────────────────────────────────┘
└──────┬──────────────┘
       │ (3) Prompt + Texto
       ▼
┌─────────────────────┐
│  GOOGLE GEMINI API  │
│  (Free Tier - Flash)│
│  - Parser de texto  │
│    livre (JSON mode)│
└─────────────────────┘
```

| Camada | Tecnologia | Motivo |
| :--- | :--- | :--- |
| Frontend | **Flutter (Dart)** + **Riverpod** | Base de código única para Mobile/Web; Riverpod é compile-safe e testável, ideal para orquestrar cache local + Realtime |
| Persistência local | **Drift (SQLite)** | Banco relacional local que espelha o schema PostgreSQL; queries complexas de sync; migrações versionadas |
| Backend | **Supabase** (PostgreSQL, Auth, Realtime, Edge Functions) | Robusto, baixo custo inicial, Realtime nativo |
| Migrations | **Supabase CLI** | Schema reproduzível e versionado no repositório |
| IA | **Google Gemini API** (`gemini-2.0-flash`, Free Tier) | Custo zero; NL de qualidade; structured output em JSON |

---

## 3. Setup & Pré-requisitos

### 3.1. Contas necessárias
| Conta | Uso | Custo |
| :--- | :--- | :--- |
| [Supabase](https://supabase.com) | Banco, Auth, Realtime, Edge Functions | Free tier |
| [Google AI Studio](https://aistudio.google.com) | API Key do Gemini | Free tier |
| [GitHub](https://github.com) | Repositório + CI (GitHub Actions) | Free |

### 3.2. Ferramentas locais (versões mínimas — "stable recente")
| Ferramenta | Versão mínima | Observações |
| :--- | :--- | :--- |
| Flutter SDK | 3.24+ (stable) | Com Web e Android enabled (`flutter doctor`) |
| Dart | incluso no Flutter | — |
| Supabase CLI | 1.190+ | Migrations e deploy das Edge Functions |
| Node.js | 20 LTS | Ambiente local das Edge Functions (Deno runtime no deploy) |
| Android Studio | latest stable | SDK + emulador; `adb` |
| VS Code | latest | Extensões Flutter/Dart, Deno |

### 3.3. Configuração de ambiente (checklist)
- [x] `flutter doctor` sem pendências para android/web. (aviso de licença Android é falso alarme do novo Android CLI — hash de licença presente no SDK)
- [x] Projeto Supabase criado; URL e anon key anotados. (ref: `smshgctdwxkqbvbdlhud`, região definida na criação)
- [ ] API Key do Gemini criada e configurada via `supabase secrets set GEMINI_API_KEY=...` (nunca no repositório). *(Fase 2)*
- [x] `supabase init` + `supabase link` no projeto local.
- [x] GitHub Actions habilitado (ver [07 Qualidade & CI](07-qualidade-ci.md)). *(pipeline verde em PR + branch protection em `main` exigindo `flutter` e `supabase`)*

### 3.4. Variáveis e segredos
| Segredo | Onde vive | Nunca em |
| :--- | :--- | :--- |
| `GEMINI_API_KEY` | Supabase Secrets | repo, client, logs |
| Supabase URL + anon key | App Flutter (build-time) | — (anon key é pública por design; RLS protege) |

---

## 4. Riscos & Mitigações

| # | Risco | Impacto | Mitigação acordada |
| :--- | :--- | :--- | :--- |
| R-01 | **Supabase free tier pausa o projeto após ~1 semana sem atividade** — sincronização/IA ficam indisponíveis até reativação (cold start de minutos) | Alto em produção pública | Aceito no MVP (contexto pessoal/familiar). **Gatilho documentado:** upgrade para Supabase Pro (~US$ 25/mês) antes de lançamento público. Sem keep-alive no código |
| R-02 | **Gemini free tier tem teto diário (RPD) baixo** — 10–15 importações/dia podem esbarrar no limite | Médio | Rate limiting por usuário (ver [04](04-ia-edge-function.md)); mensagem amigável de cota excedida; monitorar uso na Fase 4 |
| R-03 | Conflitos de sincronização com relógio de dispositivo errado | Médio | Last-write-wins com desempate pelo timestamp do servidor (ver [03](03-sincronizacao-offline.md)) |
| R-04 | API Key do Gemini vazada | Alto | Key apenas em Supabase Secrets, acessada por Edge Function; nunca no client |
| R-05 | Escopo das 6 plataformas atrasar o MVP | Médio | MVP restrito a Android/iOS/Web (ADR-001) |
| R-06 | Usuário exclui conta; dados retidos indevidamente | Legal (LGPD) | Delete físico em cascata; exclusão de conta na Fase 5 (ver [06 MVP & Entregas](06-mvp-entregas.md)) |

---

## 5. Registro de Decisões Técnicas (ADRs)

| # | Data | Decisão | Alternativas consideradas | Justificativa |
| :--- | :--- | :--- | :--- | :--- |
| ADR-001 | 02/09/2026 | MVP restrito a **Android, iOS e Web**; Desktop na Fase 6 | Todas as plataformas na v1 | Onde está o uso real (supermercado + casa); reduz tempo de build/teste |
| ADR-002 | 02/09/2026 | **Riverpod** como state management | Bloc, Provider + ChangeNotifier | Compile-safe, testável, ideal para orquestrar cache local + Realtime |
| ADR-003 | 02/09/2026 | **Drift/SQLite** como banco local | Isar, Hive | Relacional espelhando o Postgres; queries complexas de sync; migrações versionadas |
| ADR-004 | 02/09/2026 | Conflitos de sync via **last-write-wins** (`updated_at` + tombstones) | Modal de conflito manual | Simples e suficiente para o domínio; listas de compras toleram LWW |
| ADR-005 | 02/09/2026 | `unidade` como **enum fechado** | Texto livre | Elimina inconsistências ("kg" × "KG" × "quilos"); alimenta o `responseSchema` do Gemini |
| ADR-006 | 02/09/2026 | IDs gerados no **cliente** (UUID v4) | IDs do servidor | Permite criar dados offline sem negociação de chaves |
| ADR-007 | 02/09/2026 | Aceitar limitações do **free tier** no MVP; gatilho de upgrade Supabase Pro antes de lançamento público | Keep-alive, upgrade imediato | Custo zero mantido; sem engineering de contorno que possa violar ToS |
| ADR-008 | 02/09/2026 | **Delete físico em cascata** na exclusão de conta; exclusão disponível na Fase 5 | Anonimização de dados | Domínio com pouco dado sensível; CASCADE já nativo; atende LGPD |
| ADR-009 | 02/09/2026 | **Sentry** (plano free) como observabilidade no MVP | Crashlytics, nada | Cobertura Flutter/Web; integração simples; decisão mínima viável |
| ADR-010 | 02/09/2026 | **GitHub Actions** como CI desde a Fase 1 | Nenhum CI, GitLab CI | Já hospedamos no GitHub; pipeline simples (analyze + format + test) |

---

## 6. Cronograma de Execução por Fases

| Fase | Marco / Entrega | Descrição | DoD resumido |
| :--- | :--- | :--- | :--- |
| **Fase 1** | **Infraestrutura & Banco de Dados** | Criar projeto no Supabase; **migrations versionadas via Supabase CLI** (tabelas, enum de unidades, triggers, índices); configurar políticas de segurança (RLS — [02](02-seguranca-rls.md)) e ativar o Realtime. | `supabase db reset` aplica tudo; testes de negação RLS passam · Tarefas: F1 em [14](14-tarefas.md) |
| **Fase 2** | **Serviço de IA (Edge Function)** | Configurar a API Key do Gemini no Supabase Secrets; implementar a Edge Function em TypeScript com **structured output (JSON mode)**, rate limiting, timeout e tratamento de erros (ver [04](04-ia-edge-function.md)). | Contrato HTTP validado; erros amigáveis |
| **Fase 3** | **App Flutter - Core e Entrada Manual** | Configurar projeto Flutter (Riverpod + Drift); telas de Login/Registro (**incluindo recuperação de senha e verificação de e-mail**) e Minhas Listas; interface da lista com adição/edição manual, checkboxes e enum de unidades. **Testes de repositório e widget tests desde esta fase** (ver [07](07-qualidade-ci.md)). | CRUD manual funciona online; CI verde |
| **Fase 4** | **Integrar IA e Sincronização** | Implementar o modal de importação por texto + pré-visualização; implementar o **Sync Engine offline-first** (fila de mutações, LWW, tombstones — ver [03](03-sincronizacao-offline.md)); validar sincronização simultânea Web/Mobile. | Sync validado em 2 dispositivos; fila offline esvazia ao reconectar |
| **Fase 5** | **Polimento e Publicação (MVP)** | Tratar estado offline (indicadores na UI), **testes de usabilidade** (roteiro em [11](11-usabilidade-fase5.md)), **exclusão de conta (LGPD)** e publicação de **Web + Android**. | Critérios de aceite do MVP 100% (ver [06](06-mvp-entregas.md)) |
| **Fase 6** | **Pós-MVP** | Publicação iOS; suporte Desktop (Windows/macOS/Linux); **compartilhamento colaborativo ativado na UI** (planejamento em [08](08-compartilhamento-colaborativo.md)); limpeza de tombstones; avaliação de upgrade Supabase Pro. | — |

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — schema, SQL, migrations
- [02 Segurança RLS](02-seguranca-rls.md) — policies e testes de negação
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — sync engine, LWW
- [04 IA / Edge Function](04-ia-edge-function.md) — prompt, contrato, rate limit
- [05 App Flutter](05-app-flutter.md) — arquitetura, telas, UX e design
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios, LGPD, métricas
- [07 Qualidade & CI](07-qualidade-ci.md) — testes, CI, observabilidade
- [08 Compartilhamento Colaborativo](08-compartilhamento-colaborativo.md) — convites, papéis, Fase 6
- [09 Runbook de Operações](09-runbook-operacoes.md) — incidentes, backups, quotas
- [10 Wireframes das Telas](10-wireframes-telas.md) — layout de todas as telas
- [11 Usabilidade (Fase 5)](11-usabilidade-fase5.md) — roteiro e critérios de teste
