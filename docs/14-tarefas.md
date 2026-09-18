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

## Fase 2 — Serviço de IA (Edge Function) — **removida na F17**

- [x] **F2-T01** — Migration tabela `ia_rate_limit` + função de janela
  Dep: F1-T08 · Docs: [04 §4](04-importacao-lista.md)
  CP: 11ª requisição na mesma janela retorna 429.
- [x] **F2-T02** — Estrutura da função `parse-lista` + `prompt.md` versionado
  Dep: F1-T08 · Docs: [04 §5, §8](04-importacao-lista.md)
  CP: Pasta conforme 04 §8; prompt rascunho revisado; secret `GEMINI_API_KEY` configurada via CLI.
- [x] **F2-T03** — Integração Gemini (JSON mode + responseSchema + timeout 15s)
  Dep: F2-T02 · Docs: [04 §3, §6](04-importacao-lista.md)
  CP: Resposta parseada como `{itens[], aviso}`; teste real com 3 exemplos de lista bagunçada. *(modelo migrado para `gemini-3.5-flash-lite` — ver doc 04 §3)*
- [x] **F2-T04** — Validação (zod) e códigos de erro do contrato
  Dep: F2-T03 · Docs: [04 §2, §7](04-importacao-lista.md)
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

## Fase 4 — Sincronização

- [x] **F4-T01** — Modal "Importar lista" (entrada + contador + parser local + erro amigável)
  Dep: F2-T05 (histórico — removida na F17), F3-T09 · Docs: [05 §6.4](05-app-flutter.md), [04](04-importacao-lista.md), [10 §4.1](10-wireframes-telas.md) · RF-16
  CP: erro do parser com mensagem amigável; contador bloqueia > 10.000. *(modal de importação com contador e erro amigável; extração pelo parser local (F11); a etapa de IA foi removida na F17)*
- [x] **F4-T02** — Modal de pré-visualização (checkboxes, edição inline, aviso)
  Dep: F4-T01 · Docs: [05 §6.4](05-app-flutter.md), [10 §4.2](10-wireframes-telas.md) · RF-16
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
  CP: Wireframe 5; links corretos. *(rota /configuracoes protegida + ícone ⚙ no painel; e-mail da conta (emailUsuarioProvider); Política de Privacidade exibida in-app (texto único do 06 §3.3 em core/l10n/politica_privacidade.dart — a URL pública online entra na Fase 19 (ADR-013)); versão via package_info_plus; botão vermelho Excluir minha conta + aviso, com fluxo placeholder para F5-T02; 3 widget tests)*
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
  CP: Critério 11 §3.1: T1–T4 ≥ 80% sem ajuda **e** T3 100%; relatório de 1 página produzido. *(ADIADA por decisão do dono: executar somente sob solicitação explícita — só quando for lançar. Relatório modelo pronto em [docs/relatorio-usabilidade-fase5.md](relatorio-usabilidade-fase5.md); exige participantes humanos, fora do escopo do agente)*
- [x] **F5-T05b** — Distribuição interna via Firebase App Distribution
  Dep: F4-T09 · Docs: [06 §4](06-mvp-entregas.md)
  CP: APK release assinado, instalável por 2+ testadores apontando para o Supabase de produção; keystore via `android/key.properties` (gitignored, template em `key.properties.example`) com fallback para debug quando ausente. *(fora do gate de T05/T06 — é o canal provisório de builds de teste até o lançamento. Build `1.0.0+2` assinado (V2, CN=Lucas Oliveira), URL de produção verificada embutida no libapp.so e smoke no emulador: instala, abre e login com credenciais erradas devolve "E-mail ou senha incorretos" da produção. Distribuído ao grupo "testadores" (2 membros) via `firebase appdistribution:distribute --groups`; dart-defines de produção em `dart_defines_prod.json` (gitignored). Correções de CI no caminho: Flutter 3.44.5 e CLI 2.116.0 pinados, e2e cria usuários via Admin API (confirmations F3) — doc 07 §3 e 04 §8 atualizados)*
- [ ] **F5-T06** — Publicação Android (teste interno) + política de privacidade na Play
  Dep: F5-T05 · Docs: [06 §4](06-mvp-entregas.md)
  CP: Checklist 06 §1 100% marcado; AAB no closed testing; Declaração de Dados preenchida. *(ADIADA por decisão do dono: executar somente sob solicitação explícita — só quando for lançar na Play Store; a publicação Web foi entregue pela Fase 19 (ADR-013); Dep F5-T05 permanece)*

## Fase 6 — Pós-MVP

Spec do agrupamento por categoria: [superpowers/specs/2026-09-08-agrupamento-categorias-design.md](superpowers/specs/2026-09-08-agrupamento-categorias-design.md) · Requisito: RF-15 · ADR-011.

- [x] **F6-T00** — Spec + docs de planejamento (RF-15, ADR-011, campos no 13, breakdown no 14)
  Dep: — · Docs: spec da feature
  CP: docs de planejamento consistentes entre si (00/12/13/14/spec) sem tocar código.
- [x] **F6-T01** — Migration `0006_categorias.sql`: enum `categoria_item` (11 valores) + coluna em `itens_lista`
  Dep: F6-T00 · Docs: [01 §3, §4.3, §8](01-banco-de-dados.md)
  CP: `enum_range` retorna os 11 valores na ordem dos grupos; INSERT com categoria inválida rejeita; INSERT sem categoria → `outros`; `db reset` e `db push` ok.
- [x] **F6-T02** — Drift v3 (`ItemLocal.categoria`) + repositório com categoria no payload
  Dep: F6-T01 · Docs: [05 §2–3](05-app-flutter.md), [03 §3](03-sincronizacao-offline.md)
  CP: migração v2→v3 preserva dados; adicionar/editar grava categoria e enfileira payload com `categoria`; 145 testes atuais verdes + novos de repo.
- [x] **F6-T03** — Cadeia de sugestão local (memória por nome → dicionário estático → `outros`)
  Dep: F6-T02 · Docs: [05 §3](05-app-flutter.md)
  CP: função pura; memória vence dicionário; match multi-palavra vence single ("leite condensado" → mercearia); fallback `outros`; unit tests dos 4 casos.
- [x] **F6-T04** — UI: grupos por categoria, contagem, drag interno, dropdown no editar
  Dep: F6-T02, F6-T03 · Docs: [05 §6.3](05-app-flutter.md), [10 §3](10-wireframes-telas.md)
  CP: wireframe atualizado atendido; headers `Label (n)` na ordem do enum; drag só dentro do grupo; Enter aplica sugestão; concluídos sem grupos; widget tests.
- [x] **F6-T05** — Categoria sugerida no import (cadeia local + pré-visualização editável)
  Dep: F6-T02 · Docs: [04](04-importacao-lista.md)
  CP: enum dos 11 valores na pré-visualização; sugestão local em camadas; testes verdes.
  *(A etapa de servidor/IA desta tarefa foi removida na F17.)*
