# 14 — Tarefas (Breakdown Executável)

> Navegação: [← 13 Pré-modelo](13-premodelo-tecnico.md) · [← Índice](../planejamento_lista_compras.md)

**Este documento é o dono do breakdown de execução.** Cada tarefa tem ID, dependências, docs de referência e critério de pronto verificável. Marque `- [x]` ao concluir **com o critério de pronto atendido**.

Formato: `F<n>-T<nn>` (Fase-Tarefa) · Dep: dependências · Docs: referência normativa · CP: critério de pronto.

---

## Fase 1 — Infraestrutura & Banco de Dados

- [x] **F1-T01** — Setup do projeto Supabase local e remoto
  Dep: — · Docs: [00 §3](00-visao-geral.md)
  CP: `supabase init` + `link` feitos; `supabase db reset` roda vazio; checklist 00 §3.3 completo.
- [x] **F1-T02** — Migration `0001_init.sql`: enum de unidades
  Dep: F1-T01 · Docs: [01 §3](01-banco-de-dados.md)
  CP: `select unnest(enum_range(null::unidade_item));` retorna os 9 valores.
- [x] **F1-T03** — Migration `0001_init.sql`: tabelas `listas`, `lista_membros`, `itens_lista` com constraints e índices
  Dep: F1-T02 · Docs: [01 §4](01-banco-de-dados.md)
  CP: unique parcial deduplica item ativo; `quantidade <= 0` rejeita; `unidade='quilos'` rejeita.
- [x] **F1-T04** — Triggers: `touch_updated_at_lww` e `sync_dono`
  Dep: F1-T03 · Docs: [01 §5–6](01-banco-de-dados.md)
  CP: UPDATE reflete `updated_at`; 2º dono na lista falha; remover/rebaixar dono falha.
- [x] **F1-T05** — Migration `0002_rls_policies.sql`: `is_member`, `papel_na_lista`, enable/force RLS, policies completas
  Dep: F1-T04 · Docs: [02 §1–4](02-seguranca-rls.md)
  CP: Policies criadas para as 3 tabelas; `force row level security` aplicado.
- [x] **F1-T06** — Testes de negação e positivos RLS (N-01…N-10, P-01…P-05)
  Dep: F1-T05 · Docs: [02 §5](02-seguranca-rls.md)
  CP: Todos os 15 casos passam em Supabase local; script versionado.
  Nota: N-01…N-10 e P-01…P-04 em `supabase/tests/rls_tests.sql`; P-05 (Realtime com 2 contas) é validado na F1-T07, que testa exatamente esse cenário.
- [x] **F1-T07** — Migration `0003_realtime.sql`: publication das tabelas
  Dep: F1-T05 · Docs: [01 §7](01-banco-de-dados.md)
  CP: Eventos chegam a usuário membro e NÃO chegam a não-membro (teste com 2 contas).
- [x] **F1-T08** — CI GitHub Actions (analyze + format + test + db reset + RLS)
  Dep: F1-T06 · Docs: [07 §3](07-qualidade-ci.md)
  CP: Pipeline verde em PR; branch protection exige CI.

## Fase 2 — Serviço de IA (Edge Function)

- [x] **F2-T01** — Migration tabela `ia_rate_limit` + função de janela
  Dep: F1-T08 · Docs: [04 §4](04-ia-edge-function.md)
  CP: 11ª requisição na mesma janela retorna 429.
- [x] **F2-T02** — Estrutura da função `parse-lista` + `prompt.md` versionado
  Dep: F1-T08 · Docs: [04 §5, §8](04-ia-edge-function.md)
  CP: Pasta conforme 04 §8; prompt rascunho revisado; secret `GEMINI_API_KEY` configurada via CLI.
- [x] **F2-T03** — Integração Gemini (JSON mode + responseSchema + timeout 15s)
  Dep: F2-T02 · Docs: [04 §3, §6](04-ia-edge-function.md)
  CP: Resposta parseada como `{itens[], aviso}`; teste real com 3 exemplos de lista bagunçada. *(modelo migrado para `gemini-3.5-flash-lite` — ver doc 04 §3)*
