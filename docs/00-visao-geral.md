# 00 — Visão Geral, Stack, Setup, Riscos e Cronograma

> Navegação: [← Índice](../planejamento_lista_compras.md) · [01 Banco de Dados →](01-banco-de-dados.md)

Este documento concentra a visão do produto, a stack tecnológica, os pré-requisitos de ambiente, os riscos conhecidos, as decisões técnicas (ADRs) e o cronograma por fases.

---

## 1. Visão do Produto

Aplicação multiplataforma para criação, organização e execução de compras de supermercado. Combina gerenciamento manual com importação de listas enviadas em texto livre, mantendo tudo sincronizado em tempo real entre dispositivos e usuários.

> **Escopo do MVP (Versão 1):** **Android, iOS e Web (SPA)**. A partir da **Fase 18**, o **Web passa a ter funcionalidade completa** (não apenas SPA/leitura — banco, auth por link, convites, sync e import) e o **Desktop (Windows, Linux e macOS) passa a ser suportado**, aproveitando que a base de código Flutter já o suporta (decisão **ADR-012**, §5).
>
> **Web: uso local (18/09/2026).** Por decisão do dono, **não há publicação do Web em URL pública** — o Hosting do Firebase foi desabilitado e a Fase 19 (Publicação Web) foi encerrada sem deploy (ver **ADR-013**, §5). O Web continua funcional e suportado para **execução local** (`flutter run -d chrome` / `flutter build web`).

### Funcionalidades-chave (resumo)
| Funcionalidade | Descrição resumida | Documento de referência |
| :--- | :--- | :--- |
| Gerenciamento manual de listas | Adição, quantidade/unidade, checkboxes, edição, ações em massa | [05 App Flutter](05-app-flutter.md) |
| Importação por texto | Parser local determinístico (offline) extrai itens e sugere categoria | [04 Importação](04-importacao-lista.md) |
| Sincronização multi-dispositivo | Efeito "Google Docs" via Realtime (WebSockets) | [03 Sincronização](03-sincronizacao-offline.md) |
| Offline-first | Uso pleno sem conexão, com sincronização posterior | [03 Sincronização](03-sincronizacao-offline.md) |
| Listas compartilhadas | Arquitetura pronta; UI de convites na Fase 6 | [01 Banco de Dados](01-banco-de-dados.md) |

---

## 2. Stack Tecnológica

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER (Frontend)                       │
│       (Android, iOS, Web completo, Desktop — Fase 18)       │
│         State management: Riverpod                          │
│         Importação: parser local (offline, RF-16)           │
└──────┬──────────────────────────────────────┬───────────────┘
       │                                      │
       │ (1) Sincronização                    │ (0) Cache local
       │     Realtime (WebSockets)            │     Drift/SQLite
       │                                      │     (offline-first)
       ▼                                      ▼