- [x] **F6-T06** — Checklist sync [03 §8](03-sincronizacao-offline.md) com categoria + distribuição nova
  Dep: F6-T02, F6-T05 · Docs: [03 §8](03-sincronizacao-offline.md), [07 §1](07-qualidade-ci.md)
  CP: cenário de categoria entre 2 dispositivos (servidor fake) verde; CI verde; APK `1.1.0+3` distribuído ao grupo `testadores` (história em [09 §2.6](09-runbook-operacoes.md)).

### Pós-MVP (Fase 7) — Compartilhamento por link (spec aprovada)

Spec: [superpowers/specs/2026-09-10-compartilhamento-link-design.md](superpowers/specs/2026-09-10-compartilhamento-link-design.md) · Requisito: RF-13 · Doc dono: [08](08-compartilhamento-colaborativo.md) (decisões em §1.1).

- [x] **F7-T00** — Spec + ajustes nos docs de planejamento (08 §1.1, campo no 13, breakdown no 14)
  Dep: — · Docs: spec da feature
  CP: docs de planejamento consistentes entre si (00/12/13/14/spec) sem tocar código.
  Nota: *(spec aprovada + decisões em 08 §1.1 + break plan; commits 835cf26, c76d79e)*
- [x] **F7-T01** — Migration `0007_convites.sql`: tabela, RLS, RPC `aceitar_convite`, publication
  Dep: F7-T00 · Docs: [08 §2–§3.1, §7](08-compartilhamento-colaborativo.md), [02 §5](02-seguranca-rls.md)
  CP: policies de convites criadas; aceitar link pendente entra no `lista_membros`; expirado/revogado → `CONVITE_INVALIDO`; 2º aceite idempotente; N-11…N-14 em `supabase/tests/rls_tests.sql` + testes do RPC; `db reset` e CI verde.
  Nota: casos A-01…A-07 em `supabase/tests/aceitar_convite_tests.sql` (idempotência, expiração, revogação, anon rejeitado, caminho de e-mail). RPC recebe guarda de anonimato (A-05) e mantém estado `aceito` aceitável (idempotência/§9) — desvios documentados no 08 §3.1 no mesmo PR; helper `email_autenticado` + policies de `convites` documentados no 02 §1/§4.4.
- [x] **F7-T02** — `ConvitesRepository` (criar link, listar pendentes, revogar, aceitar via RPC) + papel no bootstrap
  Dep: F7-T01 · Docs: [08 §3](08-compartilhamento-colaborativo.md), [03 §4](03-sincronizacao-offline.md)
  CP: chamadas diretas ao servidor (sem fila); códigos de erro mapeados em pt-BR; papel do usuário disponível nas consultas do app; unit tests com fake.
  Nota: *(ConvitesRepository com criarLink/revogar/pendentes/mudarPapel/removerMembro/sairDaLista/aceitar (RPC `aceitar_convite`; códigos CONVITE_* e falha de rede mapeados em pt-BR); `Papel`, `Convite`, `MembroLista`, `ErroConvite`; PapelRepository fora do Drift, injetado no bootstrap (carga antes do download das tabelas, limpeza no logout) + `papelNaListaProvider`; 17 testes com ServidorFake HTTP — commits 8635873, 6a2d0bd)*
- [x] **F7-T03** — UI: sheet "Convidar" (dono) + tela de membros (trocar papel, remover, sair da lista)
  Dep: F7-T02 · Docs: [08 §5, §8](08-compartilhamento-colaborativo.md), [10 §4](10-wireframes-telas.md)
  CP: link gerado com papel; copiar/compartilhar scheme + copiar token; troca editor↔leitor; remover membro com confirmação destrutiva; "sair da lista" para não-dono; widget tests.
  Nota: *(sheet Convidar com seleção de papel (radios Editor/Leitor), link com copiar e compartilhar — `SharePlus.share` na share_plus 12.x (`Share.share` removido), pin atualizado no pubspec; tela de membros com chip de papel, "Você", troca editor↔leitor, remover com confirmação destrutiva e "Sair da lista" para não-dono; gate de "Sair" no loading, copiar token/código colado no painel; "Convidar" dono-only e "Membros" para todos no menu ⋮; papel reativo via `papelNaListaStreamProvider` com fallback síncrono; widget tests — commits 1e9051c, 6e1e640)*
- [x] **F7-T04** — Banner "Você é leitor" + bloqueio de ações de escrita na tela da lista
  Dep: F7-T02 · Docs: [08 §1, §8](08-compartilhamento-colaborativo.md), [05 §6.3](05-app-flutter.md)
  CP: leitor vê banner somente leitura; checkbox/menu/swipe/＋ desabilitados; widget tests do bloqueio por papel.
  Nota: *(banner "Somente leitura" no topo para leitor; sem campo adicionar, IA, checkbox, swipe (sem Dismissible) nem alça de drag; menu reduzido; default conservador (trata como leitor) quando papel não carregado; editor escreve, "Convidar" e "excluir lista" dono-only; 4 widget tests por papel — commit 832fbc3)*
- [x] **F7-T05** — Rota `/entrar?token=` (deep link scheme) + "Entrar com código" + retomada pós-login
  Dep: F7-T02 · Docs: [08 §3](08-compartilhamento-colaborativo.md), [05 §4](05-app-flutter.md)
  CP: link abre o app (não autenticado → login com contexto "Você foi convidado..." e retoma o aceite); token válido navega à lista; expirado/revogado → erro amigável; já membro → só navega; token colado funciona igual; widget tests dos estados.
  Nota: *(rota pública `/entrar` excluída do redirect de autenticação; sem sessão → contexto "Você foi convidado..." com Entrar/Criar conta e `?next=` para retomada pós-login; com sessão o aceite roda o RPC e navega a `/lista/:id`; expirado/revogado → erro amigável + "Tentar novamente" (idempotente); intent-filter host `entrar` + ponte deeplinkConviteProvider (app_links) — supabase_flutter só captura callbacks de auth com access_token/code (verificado no fonte do package); "Entrar com código" no painel (token colado, mesmo caminho `aceitar`); 12 widget tests. Deep link físico pendente de dispositivo (sem emulador na sessão) — smoke ficou responsabilidade do F7-T07; commits d46ef91, 2463c4b)*
- [x] **F7-T06** — Realtime `lista_membros`: papel ao vivo, entrada de membro e perda de acesso < 5s
  Dep: F7-T02 · Docs: [08 §5, §7](08-compartilhamento-colaborativo.md), [03 §7](03-sincronizacao-offline.md)
  CP: INSERT → "membro entrou"; UPDATE papel → papel local atualiza; DELETE do próprio usuário → flush + limpa cache/fila + refetch de listas (padrão F4-T06); remoção refletida < 5s no device removido; teste com canal fake no estilo `checklist_sincronizacao_test.dart`.
  Nota: *(função pura `aplicarEventoMembro` + roteamento por tabela no callback de `_assinarRealtime`: INSERT/UPDATE próprios atualizam o papel, DELETE próprio → flush + limpa cache/fila + re-sync (padrão F4-T06); eventos de `lista_membros` jamais passam pelo motor LWW (sem `updated_at`); migration 0008 replica identity full em `lista_membros` fora do plan — necessária para o `old_record` do DELETE chegar com `user_id` — doc 08 §7 atualizado no mesmo PR; testes com CanalFake + stream de papel; validação física < 5s pendente de 2 dispositivos; commit 3d57d07)*
