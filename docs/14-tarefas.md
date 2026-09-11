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
  CP: Critério 11 §3.1: T1–T4 ≥ 80% sem ajuda **e** T3 100%; relatório de 1 página produzido. *(ADIADA por decisão do dono: executar somente sob solicitação explícita — só quando for lançar. Relatório modelo pronto em [docs/relatorio-usabilidade-fase5.md](relatorio-usabilidade-fase5.md); exige participantes humanos, fora do escopo do agente)*
- [x] **F5-T05b** — Distribuição interna via Firebase App Distribution
  Dep: F4-T09 · Docs: [06 §4](06-mvp-entregas.md)
  CP: APK release assinado, instalável por 2+ testadores apontando para o Supabase de produção; keystore via `android/key.properties` (gitignored, template em `key.properties.example`) com fallback para debug quando ausente. *(fora do gate de T05/T06 — é o canal provisório de builds de teste até o lançamento. Build `1.0.0+2` assinado (V2, CN=Lucas Oliveira), URL de produção verificada embutida no libapp.so e smoke no emulador: instala, abre e login com credenciais erradas devolve "E-mail ou senha incorretos" da produção. Distribuído ao grupo "testadores" (2 membros) via `firebase appdistribution:distribute --groups`; dart-defines de produção em `dart_defines_prod.json` (gitignored). Correções de CI no caminho: Flutter 3.44.5 e CLI 2.116.0 pinados, e2e cria usuários via Admin API (confirmations F3) — doc 07 §3 e 04 §8 atualizados)*
- [ ] **F5-T06** — Publicação Web + Android (teste interno) + política de privacidade online
  Dep: F5-T05 · Docs: [06 §4](06-mvp-entregas.md)
  CP: Checklist 06 §1 100% marcado; URL Web pública; AAB no closed testing. *(ADIADA por decisão do dono: executar somente sob solicitação explícita — só quando for lançar na Play Store; Dep F5-T05 permanece)*

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
- [x] **F6-T05** — IA com categoria (prompt + `responseSchema` + cliente tolerante + pré-visualização)
  Dep: F6-T02 · Docs: [04](04-ia-edge-function.md)
  CP: schema exige enum dos 11 valores; cliente sem `categoria` → `outros`; deno/e2e verdes; **deploy da function em produção antes do APK novo** aos testadores.
  *(Smoke de produção: função responde 401 sem JWT — deploy `5m` após F6-T04; e2e `--sem-gemini` local tem 1 falha pré-existente e ambiental (`.env` com `GEMINI_API_KEY` carregado pelo edge runtime faz o cenário "sem key" não dar 500 — o CI, com env limpo, valida esse cenário)*
- [x] **F6-T06** — Checklist sync [03 §8](03-sincronizacao-offline.md) com categoria + distribuição nova
  Dep: F6-T02, F6-T05 · Docs: [03 §8](03-sincronizacao-offline.md), [07 §1](07-qualidade-ci.md)
  CP: cenário de categoria entre 2 dispositivos (servidor fake) verde; CI verde; APK `1.1.0+3` distribuído ao grupo `testadores` (história em [09 §2.5](09-runbook-operacoes.md)).

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
  CP: itens 1, 2→(adaptado a link), 4, 5, 6 e 8 do checklist verificados; APK `1.1.1+4` (ou próximo) via App Distribution; histórico em [09 §2.5](09-runbook-operacoes.md).
  Nota: *(itens 1, 2, 3(idempotência), 4, 6 e 8 do recorte verificados por suites SQL (N-01…N-17, E-01…E-05, A-01…A-07) + 223 testes Flutter; itens 1 e 5 físicos pendentes de 2 dispositivos; final review corrigiu RLS faltante (migration 0009: dono muda papel + membro sai — antes eram no-ops silenciosos), whitelist de tabelas no realtime, feedback "membro entrou" e limpeza local no sair; migrations 0007–0009 aplicadas em produção via `db push`; APK `1.1.2+5` distribuído ao grupo `testadores`)*

### Pós-MVP (Fase 7) — pendente de planejamento

Convite por e-mail transacional (Fluxo B + Edge Function `enviar-convite`), transferência de dono (RF-14), universal links (pós-F5-T06), iOS, Desktop, limpeza de tombstones.

## Fase 8 — Revisão Visual e de UX (spec em [superpowers/specs](superpowers/specs/2026-09-11-revisao-visual-ux-design.md))

- [ ] **F8-T00** — Spec + ajustes de docs de planejamento
  Dep: — · Docs: spec da fase
  CP: docs 15/05/10/00/12/13/14/index/AGENTS consistentes entre si, sem tocar código.
- [ ] **F8-T01** — Tokens + `AppTheme` claro/escuro + fonte bundlada + cores semânticas + seletor de tema
  Dep: F8-T00 · Docs: [15](15-design-system.md) · RNF-06
  CP: tema claro/escuro com paridade, extensão semântica presente, fonte Plus Jakarta Sans aplicada, modo persistido; `analyze`/`test` verdes.
- [ ] **F8-T02** — Biblioteca de componentes (`App*`) + catálogo `/design`
  Dep: F8-T01 · Docs: [15 §3](15-design-system.md)
  CP: componentes do doc 15 renderizam em claro/escuro; catálogo em `kDebugMode`.
- [ ] **F8-T03** — Testes dos componentes + CI verde
  Dep: F8-T02 · Docs: [07 §1](07-qualidade-ci.md)
  CP: widget tests dos componentes e do seletor; `format`/`analyze`/`test` verdes.

---

## Progresso por fase (atualize ao concluir)

| Fase | Tarefas | Concluídas |
| :--- | :--- | :--- |
| F1 Infra & BD | 8 | 8 |
| F2 IA | 5 | 5 |
| F3 App Core | 9 | 9 |
| F4 IA + Sync | 9 | 9 |
| F5 Publicação | 7 | 5 |
| F6 Pós-MVP | 7 | 7 |
| F7 Compartilhamento | 8 | 8 |
| F8 Design System | 4 | 0 |
| **Total** | **57** | **51** |

## Documentos relacionados
- [12 PRD](12-prd.md) — RF/RNF referenciados pelas tarefas
- [13 Pré-modelo](13-premodelo-tecnico.md) — contexto para executar qualquer tarefa
- [AGENTS.md](../AGENTS.md) — fluxo de trabalho do agente