┌──────────────────────────────────────────────────────────────┐
│                       SUPABASE BACKEND                       │
│  - PostgreSQL Database                                       │
│  - Auth (Login / Registro)                                   │
│  - Realtime Engine                                           │
│  - RLS (Segurança)                                           │
└──────────────────────────────────────────────────────────────┘
```

| Camada | Tecnologia | Motivo |
| :--- | :--- | :--- |
| Frontend | **Flutter (Dart)** + **Riverpod** | Base de código única para Mobile/Web; Riverpod é compile-safe e testável, ideal para orquestrar cache local + Realtime |
| Persistência local | **Drift (SQLite)** | Banco relacional local que espelha o schema PostgreSQL; queries complexas de sync; migrações versionadas |
| Backend | **Supabase** (PostgreSQL, Auth, Realtime) | Robusto, baixo custo inicial, Realtime nativo |
| Migrations | **Supabase CLI** | Schema reproduzível e versionado no repositório |

---

## 3. Setup & Pré-requisitos

### 3.1. Contas necessárias
| Conta | Uso | Custo |
| :--- | :--- | :--- |
| [Supabase](https://supabase.com) | Banco, Auth, Realtime | Free tier |
| [GitHub](https://github.com) | Repositório + CI (GitHub Actions) | Free |

### 3.2. Ferramentas locais (versões mínimas — "stable recente")
| Ferramenta | Versão mínima | Observações |
| :--- | :--- | :--- |
| Flutter SDK | 3.24+ (stable) | Com Web e Android enabled (`flutter doctor`) |
| Dart | incluso no Flutter | — |
| Supabase CLI | 1.190+ | Migrations e gestão do backend |
| Android Studio | latest stable | SDK + emulador; `adb` |
| VS Code | latest | Extensões Flutter/Dart |

### 3.3. Configuração de ambiente (checklist)
- [x] `flutter doctor` sem pendências para android/web. (aviso de licença Android é falso alarme do novo Android CLI — hash de licença presente no SDK)
- [x] Projeto Supabase criado; URL e anon key anotados. (ref: `smshgctdwxkqbvbdlhud`, região definida na criação)
- [x] `supabase init` + `supabase link` no projeto local.
- [x] GitHub Actions habilitado (ver [07 Qualidade & CI](07-qualidade-ci.md)). *(pipeline verde em PR + branch protection em `main` exigindo `flutter` e `supabase`)*

### 3.4. Variáveis e segredos
| Segredo | Onde vive | Nunca em |
| :--- | :--- | :--- |
| Supabase URL + anon key | App Flutter (build-time) | — (anon key é pública por design; RLS protege) |

---

## 4. Riscos & Mitigações

| # | Risco | Impacto | Mitigação acordada |
| :--- | :--- | :--- | :--- |
| R-01 | **Supabase free tier pausa o projeto após ~1 semana sem atividade** — sincronização fica indisponível até reativação (cold start de minutos) | Alto em produção pública | Aceito no MVP (contexto pessoal/familiar). **Gatilho documentado:** upgrade para Supabase Pro (~US$ 25/mês) antes de lançamento público. Sem keep-alive no código |
| R-03 | Conflitos de sincronização com relógio de dispositivo errado | Médio | Last-write-wins com desempate pelo timestamp do servidor (ver [03](03-sincronizacao-offline.md)) |
| R-05 | Escopo das 6 plataformas atrasar o MVP | Médio | MVP restrito a Android/iOS/Web (ADR-001); Desktop entra na Fase 18 (ADR-012) |
| R-06 | Usuário exclui conta; dados retidos indevidamente | Legal (LGPD) | Delete físico em cascata; exclusão de conta na Fase 5 (ver [06 MVP & Entregas](06-mvp-entregas.md)) |

---

## 5. Registro de Decisões Técnicas (ADRs)

| # | Data | Decisão | Alternativas consideradas | Justificativa |
| :--- | :--- | :--- | :--- | :--- |
| ADR-001 | 02/09/2026 | MVP restrito a **Android, iOS e Web (SPA)**; **Desktop suportado a partir da Fase 18** (ver ADR-012) | Todas as plataformas na v1 | Onde está o uso real (supermercado + casa); reduz tempo de build/teste |
| ADR-002 | 02/09/2026 | **Riverpod** como state management | Bloc, Provider + ChangeNotifier | Compile-safe, testável, ideal para orquestrar cache local + Realtime |
| ADR-003 | 02/09/2026 | **Drift/SQLite** como banco local | Isar, Hive | Relacional espelhando o Postgres; queries complexas de sync; migrações versionadas |
| ADR-004 | 02/09/2026 | Conflitos de sync via **last-write-wins** (`updated_at` + tombstones) | Modal de conflito manual | Simples e suficiente para o domínio; listas de compras toleram LWW |
| ADR-005 | 02/09/2026 | `unidade` como **enum fechado** | Texto livre | Elimina inconsistências ("kg" × "KG" × "quilos") |
| ADR-006 | 02/09/2026 | IDs gerados no **cliente** (UUID v4) | IDs do servidor | Permite criar dados offline sem negociação de chaves |
| ADR-007 | 02/09/2026 | Aceitar limitações do **free tier** no MVP; gatilho de upgrade Supabase Pro antes de lançamento público | Keep-alive, upgrade imediato | Custo zero mantido; sem engineering de contorno que possa violar ToS |
| ADR-008 | 02/09/2026 | **Delete físico em cascata** na exclusão de conta; exclusão disponível na Fase 5 | Anonimização de dados | Domínio com pouco dado sensível; CASCADE já nativo; atende LGPD |
| ADR-009 | 02/09/2026 | **Sentry** (plano free) como observabilidade no MVP | Crashlytics, nada | Cobertura Flutter/Web; integração simples; decisão mínima viável |
| ADR-010 | 02/09/2026 | **GitHub Actions** como CI desde a Fase 1 | Nenhum CI, GitLab CI | Já hospedamos no GitHub; pipeline simples (analyze + format + test) |
| ADR-011 | 08/09/2026 | `categoria` do item como **enum fechado** (11 valores) com sugestão local em camadas — memória por nome → dicionário estático → `outros` | Texto livre; sugestão manual | Consistência de dados ("Frios" × "frios"); preserva o offline-first |
| ADR-012 | 17/09/2026 | Suporte a **Web completo** e **Desktop (Windows/Linux/macOS)** (Fase 18): banco local por fábrica com import condicional (`WasmDatabase`/OPFS-IndexedDB no web, `NativeDatabase` no nativo/desktop); auth e convites via URL https no web (`Uri.base.origin`) e scheme custom no nativo; CI valida `flutter build web` e builds desktop | Web só SPA/leitura; adiar desktop indefinidamente | A base Flutter já cobre as plataformas; preserva o offline-first com o mesmo Drift; a hospedagem pública ficou na Fase 19 (ADR-013) |
| ADR-013 | 17/09/2026 *(revisado em 18/09/2026)* | **Publicação do Web cancelada por decisão do dono: o Web fica para uso local.** O Hosting do Firebase foi desabilitado e **os artefatos de publicação foram removidos do repositório** (`firebase.json`, `.firebaserc`, `web/privacidade.html`, `web/robots.txt` e o teste-guarda da página pública). Rodar local: `flutter run -d chrome` (dev) ou `flutter build web` + servir `build/web`. As decisões de banco da Fase 19 seguem valendo (RPC `agora_servidor`, policies). | ~~Publicar em URL pública (Firebase Hosting)~~ — cancelado | Publicar o Web exigia manutenção de um site público sem uso previsto; o valor do offline-first está no app instalado. Reabilitar, se um dia fizer sentido, é trabalho novo (reconstruir os artefatos), não um revert |

---

## 6. Cronograma de Execução por Fases

| Fase | Marco / Entrega | Descrição | DoD resumido |
| :--- | :--- | :--- | :--- |
| **Fase 1** | **Infraestrutura & Banco de Dados** | Criar projeto no Supabase; **migrations versionadas via Supabase CLI** (tabelas, enum de unidades, triggers, índices); configurar políticas de segurança (RLS — [02](02-seguranca-rls.md)) e ativar o Realtime. | `supabase db reset` aplica tudo; testes de negação RLS passam · Tarefas: F1 em [14](14-tarefas.md) |
| **Fase 3** | **App Flutter - Core e Entrada Manual** | Configurar projeto Flutter (Riverpod + Drift); telas de Login/Registro (**incluindo recuperação de senha e verificação de e-mail**) e Minhas Listas; interface da lista com adição/edição manual, checkboxes e enum de unidades. **Testes de repositório e widget tests desde esta fase** (ver [07](07-qualidade-ci.md)). | CRUD manual funciona online; CI verde |
| **Fase 4** | **Integrar Sincronização** | Implementar o **Sync Engine offline-first** (fila de mutações, LWW, tombstones — ver [03](03-sincronizacao-offline.md)); validar sincronização simultânea Web/Mobile. | Sync validado em 2 dispositivos; fila offline esvazia ao reconectar |
| **Fase 5** | **Polimento e Publicação (MVP)** | Tratar estado offline (indicadores na UI), **testes de usabilidade** (roteiro em [11](11-usabilidade-fase5.md)), **exclusão de conta (LGPD)** e publicação de **Android (teste interno na Play)** — o Web é publicado na Fase 19 (ADR-013). | Critérios de aceite do MVP 100% (ver [06](06-mvp-entregas.md)) |
| **Fase 6** | **Pós-MVP** | Publicação iOS; **compartilhamento colaborativo ativado na UI** (planejamento em [08](08-compartilhamento-colaborativo.md)); **agrupamento da lista por categoria** (spec em [superpowers/specs](superpowers/specs/2026-09-08-agrupamento-categorias-design.md)); limpeza de tombstones; avaliação de upgrade Supabase Pro. | — |
| **Fase 8** | **Revisão Visual e de UX** | Design system (tokens, M3 Expressive, fonte, componentes), refresh das telas e redesign de navegação. | Etapa 1 (fundação) entregue, CI verde — spec em [`superpowers/specs/2026-09-11-revisao-visual-ux-design.md`](superpowers/specs/2026-09-11-revisao-visual-ux-design.md) |
| **Fase 14** | **Acessibilidade, Fluxos e Polimento de UX** | Conformidade com o RNF-06 (semântica, live regions, alvos ≥48dp, escala de texto), conclusão da recuperação de senha (RF-01) e polimento de estados/feedback/consistência das telas. | Testes de acessibilidade verdes + docs donos atualizados — spec em [`superpowers/specs/2026-09-14-ux-acessibilidade-design.md`](superpowers/specs/2026-09-14-ux-acessibilidade-design.md) |
| **Fase 16** | **Busca e filtro** | Busca/filtro **local (offline)** por título no painel e por nome na tela da lista (RF-17), sem mudança de schema/RLS/sync. | Busca e vazios de resultado com testes verdes; CI verde — spec em [`superpowers/specs/2026-09-16-busca-filtro-design.md`](superpowers/specs/2026-09-16-busca-filtro-design.md) |
| **Fase 18** | **Suporte a Web e Desktop** | Banco local por plataforma (fábrica com import condicional: Drift/Wasm no web, nativo no desktop), auth/links por plataforma e path URL strategy; pastas de desktop; CI validando `flutter build web` e builds desktop. | Web funcional completo e app abrindo/persistindo no Windows; Android/iOS sem regressão; CI verde — spec em [`superpowers/specs/2026-09-17-suporte-web-desktop-design.md`](superpowers/specs/2026-09-17-suporte-web-desktop-design.md) |
| **Fase 19** | **Publicação Web** ~~(suspensa)~~ | **Decisão do dono (18/09/2026): o Web fica para uso local** — o Hosting foi desabilitado e a fase é encerrada sem deploy em produção (ver ADR-013). A base técnica entregue na F18 (Web funcional) permanece. | ~~URL pública funcionando~~ — cancelado; rodar local por `flutter run -d chrome`/`flutter build web` — spec em [`superpowers/specs/2026-09-17-publicacao-web-design.md`](superpowers/specs/2026-09-17-publicacao-web-design.md) |
| **Fase 22** | **Modo mercado e itens frequentes** | Tela focada para comprar no corredor (RF-18: pendentes em destaque, contador, faixa "Marcados") e chips de sugestão derivados do histórico local (RF-19), 100% offline e sem mudança de schema/RLS/sync. | Botão/gate por papel, tela do mercado e chips com testes verdes; CI verde — spec em [`superpowers/specs/2026-09-18-modo-mercado-frequentes-design.md`](superpowers/specs/2026-09-18-modo-mercado-frequentes-design.md) |

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — schema, SQL, migrations
- [02 Segurança RLS](02-seguranca-rls.md) — policies e testes de negação
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — sync engine, LWW
- [04 Importação](04-importacao-lista.md) — parser local (RF-16)
- [05 App Flutter](05-app-flutter.md) — arquitetura, telas, UX e design
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios, LGPD, métricas
- [07 Qualidade & CI](07-qualidade-ci.md) — testes, CI, observabilidade
- [08 Compartilhamento Colaborativo](08-compartilhamento-colaborativo.md) — convites, papéis, Fase 6
- [09 Runbook de Operações](09-runbook-operacoes.md) — incidentes, backups, quotas
- [10 Wireframes das Telas](10-wireframes-telas.md) — layout de todas as telas
- [11 Usabilidade (Fase 5)](11-usabilidade-fase5.md) — roteiro e critérios de teste
- [15 Design System](15-design-system.md) — tokens, componentes, acessibilidade