- [x] **F7-T07** — Checklist de validação 08 §9 (recorte link-only) + CI verde + distribuição aos testadores
  Dep: F7-T03, F7-T04, F7-T05, F7-T06 · Docs: [08 §9](08-compartilhamento-colaborativo.md), [07 §1](07-qualidade-ci.md)
  CP: itens 1, 2→(adaptado a link), 4, 5, 6 e 8 do checklist verificados; APK `1.1.1+4` (ou próximo) via App Distribution; histórico em [09 §2.6](09-runbook-operacoes.md).
  Nota: *(itens 1, 2, 3(idempotência), 4, 6 e 8 do recorte verificados por suites SQL (N-01…N-17, E-01…E-05, A-01…A-07) + 223 testes Flutter; itens 1 e 5 físicos pendentes de 2 dispositivos; final review corrigiu RLS faltante (migration 0009: dono muda papel + membro sai — antes eram no-ops silenciosos), whitelist de tabelas no realtime, feedback "membro entrou" e limpeza local no sair; migrations 0007–0009 aplicadas em produção via `db push`; APK `1.1.2+5` distribuído ao grupo `testadores`)*

### Pós-MVP (Fase 7) — pendente de planejamento

Convite por e-mail transacional (Fluxo B + Edge Function `enviar-convite`), transferência de dono (RF-14), universal links (pós-F5-T06), iOS, Desktop, limpeza de tombstones.

## Fase 8 — Revisão Visual e de UX (spec em [superpowers/specs](superpowers/specs/2026-09-11-revisao-visual-ux-design.md))

- [x] **F8-T00** — Spec + ajustes de docs de planejamento
  Dep: — · Docs: spec da fase
  CP: docs 15/05/10/00/12/13/14/index/AGENTS consistentes entre si, sem tocar código.
- [x] **F8-T01** — Tokens + `AppTheme` claro/escuro + fonte bundlada + cores semânticas + seletor de tema
  Dep: F8-T00 · Docs: [15](15-design-system.md) · RNF-06
  CP: tema claro/escuro com paridade, extensão semântica presente, fonte Plus Jakarta Sans aplicada, modo persistido; `analyze`/`test` verdes.
- [x] **F8-T02** — Biblioteca de componentes (`App*`) + catálogo `/design`
  Dep: F8-T01 · Docs: [15 §3](15-design-system.md)
  CP: componentes do doc 15 renderizam em claro/escuro; catálogo em `kDebugMode`.
- [x] **F8-T03** — Testes dos componentes + CI verde
  Dep: F8-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: widget tests dos componentes e do seletor; `format`/`analyze`/`test` verdes.

## Fase 9 — Refresh Visual das Telas (spec em [superpowers/specs](superpowers/specs/2026-09-11-revisao-visual-ux-etapa2-design.md))

- [x] **F9-T00** — Spec + plano + fase nos docs
  Dep: F8-T03 · Docs: spec da fase
  CP: spec/plano registrados; fase 9 em 14/14 sem tocar código de app.
- [x] **F9-T01** — Auth (login/registro/recuperar) com componentes/tokens
  Dep: F9-T00 · Docs: [15](15-design-system.md) · RNF-06
  CP: campos/botões/banners padronizados; tooltip no toggle; strings centralizadas; testes verdes.
- [x] **F9-T02** — Minhas Listas com `AppCard`/`AppEstadoVazio`/`AppEstadoErro`/`AppDialog`
  Dep: F9-T01 · Docs: [15](15-design-system.md)
  CP: card/vazio/erro/destrutivo padronizados; testes verdes.
- [x] **F9-T03** — Indicador de sync com `AppBanner`
  Dep: F9-T01 · Docs: [15](15-design-system.md)
  CP: offline/erro com contraste correto; testes verdes.
- [x] **F9-T04** — Tela da lista (banners, estados, destrutivo, strings/cores)
  Dep: F9-T02, F9-T03 · Docs: [15](15-design-system.md), [10](10-wireframes-telas.md)
  CP: banners/estados/cores/strings padronizados; testes verdes.
- [x] **F9-T05** — Modal de importação (aviso, botões, strings)
  Dep: F9-T01 · Docs: [15](15-design-system.md)
  CP: aviso via `AppBanner`; botões/strings padronizados; testes verdes.
- [x] **F9-T06** — Configurações (cabeçalho, destrutivo, sheet)
  Dep: F9-T02 · Docs: [15](15-design-system.md)
  CP: cabeçalho/botão/sheet padronizados; testes verdes.
- [x] **F9-T07** — Convites e membros (chip, botões, sheet, a11y)
  Dep: F9-T02 · Docs: [15](15-design-system.md)
  CP: chip ≥48dp; tooltips; confirmações destrutivas; testes verdes.
- [x] **F9-T08** — Acessibilidade, doc 10 e fechamento
  Dep: F9-T01…F9-T07 · Docs: [10](10-wireframes-telas.md), [07 §1](07-qualidade-ci.md)
  CP: `format`/`analyze`/`test` verdes; wireframes sincronizados; fase marcada.

## Fase 10 — Redesign de Navegação (spec em [superpowers/specs](superpowers/specs/2026-09-11-revisao-visual-ux-etapa3-design.md))

- [x] **F10-T00** — Spec + plano + fase nos docs
  Dep: F9-T08 · Docs: spec da fase
  CP: spec/plano registrados; fase 10 em 14 sem tocar código de app.
- [x] **F10-T01** — Split Minhas × Compartilhadas (`PainelListas` + telas)
  Dep: F10-T00 · Docs: [05 §6.2](05-app-flutter.md), [15](15-design-system.md)
  CP: Minhas = listas do dono; Compartilhadas = listas de membro; testes verdes.
- [x] **F10-T02** — `AppShell` (NavigationBar/Rail) + rotas por shell + logout em Configurações
  Dep: F10-T01 · Docs: [05 §4](05-app-flutter.md)
  CP: 3 destinos com estado preservado; rota protegida; logout em Configurações; testes verdes.
- [x] **F10-T03** — Testes de navegação, doc 10 e fechamento
  Dep: F10-T02 · Docs: [10](10-wireframes-telas.md), [07 §1](07-qualidade-ci.md)
  CP: `format`/`analyze`/`test` verdes; wireframes sincronizados; fase marcada.
- [x] **F10-T04** — Correção: associação do dono ao criar lista
  Dep: F10-T03 · Docs: [01 §6](01-banco-de-dados.md), [02 §1/§3](02-seguranca-rls.md) · Bug: dono virava leitor
  CP: migration `0010_dono_automatico.sql` (trigger + backfill) em produção; papel local imediato no cliente; suites SQL (com P-08) e `flutter test` verdes.