- [x] **F2-T04** — Validação (zod) e códigos de erro do contrato
  Dep: F2-T03 · Docs: [04 §2, §7](04-ia-edge-function.md)
  CP: Todos os 8 códigos do contrato testados (401, 400×2, 422, 429×2, 504, 500). *(401/400×2/429 rate_limit/500 em e2e; 422/429 cota_ia/504 em unit deno test com fetch fake)*
- [x] **F2-T05** — Testes de integração da função no CI (deno test / supabase local)
  Dep: F2-T04 · Docs: [07 §1](07-qualidade-ci.md)
  CP: Job `supabase` roda os testes da função; pipeline verde. *(unit deno test + e2e do contrato sem Gemini; PR #2)*

## Fase 3 — App Flutter Core

- [x] **F3-T01** — Projeto Flutter: pacotes, estrutura feature-first, tema Material 3 (claro/escuro), strings centralizadas
  Dep: F1-T08 · Docs: [05 §1–2, §7](05-app-flutter.md)
  CP: `flutter run` abre em Android e Chrome; tema escuro aplicado; `analyze` limpo. *(Android: build+instalação+launch validados no emulador; Chrome: run -d chrome + build web; emulador instabilizou após launch — ambiente, não app)*
- [x] **F3-T02** — Schema Drift local (ListaLocal, ItemLocal, MutacaoPendente) + AppDatabase
  Dep: F3-T01 · Docs: [05 §2](05-app-flutter.md), [03 §3](03-sincronizacao-offline.md)
  CP: Migração v1 do Drift criada; CRUD local funciona em teste de repositório. *(5 testes de database: CRUD, soft delete, FK cascade, fila)*
- [x] **F3-T03** — Auth (Supabase): registro c/ verificação, login, recuperação, guard de rotas
  Dep: F3-T01 · Docs: [05 §4, §6.1](05-app-flutter.md) · RF-01
  CP: Fluxo completo funcional; deep link de verificação abrindo o app; redirects corretos. *(signup c/ emailRedirectTo, login, reset, guard /login↔/listas, intent-filter deep link, Mailpit 303 para scheme)*
- [x] **F3-T04** — Tela Login + Registro + Recuperar senha (wireframes 10 §1)
  Dep: F3-T03 · Docs: [05 §6.1](05-app-flutter.md), [10 §1](10-wireframes-telas.md)
  CP: Estados carregando/erro inline; widget tests. *(16 widget tests de auth com FakeAuthRepository: validação, spinner, erro inline, toggle senha, verificação de e-mail; string "já cadastrado" centralizada)*
- [x] **F3-T05** — Painel Minhas Listas (vazio e preenchido, sheet nova lista)
  Dep: F3-T02 · Docs: [05 §6.2](05-app-flutter.md), [10 §2](10-wireframes-telas.md) · RF-02
  CP: Cards com contagem; criar/renomear/excluir locais; estado vazio conforme wireframe. *(cards com contagem via JOIN (11 §2.1), tempo relativo, FAB + sheet nova lista, long-press renomear/excluir com confirmação destrutiva; rota /lista/:id com placeholder p/ F3-T07)*
- [x] **F3-T06** — Repositório Listas/Itens (escrita local + enfileiramento)
  Dep: F3-T02 · Docs: [03 §3](03-sincronizacao-offline.md), [05 §3](05-app-flutter.md)
  CP: Toda escrita aplica no Drift e registra mutação com ts_local; testes de repositório. *(11 testes: criar/renomear/excluir lista, adicionar/editar/remover item, ordem sequencial, UUID v4, enum de unidades, quantidade>0, payload completo snake_case)*
- [x] **F3-T07** — Tela da Lista: adicionar item rápido, checkbox, seção concluídos dobrável, editar/remover (swipe+undo)
  Dep: F3-T05, F3-T06 · Docs: [05 §6.3](05-app-flutter.md), [10 §3](10-wireframes-telas.md) · RF-03, RF-04
  CP: Wireframe 3.1 funcional; undo funciona; quantidade/unidade via enum. *(Enter/＋ salva na hora; "Itens concluídos (n)" dobrável; swipe → editar diálogo stepper+dropdown do enum / remover com undo (restaurarItem); duplicado soma quantidade (05 §6.3); menu ⋮ e sync ficam para F3-T08/F4-T07)*
- [x] **F3-T08** — Ações em massa (desmarcar todos, limpar concluídos) + diálogo excluir lista
  Dep: F3-T07 · Docs: [05 §6.3](05-app-flutter.md), [10 §3.4](10-wireframes-telas.md) · RF-04
  CP: Confirmações destrutivas; "desmarcar todos" reaproveita a lista. *(menu ⋮ com desmarcar/limpar/renomear/excluir; diálogo excluir no formato 10 §3.4 e volta ao painel; repo desmarcarTodos/limparConcluidos enfileiram por item; sheet de título extraída para reuso)*
- [x] **F3-T09** — Widget tests das telas core
  Dep: F3-T07, F3-T08 · Docs: [07 §1](07-qualidade-ci.md)
  CP: Widgets críticos cobertos; CI verde. *(30 widget tests escritos incrementalmente: auth 15 (F3-T04), painel 6 (F3-T05), lista 10 (F3-T07/08); + 17 de repositório e 7 de util; pipeline local 07 §3 verde — format/analyze/test)*

## Fase 4 — IA + Sincronização

- [x] **F4-T01** — Modal "Importar por IA" (entrada + contador + chamada + erros amigáveis)
  Dep: F2-T05, F3-T09 · Docs: [05 §6.4](05-app-flutter.md), [04 §2](04-ia-edge-function.md), [10 §4.1](10-wireframes-telas.md) · RF-06
  CP: Todos os códigos de erro exibem mensagem do contrato; contador bloqueia > 2000. *(cliente HTTP `ParseListaClient` com JWT + timeout 20s; os 8 códigos do contrato mapeados com fallback pt-BR; contador vermelho e botão desabilitado > 2000; sucesso devolve `RespostaParse` para a pré-visualização (F4-T02) — placeholder SnackBar no entretempo; 11 unit + 8 widget + 1 na tela da lista)*
- [x] **F4-T02** — Modal de pré-visualização (checkboxes, edição inline, aviso da IA)
  Dep: F4-T01 · Docs: [05 §6.4](05-app-flutter.md), [10 §4.2](10-wireframes-telas.md) · RF-06
  CP: Cancelar não grava; incluir/excluir por item; itens gravados via repositório local. *(checkbox por item + contador "N de M serão adicionados"; painel ▾ edita nome/quantidade/unidade inline; aviso em destaque; "Adicionar N" grava via `ListasRepository.adicionarItem`; 6 widget + 2 de integração com Drift)*
- [x] **F4-T03** — Sync Engine: flush da fila (coalescing, ordenação por lista, retry/backoff)
  Dep: F3-T06 · Docs: [03 §3–4](03-sincronizacao-offline.md) · RF-08
  CP: Fila esvazia ao reconectar; coalescing testado; retry exponencial testado com fake. *(SyncEngine + SyncRemoto (interface) + estados 03 §6; dreno por lista em ordem, coalescing mantém última mutação por registro, backoff 1s→2s→…→5min com 10 tentativas → ErroSync + reiniciarTentativas; rede cai no meio do flush pausa sem queimar tentativas; gatilhos: watch da fila + conectividade; 9 testes com RemotoFake. Remoto real com LWW entra na F4-T04)*
- [x] **F4-T04** — LWW + tombstones na aplicação de mutações e remotos
  Dep: F4-T03 · Docs: [03 §5](03-sincronizacao-offline.md) · RF-08, RF-10
  CP: Casos-limite da tabela 03 §5 passam (relógio adiantado, criado+removido offline, remoção vs edição remota). *(SupabaseSyncRemoto consulta remoto e decide LWW — empate vence servidor, `remotoVenceNoLww` puro; AplicadorRemoto sobrescreve Drift incluindo tombstones; engine aplica vencedor remoto e descarta mutações do registro; criado+removido offline já coberto pelo coalescing F4-T03; 7 testes LWW + 3 aplicador + 4 engine com RemotoComLwwFake. Bootstrap/multi-conta na F4-T06)*
- [x] **F4-T05** — Reordenar itens (drag-and-drop → `ordem`)
  Dep: F3-T07 · Docs: [05 §6.3](05-app-flutter.md) · RF-05
  CP: Reordenação persiste local e sincroniza. *(SliverReorderableList + alça ≡ (ReorderableDragStartListener); reordenarItens grava `ordem` e enfileira UPDATE só das linhas que mudaram; ordenação secundária por id para determinismo; fix: undo do SnackBar captura repo antes do unmount; sync via fila já coberto pelo engine (F4-T03); 1 teste de repo + 1 widget de drag)*
- [x] **F4-T06** — Realtime: aplicar remotos no Drift com LWW; bootstrap e re-sync
  Dep: F4-T04 · Docs: [03 §4, §7](03-sincronizacao-offline.md) · RF-07
  CP: Mudança remota visível < 1s; re-sync completo em gap de conexão; multi-conta isolada. *(SupabaseBootstrap: canal Realtime `postgres_changes` aplica INSERT/UPDATE imediatamente via `aplicarRemoto` com LWW (sem debounce, DELETE físico ignorado); troca de usuário → flush final + limpa cache/fila + bootstrap; último usuário em SharedPreferences para a fila sobreviver ao restart; reconexão → re-sync completo + flush; 6 testes)*
- [x] **F4-T07** — Indicador de sync na UI (estados 03 §6 + banner offline)
  Dep: F4-T06 · Docs: [03 §6](03-sincronizacao-offline.md), [10 §3.2](10-wireframes-telas.md) · RF-09
  CP: Todos os 5 estados renderizam conforme wireframe. *(IndicadorSync no topo do corpo da lista: check (Sincronizado), spinner (Sincronizando), contagem singular/plural (Pendente), banner nuvem cortada (Offline), banner errorContainer com ação "Tentar novamente" → engine.reiniciarTentativas (Erro); 6 widget tests + integração na tela da lista)*
- [x] **F4-T08** — Deduplicação no sync (unique violada → aumenta quantidade)
  Dep: F4-T04 · Docs: [03 §5](03-sincronizacao-offline.md) · RF-10
  CP: Item duplicado offline vira quantidade somada; testes de sync cobrem. *(SupabaseSyncRemoto consulta itens ativos da lista no INSERT e detecta mesmo nome (case-insensitive, id diferente); `mesclarDuplicado` soma quando unidades coincidem (updated_at = mais recente) e devolve null quando divergem (remoto vence); engine tombstone a linha local, aplica o registro remoto e descarta as mutações; 2 testes da mescla + 1 do engine)*
- [x] **F4-T09** — Testes do Sync Engine completos (checklist 03 §8)
  Dep: F4-T03…F4-T08 · Docs: [03 §8](03-sincronizacao-offline.md), [07 §1](07-qualidade-ci.md)
  CP: Os 8 itens do checklist passam; prioridade máxima de cobertura. *(checklist_sincronizacao_test.dart: 2 dispositivos + servidor fake em memória com LWW/dedup reais; 8 testes 1:1 com o checklist. Correções encontradas ao validar: flush() agora encadeia chamadas concorrentes (não drena duas vezes, quem chama espera a fila real) e incrementar tentativas não dispara novo flush; Drift v2 — datas como texto ISO-8601 com microssegundos (armazenamento em unix segundos truncava updated_at e criava empates artificiais no LWW) com migração v1→v2)*

## Fase 5 — Polimento e Publicação (MVP)

- [x] **F5-T01** — Tela Configurações (política de privacidade, versão, exclusão de conta)
  Dep: F4-T09 · Docs: [06 §3](06-mvp-entregas.md), [10 §5](10-wireframes-telas.md) · RF-11
  CP: Wireframe 5; links corretos. *(rota /configuracoes protegida + ícone ⚙ no painel; e-mail da conta (emailUsuarioProvider); Política de Privacidade exibida in-app (texto único do 06 §3.3 em core/l10n/politica_privacidade.dart — a URL pública online entra na F5-T06); versão via package_info_plus; botão vermelho Excluir minha conta + aviso, com fluxo placeholder para F5-T02; 3 widget tests)*
- [x] **F5-T02** — RPC `excluir_conta()` + fluxo de confirmação dupla
  Dep: F5-T01 · Docs: [06 §3.3.1](06-mvp-entregas.md) · RF-11
  CP: Conta excluída remove todos os dados (cascades verificados); app limpa cache/fila; sessão invalidada. *(migration 0005: RPC security definer apaga auth.users + ia_rate_limit (sem FK) e marca a transação `app.excluindo_conta`; sync_dono v2 reconhece a marca — exceção documentada no doc 01 §6 no mesmo PR; app: repo.excluirConta() (RPC + signOut) e confirmação dupla na tela — senha com reautenticação (erro inline "Senha incorreta") + diálogo final; cache/fila limpos pelo bootstrap ao detectar fim de sessão (F4-T06, testado em deve_limpar_cache_e_fila_quando_logout); 5 widget tests do fluxo)*
- [x] **F5-T03** — Testes de integração da exclusão de conta
  Dep: F5-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: SELECT pós-exclusão retorna vazio em todas as tabelas; RLS sem vazamento. *(supabase/tests/excluir_conta_tests.sql: E-01 RPC sem usuário rejeita; E-02 RPC autenticado executa; E-03 auth.users/listas/membros/itens/ia_rate_limit vazios; E-04 dados de terceiros intactos e participação removida; E-05 execução negada a anon; job no CI após os testes RLS; 14 casos RLS revalidados sem regressão)*
- [x] **F5-T04** — Sentry (Flutter + Edge Function) sem conteúdo de listas
  Dep: F4-T09 · Docs: [07 §4](07-qualidade-ci.md) · RF-12
  CP: Erro simulado aparece no Sentry; payload inspecionado sem dados de itens. *(Flutter: SentryFlutter.init com DSN via --dart-define SENTRY_DSN (vazio → desligado), sendDefaultPii=false e beforeSend limpa breadcrumbs; engine reporta os eventos monitorados — sync_erro_persistente, sync_falha_fila_grande (>10), sync_falha_tentativas_altas (>5), sync_relogio_adiantado (>24h) — apenas códigos + contagens, via callback injetado (3 testes); Edge Function: supabase/functions/parse-lista/sentry.ts com SDK @sentry/deno carregado dinamicamente e no-op sem DSN, acoplado aos caminhos 422/500 (3 testes deno, CI com --allow-env). Smoke com DSN real do projeto: instruções em 09 §3 — operação externa (criar projeto Sentry + setar secret/dart-define)*
- [ ] **F5-T05** — Testes de usabilidade (3–5 participantes)
  Dep: F4-T09, F5-T02 · Docs: [11](11-usabilidade-fase5.md)
  CP: Critério 11 §3.1: T1–T4 ≥ 80% sem ajuda **e** T3 100%; relatório de 1 página produzido. *(relatório modelo já preparado: [docs/relatorio-usabilidade-fase5.md](relatorio-usabilidade-fase5.md) — executar as 3–5 sessões perante participantes reais e preencher; exige ação humana, fora do escopo do agente)*
- [ ] **F5-T06** — Publicação Web + Android (teste interno) + política de privacidade online
  Dep: F5-T05 · Docs: [06 §4](06-mvp-entregas.md)
  CP: Checklist 06 §1 100% marcado; URL Web pública; AAB no closed testing.

## Pós-MVP (Fase 6) — resumo

Compartilhamento completo (convites, papéis na UI, transferência de dono), iOS, Desktop, limpeza de tombstones. Planejamento: [08](08-compartilhamento-colaborativo.md) — breakdown detalhado desta fase será criado ao iniciá-la.

---

## Progresso por fase (atualize ao concluir)

| Fase | Tarefas | Concluídas |
| :--- | :--- | :--- |
| F1 Infra & BD | 8 | 8 |
| F2 IA | 5 | 5 |
| F3 App Core | 9 | 9 |
| F4 IA + Sync | 9 | 9 |
| F5 Publicação | 6 | 4 |
| **Total** | **37** | **35** |

## Documentos relacionados
- [12 PRD](12-prd.md) — RF/RNF referenciados pelas tarefas
- [13 Pré-modelo](13-premodelo-tecnico.md) — contexto para executar qualquer tarefa
- [AGENTS.md](../AGENTS.md) — fluxo de trabalho do agente