- [x] **F10-T05** — Correção: papel por propriedade, membros e reparo do dono
  Dep: F10-T04 · Docs: [02 §3](02-seguranca-rls.md), [08 §5](08-compartilhamento-colaborativo.md)
  CP: `papelEfetivoProvider` deriva dono de `listas.dono_id` (offline/após reinício); tela de membros mescla o dono local e refaz o fetch ao abrir; migration `0011_dono_repair.sql` (trigger + backfill idempotente) em produção; botão "Importar lista" com SafeArea + mais respiro inferior; `analyze`/`test` verdes.
- [x] **F10-T06** — Navegação: push sobre o shell, voltar por origem e títulos
  Dep: F10-T03 · Docs: [05 §4/§5](05-app-flutter.md), [10 §2/§3](10-wireframes-telas.md) · Spec: [navegacao-titulos](superpowers/specs/2026-09-11-navegacao-titulos-design.md)
  CP: abrir lista/membros por `push` retorna à aba de origem (seta e voltar do Android); sem pilha cai em `/listas`/`/compartilhadas`; aba e AppBar "Configurações"; membros com `Membros · {lista}`; estados da lista com título; `analyze`/`test` verdes; APK `1.2.0+6` distribuído ao grupo `testadores` (App Distribution).

---

## Fase 11 — Importação de lista (spec em [superpowers/specs](superpowers/specs/2026-09-11-importacao-local-design.md))

- [x] **F11-T00** — RF-16 + docs de planejamento
  Dep: F10-T04 · Docs: spec da fase
  CP: RF-16 no 12; 05 §6.4, 10 §4.1 e 04 §1 atualizados; Fase 11 no 14; sem tocar código de app.
- [x] **F11-T01** — Tipos de importação, normalizador e parser local
  Dep: F11-T00 · Docs: [05 §3/§6.4](05-app-flutter.md), [01 §3](01-banco-de-dados.md)
  CP: parser puro com unit tests dos casos da spec §8; imports atualizados; `analyze`/`test` verdes.
- [x] **F11-T02** — Modal de importação + pré-visualização (nomes genéricos)
  Dep: F11-T01 · Docs: [05 §6.4](05-app-flutter.md), [10 §4](10-wireframes-telas.md)
  CP: modo local offline (RF-16); botão "Importar lista"; testes verdes.
- [x] **F11-T03** — Verificação final, docs e CI
  Dep: F11-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: `format`/`analyze`/`test` verdes; fase marcada.

---

## Fase 12 — Correções (pós-F11)

Correções pontuais reportadas pelo dono: legibilidade no tema escuro e geração
do link de convite. Docs donos: [15](15-design-system.md) (tema),
[08](08-compartilhamento-colaborativo.md) (convites),
[03](03-sincronizacao-offline.md) (sync).

- [x] **F12-T01** — Tema escuro: `TextTheme` por brilho/`ColorScheme` (textos ilegíveis)
  Dep: F9-T08 · Docs: [15 §1–2, §4](15-design-system.md) · RNF-06
  CP: `AppTypography.textTheme(brightness, scheme)` deriva as cores do `ColorScheme` (claro → escuro; escuro → claro); teste de contraste em claro/escuro; `analyze`/`test` verdes.
- [x] **F12-T02** — Compartilhamento: erros amigáveis + pré-condição ao gerar link
  Dep: F7-T07 · Docs: [08 §3/§8](08-compartilhamento-colaborativo.md) · RF-13
  CP: `criarLink` mapeia FK (`23503`)/RLS (`42501`) → `lista_nao_sincronizada` e rede → `sem_conexao`; sheet faz flush best-effort da fila antes de gerar; testes de repo (4) e de sheet (2) verdes.
- [x] **F12-T03** — Robustez do sync: assinatura da fila e cadeia do bootstrap
  Dep: F4-T09 · Docs: [03 §4/§7](03-sincronizacao-offline.md) · RF-08, RF-09
  CP: `SyncEngine.iniciar()` assina a fila antes da checagem de conexão (falha não impede flush); `SupabaseBootstrap._encadear` descarta erro do trabalho para não envenenar a cadeia; 2 testes novos verdes.
- [x] **F12-T04** — Sync: INSERT/UPDATE em vez de `upsert` + policy `listas_update_editores`
  Dep: F12-T03 · Docs: [03 §4](03-sincronizacao-offline.md), [02 §4.1](02-seguranca-rls.md) · RF-08
  CP: `SupabaseSyncRemoto.enviar` usa `INSERT` sem linha remota e `UPDATE` com linha remota; migration `0012_fix_listas_update_policy.sql` corrige o `WITH CHECK` (`l.id = listas.id`) aplicada em produção; 3 testes do `enviar` verdes; INSERT/UPDATE validados em produção (201/204).
- [x] **F12-T05** — Visual: espaçamento entre os cards de listas
  Dep: F10-T01 · Docs: [10 §2.1](10-wireframes-telas.md), [15 §3](15-design-system.md) · RNF-06
  CP: `PainelListas` separa os cards com `AppSpacing.sm` (`ListView.separated`); teste de regressão mede o vão entre dois cards; `analyze`/`test` verdes.
- [x] **F12-T06** — Tela da lista: unidade no add manual, parse do texto e editar/remover descobrível
  Dep: F11-T01 · Docs: [05 §6.3](05-app-flutter.md), [10 §3.1](10-wireframes-telas.md) · RF-03, RF-04, RF-16
  CP: seletor de unidade no campo; `interpretarItemAvulso` reconhece `1kg de banana` (unidade explícita vence o seletor); duplicado soma se unidade igual, senão atualiza; tocar no item abre o editor com **Remover** (undo); 5 testes de tela + 6 do parser verdes.
- [x] **F12-T07** — SnackBar com duração curta
  Dep: F12-T06 · Docs: [15 §3](15-design-system.md) · RNF-06
  CP: `mostrarSnackBar` usa 2s sem ação e 3s com ação (`duracao` sobrescreve); 2 testes do widget verificam as durações.

---

## Fase 13 — Identidade visual (logo + títulos)

Marca própria do app e ajuste dos títulos de tela. Doc dono:
[15 §1/§3/§6](15-design-system.md); layout em [10](10-wireframes-telas.md);
UX em [05](05-app-flutter.md).

- [x] **F13-T01** — Logo do app: ícones, splash e web
  Dep: F9-T08 · Docs: [15 §6](15-design-system.md) · RNF-06
  CP: masters `assets/branding/logo.svg`/`logo_glyph.svg` + PNGs 1024; `flutter_launcher_icons` gera ícones Android (incl. adaptativo)/iOS/web e `flutter_native_splash` o splash verde; `web/manifest.json`/`index.html` com nome/cores da marca; teste garante o asset no bundle.
- [x] **F13-T02** — Marca no cabeçalho das telas de topo
  Dep: F13-T01 · Docs: [15 §3](15-design-system.md), [10 §2.1](10-wireframes-telas.md), [05 §6.2](05-app-flutter.md) · RNF-06
  CP: `AppLogo` (28dp, `AppRadius.sm`, `Semantics` com o nome do app) à esquerda do título no painel; telas internas sem a marca; testes de widget verdes.
- [x] **F13-T03** — Títulos de tela: 24sp bold
  Dep: F9-T08 · Docs: [15 §1](15-design-system.md) · RNF-06
  CP: `appBarTheme.titleTextStyle` com `fontSize: 24` e `FontWeight.bold` (tokens em `AppTypography`), claro/escuro; teste verifica tamanho e peso.

---

## Fase 14 — Acessibilidade, fluxos e polimento de UX

Spec: [superpowers/specs/2026-09-14-ux-acessibilidade-design.md](superpowers/specs/2026-09-14-ux-acessibilidade-design.md) · Docs donos: [15](15-design-system.md) (a11y/componentes), [05](05-app-flutter.md) (UX/rotas), [10](10-wireframes-telas.md) (layout), [08](08-compartilhamento-colaborativo.md) (membros), [12](12-prd.md) (RF-01/RNF-06).

- [x] **F14-T00** — Spec + docs de planejamento
  Dep: F13-T03 · Docs: spec da fase
  CP: spec aprovada; `15 §3/§4`, `05 §4/§6/§7`, `10`, `08 §5/§8`, `12` e `14` consistentes entre si; sem tocar código de app.
- [x] **F14-T01** — Semântica nos componentes `App*`
  Dep: F14-T00 · Docs: [15 §3/§4](15-design-system.md) · RNF-06
  CP: `AppEstadoVazio` com rótulo único (título + descrição; ação em nó próprio), `AppBanner` com `liveRegion` em erro/aviso/offline e `AppBotao(carregando)` anunciando progresso em nó próprio; `AppEstadoErro` e `mostrarSnackBar` já conformes (sem mudança); `test/core/widgets/acessibilidade_test.dart` com semântica + `meetsGuideline(labeledTapTargetGuideline)`/`androidTapTargetGuideline` verde (6 testes).
- [x] **F14-T02** — Acessibilidade nas telas + escala de fonte
  Dep: F14-T01 · Docs: [15 §4](15-design-system.md) · RNF-06
  CP: `IndicadorSync` com live region e ícones ≥16dp (3 testes); `Checkbox` do item rotulado com o nome (`MergeSemantics`, 1 teste); `tooltip` pt-BR no menu de membros (1 teste); escala de texto 2.0 sem overflow em login/painel/lista (3 testes-guarda, com o overflow comprovadamente detectável). `Icon`/fundos do `Dismissible` já excluem a si mesmos — sem mudança.
- [x] **F14-T03** — Recuperação de senha: tela de nova senha (RF-01)
  Dep: F14-T00 · Docs: [05 §4/§6.1](05-app-flutter.md), [10 §1.3](10-wireframes-telas.md) · RF-01
  CP: rota pública `/redefinir-senha`; `redefinindoSenhaProvider` reage a `passwordRecovery` (assinado antes do refresh do router — corrida de listeners coberta por teste) e força o redirect; nova senha + confirmação com toggle (strings órfãs usadas); sucesso → SnackBar "Senha alterada" + `/listas` e flag limpo; erro (`AuthException`) → banner + "Pedir novo link" → `/recuperar-senha`; 4 testes de tela/rota verdes.
- [x] **F14-T04** — Estados vazios, de erro e transições
  Dep: F14-T00 · Docs: [15 §3](15-design-system.md), [10 §3/§4/§6](10-wireframes-telas.md)
  CP: erro da lista com `AppEstadoErro` + retry (invalida `listaPorIdProvider`) e "não encontrada" com CTA; vazios em membros (sem cache → instrução, sem ações — papel não confiável) e na pré-visualização com 0 itens ("Nada foi reconhecido" + "Voltar e editar" sem rodapé/botão); `/entrar` sem tela em branco e com AppBar no carregando (estados transientes, sem teste dedicado). Vazio do leitor já conforme (no-op). 4 testes novos verdes.
- [x] **F14-T05** — Feedback de ação
  Dep: F14-T00 · Docs: [05 §6](05-app-flutter.md), [08 §5](08-compartilhamento-colaborativo.md)
  CP: SnackBars de reenviar link/compartilhar/papel/remover membro/criar-renomear lista; undo em "limpar concluídos" (restaura `id`/`ordem`); "Sair" com confirmação destrutiva; testes verdes.
  *(reenviar link com "Link reenviado" + erro amigável e botão desabilitado durante o envio; compartilhar convite com "Link compartilhado"; papel/remoção de membro com SnackBar; criar/renomear lista com SnackBar 2s via `mensagemSucesso` do `SheetTituloLista`; `limparConcluidos` devolve os itens removidos e o SnackBar 3s "Desfazer" restaura `id`/`ordem`; "Sair" via `AppDialog.confirmarDestrutivo`; testes novos/ajustados em auth, convites, listas e configurações)*
- [x] **F14-T06** — Affordance e rótulos
  Dep: F14-T00 · Docs: [10 §2.1/§3](10-wireframes-telas.md), [05 §6.2/§6.3](05-app-flutter.md)
  CP: `⋮` no card com as ações do contexto (long-press abre o mesmo menu); rótulo "Nome do item" no editor; "Copiar link" × "Copiar código" distinguidos; testes verdes.
  *(card com `PopupMenuButton` `⋮` (Minhas: Renomear/Excluir; Compartilhadas: Membros/Sair) e long-press via `showButtonMenu`; "Sair da lista" extraído para `confirmarSairDaLista` (reuso tela de membros/card); editor de item com "Nome do item" (entrada rápida segue "Adicionar item"); sheet Convidar com "Copiar código" + tooltips nos dois botões e doc 08 §8 atualizado)*
- [x] **F14-T07** — Validação visível
  Dep: F14-T00 · Docs: [05 §6](05-app-flutter.md), [15 §3](15-design-system.md)
  CP: erro inline no editor (nome/quantidade) e na edição inline da importação; aviso quando o parser descarta todo o texto; toggle de senha no registro; testes verdes.
  *(`_CampoAdicionar` com erro inline `naoEntendiItem` quando o parser descarta o texto, limpo ao digitar; editor de item com `erroNomeVazio`/`erroQuantidadeInvalida` mantendo o diálogo aberto; `_PainelEdicao` da importação com `errorText` de nome/quantidade (migração para `AppCampoTexto` segue na F14-T08); registro com toggle independente por campo (padrão da `RedefinirSenhaScreen`); docs 05 §6.1/§6.3/§6.4 atualizados)*
- [x] **F14-T08** — Consistência e dívida visual
  Dep: F14-T00 · Docs: [15 §1/§3](15-design-system.md), [05 §6/§7](05-app-flutter.md)
  CP: uma única copy de exclusão de lista; strings (tempo relativo, fallbacks) no `AppStrings`; `AppBannerTipo.leitura` usado; `AppCampoTexto` com `maxLength`/`minLines`/`textInputAction`/`readOnly` e os `TextField` crus migrados; medidas em tokens; `analyze`/`test` verdes.
  *(`AppCampoTexto` com `hint`/`maxLength`/`minLines`/`maxLines`/`textInputAction`/`readOnly` (contador embutido oculto, sem truncar; default `maxLines` corrigido para 1); `AppDropdown<T>` novo migrando os 4 dropdowns; `TextField` crus de `modal_importar`/`modal_previsao_importacao`/`sheet_convidar` migrados; `excluirListaTitulo`/`excluirListaMensagem(nItens, temMembros)` única (painel `false`, tela da lista best-effort via `membrosDaListaProvider`); tempo relativo/`progressoLista`/`semValor` no `AppStrings`; banner de leitura via `AppBannerTipo.leitura`; medidas exatas em tokens; docs 15 §3 atualizado)*
- [x] **F14-T09** — Skeletons + fechamento
  Dep: F14-T01…T08 · Docs: [15 §3](15-design-system.md), [07 §1](07-qualidade-ci.md)
  CP: `AppEsqueleto` (estático, sem dependência nova) no painel/itens/membros; `format`/`analyze`/`test` verdes; docs sincronizados; APK aos testadores via F5-T05b (opcional).
  *(`AppEsqueleto` estático com `linhas`/`altura`, cor `surfaceContainerHighest`, `Semantics` de carregamento; usado no painel de listas (4), itens da lista (5) e membros (4), substituindo o spinner só nessas listas; catálogo `/design` e doc 15 §3 atualizados; APK opcional não executado)*

### Fase 15 — Backlog de planejamento

Registrado pela [spec da F14 §16](superpowers/specs/2026-09-14-ux-acessibilidade-design.md); ainda sem spec nem tarefas:

- **Identificação de membros por nome/e-mail** (hoje só UUID prefixado) — exige RPC `security definer` + policy nova (docs 01/02) e decisão de privacidade.
- **Novas features de produto:** modo mercado (tela focada no supermercado), busca/filtro na lista e no painel, atalhos de itens frequentes, avatar/busca de membros.

---

## Fase 16 — Busca e filtro

Spec: [superpowers/specs/2026-09-16-busca-filtro-design.md](superpowers/specs/2026-09-16-busca-filtro-design.md) · Requisito: RF-17.

- [x] **F16-T00** — RF-17 + docs de planejamento
  Dep: — · Docs: spec da fase
  CP: RF-17 no 12 (tabela + matriz); 05 §6.2/§6.3, 10 §2/§3, 00/índice e Fase 16 no 14 consistentes; sem tocar código de app.
- [x] **F16-T01** — Helper `contemBusca` + unit tests
  Dep: F16-T00 · Docs: [05 §6.2/§6.3](05-app-flutter.md)
  CP: `contemBusca` puro (caixa/acento) com unit tests dos casos da spec §7; `analyze`/`test` verdes.
  *(`lib/core/texto/busca.dart` reusa `normalizarTexto` e faz `contains`; unit tests em `test/core/texto/busca_test.dart` cobrindo caixa, acento, substring, termo que não casa e termo com espaços)*
- [x] **F16-T02** — Busca no painel (título)
  Dep: F16-T01 · Docs: [05 §6.2](05-app-flutter.md), [10 §2](10-wireframes-telas.md)
  CP: lupa/campo/filtro por título/vazio de busca no `PainelListas`; widget tests.
  *(`PainelListas` vira `ConsumerStatefulWidget`; lupa com `tooltip` "Buscar", campo `label` "Buscar lista" e hint "Nome da lista", ✕ limpa/fecha; filtro por `contemBusca(titulo)`; `AppEstadoVazio` "Nenhuma lista encontrada" sem CTA; widget tests nas abas Minhas/Compartilhadas)*
- [x] **F16-T03** — Busca na tela da lista (item)
  Dep: F16-T01 · Docs: [05 §6.3](05-app-flutter.md), [10 §3](10-wireframes-telas.md)
  CP: lupa/campo/filtro por nome, grupos preservados (vazios escondidos), drag off, concluídos filtrados, limpar-ao-adicionar, vazio; widget tests.
  *(`_buscando` na tela da lista; campo `label` "Buscar item" e hint "Nome do item"; `_ListaItens` filtra por `contemBusca(nome)`, mantém os grupos de categoria (vazios somem) e a seção de concluídos (contagens filtradas); drag desabilitado com filtro ativo (`SliverList`); adicionar limpa a busca; vazio de busca com ação "Limpar busca"; widget tests)*
- [x] **F16-T04** — Acessibilidade, docs e fechamento
  Dep: F16-T02, F16-T03 · Docs: [12](12-prd.md), [05](05-app-flutter.md), [10](10-wireframes-telas.md), [14](14-tarefas.md)
  CP: tooltips/estados conferidos; `format`/`analyze`/`test` verdes; Fase 16 marcada.
  *(rótulo acessível `label` nos dois campos de busca com `hint` de exemplo; tooltips da lupa/✕ já presentes; 10 §2/§3 e spec §4.2/§4.3/§4.4 ajustados para "label + hint"; 05 §6.2/§6.3 sem divergência; `format`/`analyze`/`test` verdes; Fase 16 marcada 5/5 — F16 encerra a fase 16)*

---

## Fase 17 — Remoção da IA

Spec: [superpowers/specs/2026-09-17-remocao-ia-design.md](superpowers/specs/2026-09-17-remocao-ia-design.md) · Requisito: RF-16 (import local permanece); RF-06/RNF-04 removidos.

- [x] **F17-T00** — PRD + planejamento (RF-06/RNF-04 fora do 12; Fase 17 no 14)
  Dep: — · Docs: [12](12-prd.md), [14](14-tarefas.md)
  CP: RF-06 e RNF-04 removidos do 12 (tabela + matriz); RF-15/RF-16 sem cláusulas de IA; Fase 17 no 14; sem tocar código.
- [x] **F17-T01** — Migration `0013` + `excluir_conta` sem `ia_rate_limit`
  Dep: F17-T00 · Docs: [01](01-banco-de-dados.md), [06 §3.3.1](06-mvp-entregas.md)
  CP: `supabase db reset` aplica 0004+0013; `ia_rate_limit`/`registrar_requisicao_ia` inexistentes; `excluir_conta_tests.sql` E-01…E-05 verde.
- [x] **F17-T02** — Remover Edge Function `parse-lista` e passos Deno/e2e do CI
  Dep: F17-T01 · Docs: [04](04-importacao-lista.md), [07](07-qualidade-ci.md)
  CP: pasta `supabase/functions/parse-lista/` e `parse_lista_e2e.mjs` removidos; CI sem setup-deno/deno test/e2e; pipeline verde.
- [x] **F17-T03** — App: import local como único modo (+ testes Flutter)
  Dep: F17-T00 · Docs: [05 §6.4](05-app-flutter.md), [10 §4](10-wireframes-telas.md)
  CP: `lib/features/ia/` e `test/features/ia/` removidos; `ErroImportacao` no core; modal sem seletor de modo; strings sem prefixo `ia`; privacidade sem Gemini; `format`/`analyze`/`test` verdes.
- [x] **F17-T04** — Docs donos, 04 reaproveitado e fechamento
  Dep: F17-T01, F17-T02, F17-T03 · Docs: [00](00-visao-geral.md), [04](04-importacao-lista.md), [12](12-prd.md), [14](14-tarefas.md)
  CP: `04-importacao-lista.md` dono do import local; ~34 links repontados; 00/03/05/06/09/10/11/13/README/AGENTS/planejamento sem IA/Gemini; guarda de grep da spec §6 vazia; Fase 17 na tabela de progresso.

## Fase 18 — Suporte a Web e Desktop

Spec: [superpowers/specs/2026-09-17-suporte-web-desktop-design.md](superpowers/specs/2026-09-17-suporte-web-desktop-design.md) · ADR-012 · Docs donos: 00, 05, 06, 07, 08, 09.

- [x] **F18-T00** — ADR-012 + planejamento (00, 12, 13, 14)
  Dep: — · Docs: [00](00-visao-geral.md), [14](14-tarefas.md)
  CP: ADR-012 no 00; Fase 18 no 14; menções de plataforma no 12/13 coerentes; sem tocar código.
- [x] **F18-T01** — Banco multi-plataforma (fábrica condicional + assets wasm)
  Dep: F18-T00 · Docs: [05](05-app-flutter.md)
  CP: `database.dart` sem `dart:io`; `conexao_nativa`/`conexao_web`; assets `drift_worker.js`/`sqlite3.wasm` versionados; `analyze`/`test` verdes.
- [x] **F18-T02** — Rede, links, auth e URL strategy (web compila)
  Dep: F18-T01 · Docs: [05](05-app-flutter.md), [09](09-runbook-operacoes.md), [12](12-prd.md)
  CP: `erro_rede` sem `dart:io`; `links.dart` (origem/scheme); `/login-callback`; `usePathUrlStrategy`; `flutter build web` compila.
- [x] **F18-T03** — Desktop (Windows/Linux/macOS)
  Dep: F18-T02 · Docs: [05](05-app-flutter.md), [06](06-mvp-entregas.md)
  CP: pastas `windows/`/`linux/`/`macos/`; `flutter build windows` e `flutter build linux`; app abre e persiste no Windows.
- [x] **F18-T04** — Ajustes do app web
  Dep: F18-T02 · Docs: [06](06-mvp-entregas.md)
  CP: manifest sem portrait fixo; `web/version.json`; compartilhar com fallback; smoke no Chrome.
- [x] **F18-T05** — CI (build web + desktop) e docs donos; fechamento
  Dep: F18-T03, F18-T04 · Docs: [07](07-qualidade-ci.md), [08](08-compartilhamento-colaborativo.md), [09](09-runbook-operacoes.md)
  CP: CI verde com `build web` + builds desktop; 05/06/07/08/09 sincronizados; Fase 18 marcada.

## Fase 19 — Publicação Web — **CANCELADA (18/09/2026)**

> **Decisão do dono:** o Web fica para **uso local**; não haverá publicação em URL pública. O Hosting foi desabilitado (`https://lista-compras-34f93.web.app` → 404) e a fase é encerrada sem deploy. ADR-013 revisado em [00 §5](00-visao-geral.md); spec mantida como referência em [superpowers/specs/2026-09-17-publicacao-web-design.md](superpowers/specs/2026-09-17-publicacao-web-design.md). T02/T03/T04 **não serão executadas**; o que foi entregue (T00/T01) permanece no repositório.

Spec: [superpowers/specs/2026-09-17-publicacao-web-design.md](superpowers/specs/2026-09-17-publicacao-web-design.md) · ADR-013 · Docs donos: 00, 06, 07, 09.

- [x] **F19-T00** — ADR-013 + planejamento (00, 06, 12, 13, 14)
  Dep: — · Docs: [00](00-visao-geral.md), [06](06-mvp-entregas.md), [14](14-tarefas.md)
  CP: ADR-013 no 00; Fase 19 no 14; item de publicação do 06 §1 desdobrado; sem tocar código. *(ADR-013 no 00 e no 13; Fase 19 no 14 com progresso; 06 §1 desdobrado, numeração 3.3.2 corrigida e nota do contato genérico; 12 §7 e as descrições da Fase 5/F5-T06 reapontadas para Play-only; nenhum arquivo de código tocado)*
- [x] **F19-T01** — Artefatos de hosting, política estática e primeiro deploy
  Dep: F19-T00 · Docs: [06 §3.3.2](06-mvp-entregas.md), [09](09-runbook-operacoes.md)
  CP: `firebase.json`/`.firebaserc`/`robots.txt`/`privacidade.html`; testes-guarda de paridade verdes; URL pública com COOP/COEP, rewrite e `/privacidade`. *(entregue e depois **revertido por decisão do dono**: o Hosting foi desabilitado em 18/09/2026 e os artefatos + o teste-guarda foram **removidos do repositório** — o Web fica para uso local, ver ADR-013)*
- [x] ~~**F19-T02** — Supabase Auth e smoke funcional na URL pública~~ — **cancelada** (Web de uso local)
- [x] ~~**F19-T03** — Deploy no CI (preview por PR, live na main) e rollback~~ — **cancelada** (não haverá publicação)
- [x] ~~**F19-T04** — Política no app e fechamento~~ — **cancelada**; a pendência de acessar a política pelo app (link no cadastro/configurações) segue válida **sem** a versão online e fica com a F21 (`F21-T04`)

## Fase 20 — Correções da revisão geral

Fonte: [relatorio-revisao-geral.md](relatorio-revisao-geral.md) · Plano: [superpowers/plans/2026-09-18-correcoes-revisao-geral.md](superpowers/plans/2026-09-18-correcoes-revisao-geral.md) · Docs donos: 01, 02, 03, 04, 06, 07, 08, 15.

Ordem: T00 → T01 → T02 (parser) → T03 → T04 → T05 (sync) → T06 (docs donos) → T07…T12 (frentes independentes).

- [x] **F20-T00** — Registrar a revisão geral e a Fase 20
  Dep: — · Docs: [14](14-tarefas.md), [relatório](relatorio-revisao-geral.md)
  CP: relatório com os achados `R-xx` verificados; Fase 20 no 14 com progresso; sem tocar código.
- [x] **F20-T01** — Parser: vírgula decimal não pode corromper a quantidade (R-01)
  Dep: F20-T00 · Docs: [04 §3](04-importacao-lista.md)
  CP: `1,5 kg de arroz` → `1.5 kg`; segmentação por `,` entre itens preservada; doc 04 §3 sem contradição.
- [x] **F20-T02** — Parser e UI: quantidade ≤ 0 tratada como ausente (R-02)
  Dep: F20-T01 · Docs: [04 §3](04-importacao-lista.md)
  CP: `0 arroz` → `1 un` + aviso; edição inline rejeita `≤ 0`; nenhuma exceção crua na confirmação.
- [x] **F20-T03** — Sync: não perder mutação enfileirada durante o flush (R-03)
  Dep: F20-T00 · Docs: [03 §3/§4](03-sincronizacao-offline.md)
  CP: remoção limitada ao id do lote; teste com edição durante o envio mantém a mutação nova na fila e no servidor.
- [x] **F20-T04** — Sync: flush sem reentrância e status correto no bootstrap (R-04, R-05)
  Dep: F20-T03 · Docs: [03 §4/§6](03-sincronizacao-offline.md)
  CP: `flush()` em laço (sem ciclo de futures); fila esgotada no restart expõe `Erro` com "tentar de novo".
- [x] **F20-T05** — Sync: divergência de relógio medida contra o servidor (R-06)
  Dep: F20-T03 · Docs: [03 §5](03-sincronizacao-offline.md), [07 §4](07-qualidade-ci.md)
  CP: `ts_local` comparado ao `now()` do servidor; evento `sync_relogio_adiantado` testado com fonte injetada.
- [x] **F20-T06** — Docs donos: publication, cascatas, inventário e CI (R-09, R-17)
  Dep: — · Docs: [01](01-banco-de-dados.md), [02](02-seguranca-rls.md), [06](06-mvp-entregas.md), [07](07-qualidade-ci.md)
  CP: 01 §7 e §4 com `convites`; 02 §2 com `convites`; 06 §4/ADR-013 sem afirmar deploy já entregue; 07 §3 espelhando o `ci.yml`; cascata de `convites.criado_por` na lista do 06 §3.3.1.
- [x] **F20-T07** — CI: rodar o teste de Realtime no job `supabase` (R-10)
  Dep: F20-T06 · Docs: [02 §5](02-seguranca-rls.md), [07 §3](07-qualidade-ci.md)
  CP: `realtime_test.mjs` executado no CI (sem `package.json` stub); CP da F1-T07 validado.
- [x] **F20-T08** — Convites: revogar convite pendente pela UI (R-07)
  Dep: — · Docs: [08 §2/§5](08-compartilhamento-colaborativo.md)
  CP: ação "Revogar" no sheet do dono usando `ConvitesRepository.revogar`; token revogado deixa de ser aceito.
- [x] **F20-T09** — Categorias: cobertura do termo antes do desempate alfabético (R-08)
  Dep: — · Docs: [04 §5](04-importacao-lista.md)
  CP: `Suco de laranja` → Bebidas; casos de teste para compostos.
- [x] **F20-T10** — Realtime: limpeza ao perder acesso e status do canal (R-11, R-12)
  Dep: — · Docs: [03 §4/§7](03-sincronizacao-offline.md), [08 §7/§9](08-compartilhamento-colaborativo.md)
  CP: comportamento do cache ao ser removido documentado e o caminho testado; callback de status com re-sync em erro (feito); **R-23: flaky do Realtime local mitigado no CI com retry** (ver `R-23` no relatório). *(R-11: medido contra o stack local — o `old_record` do DELETE de `lista_membros` chega vazio mesmo com `replica identity full`; causa é `_realtime.tenants.private_only`, sem opção no CLI. Limpeza garantida por reconexão/bootstrap/sair-da-lista; **não** há limpeza por evento nem reavaliação em resume — o `08 §9` descreve isso como limite conhecido. R-12: re-sync em `SUBSCRIBED` implementado e testado. R-23: flaky de infra local, retry no CI)*
- [x] **F20-T11** — Banco: defesa em profundidade e higiene (R-18, R-19)
  Dep: F20-T06 · Docs: [01](01-banco-de-dados.md), [02 §4.3](02-seguranca-rls.md)
  CP: `papel='dono'` restrito na policy de insert; trigger de `atualizado_em` em `convites`; testes de negação verdes.
- [x] **F20-T12** — Privacidade e polimento de UI/a11y (R-13…R-16, R-20, R-21, R-22)
  Dep: — · Docs: [05 §7](05-app-flutter.md), [07 §4](07-qualidade-ci.md), [09 §2.4](09-runbook-operacoes.md), [15 §4](15-design-system.md)
  CP: `beforeSend` sem dados de itens; callback do login no i18n/tokens; comentário da política; deps; ajustes de a11y; CSP documentada como decisão; `seed.sql` existente ou `sql_paths` removido do `config.toml` (sem aviso no `db reset`).

## Fase 21 — Pendências do fechamento da F20

Achados da revisão de fechamento que **não** deveriam ser marcados como concluídos na F20 (ver `relatorio-revisao-geral.md`).

- [ ] **F21-T01** — A11y pendente do R-20
  Dep: — · Docs: [10](10-wireframes-telas.md), [11](11-usabilidade-fase5.md), [15 §4](15-design-system.md)
  CP: `SeletorTema` sem overflow em tela estreita/escala 2x; telas de verificação/login com scroll; decisão registrada sobre o indicador de sync no painel (código ou wireframe ajustado).
- [ ] **F21-T02** — Sentry: limpar `event.extra` e alinhar `07 §3`/`02 §3`
  Dep: — · Docs: [02 §3](02-seguranca-rls.md), [07 §3/§4](07-qualidade-ci.md)
  CP: `beforeSend` limpa `breadcrumbs`, `extra` e `contexts`; esqueleto do CI espelha o `ci.yml` (step de Realtime + pin do CLI); matriz de INSERT de `lista_membros` no 02 §3 cita `user_id = auth.uid()`.
- [ ] **F21-T03** — Convites: revogar também os pendentes anteriores (R-07 parcial)
  Dep: — · Docs: [08 §2](08-compartilhamento-colaborativo.md)
  CP: sheet lista os convites pendentes da lista (usando `pendentesDaLista`) com ação de revogar; ou limite documentado no 08.
- [ ] **F21-T04** — Política de Privacidade acessível pelo app (herdada da F19-T04)
  Dep: — · Docs: [06 §3.3.2](06-mvp-entregas.md)
  CP: link "ver política" no cadastro e em Configurações abrindo o texto in-app (`politicaPrivacidadeTexto`); **sem** versão online (decisão de 18/09/2026).

## Progresso por fase (atualize ao concluir)

| Fase | Tarefas | Concluídas |
| :--- | :--- | :--- |
| F1 Infra & BD | 8 | 8 |
| F3 App Core | 9 | 9 |
| F4 Sincronização | 9 | 9 |
| F5 Publicação | 7 | 5 |
| F6 Pós-MVP | 7 | 7 |
| F7 Compartilhamento | 8 | 8 |
| F8 Design System | 4 | 4 |
| F9 Refresh Visual | 9 | 9 |
| F10 Navegação | 7 | 7 |
| F11 Import local | 4 | 4 |
| F12 Correções | 7 | 7 |
| F13 Identidade visual | 3 | 3 |
| F14 Acessibilidade & UX | 10 | 10 |
| F16 Busca e filtro | 5 | 5 |
| F17 Remoção da IA | 5 | 5 |
| F18 Web e Desktop | 6 | 6 |
| F19 Publicação Web — **cancelada** | 5 | 5 |
| F20 Correções da revisão | 13 | 13 |
| F21 Pendências do fechamento | 4 | 0 |
| **Total** | **130** | **124** |

## Documentos relacionados
- [12 PRD](12-prd.md) — RF/RNF referenciados pelas tarefas
- [13 Pré-modelo](13-premodelo-tecnico.md) — contexto para executar qualquer tarefa
- [AGENTS.md](../AGENTS.md) — fluxo de trabalho do agente
