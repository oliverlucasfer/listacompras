# Spec — Remoção da IA/Gemini (Fase 17)

> Navegação: [← 12 PRD](../../12-prd.md) · [04 Importação](../../04-importacao-lista.md) · [05 App Flutter](../../05-app-flutter.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-17 · Status: aprovada

## 1. Objetivo

Remover integralmente o caminho de **IA/Gemini** do produto: a Edge Function `parse-lista`, o **modo IA** do modal de importação, a tabela/RPC de rate limit, os testes Deno/e2e, as etapas de CI e os segredos. A importação de lista por texto livre **permanece** — agora apenas no **modo local determinístico, offline** (**RF-16**), que já é o padrão desde a Fase 11.

O doc dono `04-ia-edge-function.md` deixa de ser dono da IA e passa a ser o dono do contrato da **importação de lista (parser local)**.

Requisitos afetados: **RF-06** (importação via IA) e **RNF-04** (proteção da IA) são **removidos** do PRD; **RF-15** e **RF-16** são reescritos sem cláusulas de IA. Fase nova: **F17 — Remoção da IA**.

## 2. Contexto

- O app funciona 100% sem IA desde a F11 (parser local `lib/core/importacao/parser_lista_local.dart`, RF-16), que é o **modo padrão** do modal.
- Não há coluna de “origem IA”, tabela de previsões, nem caminho de IA no sync/Drift/RLS. O único artefato de schema ligado à IA é `public.ia_rate_limit` + a RPC `registrar_requisicao_ia` (migration `0004`).
- A IA existe em cinco camadas: Edge Function (`supabase/functions/parse-lista/`), cliente/providers Dart (`lib/features/ia/`), ramo IA do modal, strings, e testes (Deno + e2e + Flutter).
- **Acoplamentos que NÃO são exclusivos da IA** (precisam de destino após a remoção):
  - `ErroIa` (`lib/features/ia/domain/contrato_ia.dart`) é lançada/capturada pelo **fluxo local** em `modal_importar.dart:85,99`.
  - `AppStrings.iaSemConexao` é usada por **convites** (`convites_repository.dart:146-150`) e seu teste.
  - `AppStrings.iaRespostaInvalida` é usada pelo fluxo local; `iaConfirmeItens`/`iaAdicionarN`/`iaSeraoAdicionados` pela **pré-visualização**, que permanece.
  - `ItemExtraido`/`RespostaParse` (`lib/core/importacao/resposta_import.dart`) já são genéricos e servem ao modo local — **não remover**.
- Docs donos que citam IA/Gemini: `00`, `01`, `03`, `05`, `06`, `07`, `09`, `10`, `11`, `12`, `13`, `14`, `relatorio-usabilidade-fase5.md`, `README.md`, `AGENTS.md`, `planejamento_lista_compras.md`.
- Restrições: **migrations são append-only** (`0004` permanece como histórico); **RLS é sagrado**; nenhum segredo em código/commit/log (AGENTS.md).

## 3. Decisões (2026-09-17)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Escopo | Remover **só** o caminho Gemini/IA; manter o import local (RF-16) | O local já é o padrão e cobre o caso de uso |
| Doc dono `04` | **Reaproveitar e renomear** para `docs/04-importacao-lista.md` (dono do parser local) | Preserva a sequência `00–15` e os links; dá dono normativo ao import local |
| RF-06 / RNF-04 | **Remover** as linhas (IDs estáveis, **sem renumerar** o restante) | Requisito inexistente não deve permanecer no PRD |
| Remoção | **Big-bang** numa fase (F17), por camada | IA já é opcional; minimiza tempo com código/doc mortos |
| Migration | **Nova `0013_remover_ia_rate_limit.sql`** (append-only); `0004` fica como histórico | `db reset`/produção dependem do histórico; AGENTS.md exige migrations |
| Rate limit e `excluir_conta` | `0013` faz `drop function` + `drop table` e **recria `excluir_conta()`** sem o `delete` da tabela | O RPC de [0005:28](../../../supabase/migrations/0005_excluir_conta.sql) referencia a tabela removida |
| Erro compartilhado | Novo **`ErroImportacao`** em `lib/core/importacao/erro_importacao.dart`; `ErroIa` deixa de existir | O fluxo local não pode depender de `features/ia/` |
| Strings compartilhadas | `iaSemConexao` → **`erroSemConexao`**; `iaRespostaInvalida` → **`importRespostaInvalida`**; demais `ia*` remanescentes → prefixo **`import*`** | Remove o vocabulário de IA sem quebrar convites/previsão |
| Modal | **Modo único** local; remove `enum ModoImportacao`, o `SegmentedButton` e o parâmetro `modoInicial` | Não há mais escolha de modo |
| CI (deno) | **Remover** `setup-deno` e os steps Deno/e2e agora; reintroduzir quando a Fase 7 trouxer `enviar-convite` | YAGNI; CI honesto com o que existe |
| Segredos | `supabase secrets unset GEMINI_API_KEY`, **revogar** a chave no Google AI Studio e apagar `.env` locais | A chave deixa de existir no produto |
| `budget`/cota | Remover R-02/R-04 do [00](../../00-visao-geral.md) e a seção 3 do [09](../../09-runbook-operacoes.md) | Sem IA não há cota Gemini nem rotação de chave |

## 4. Comportamento

### 4.1 Banco de dados

- Nova migration `supabase/migrations/0013_remover_ia_rate_limit.sql`:
  1. `drop function if exists public.registrar_requisicao_ia(uuid);`
  2. `drop table if exists public.ia_rate_limit;`
  3. `create or replace function public.excluir_conta()` — corpo **idêntico** ao de `0005` menos a linha `delete from public.ia_rate_limit where user_id = uid;`; reemitir os grants (`revoke execute ... from public, anon;` / `grant execute ... to authenticated;`).
- `sync_dono` (definido em `0005`) **não muda**.
- `supabase/tests/excluir_conta_tests.sql`: remover o setup que insere em `ia_rate_limit` (L45-47) e a asserção E-03 sobre a tabela (L92-93). Os demais casos (E-01, E-02, E-03 para as tabelas restantes, E-04, E-05) permanecem.

### 4.2 Backend / Edge Function

- Deletar `supabase/functions/parse-lista/` inteira (`index.ts`, `gemini.ts`, `gemini_test.ts`, `prompt.ts`, `rate-limit.ts`, `schema.ts`, `schema_test.ts`, `sentry.ts`, `sentry_test.ts`).
- Deletar `supabase/functions/.env` (contém `GEMINI_API_KEY`).
- Deletar `supabase/tests/parse_lista_e2e.mjs`.
- `.github/workflows/ci.yml`: remover o step `denoland/setup-deno` e o `deno-version`, o step `Testes unitários das Edge Functions (deno)` e o step `Testes e2e do contrato parse-lista (cenários sem Gemini)`. O `supabase start -x …` permanece (o edge runtime não faz mal e volta a ser usado na Fase 7).

### 4.3 App Flutter

- Deletar `lib/features/ia/` inteira (`data/parse_lista_client.dart`, `domain/contrato_ia.dart`, `providers/ia_providers.dart`) e `test/features/ia/`.
- Criar `lib/core/importacao/erro_importacao.dart`:
  ```
  class ErroImportacao implements Exception {
    const ErroImportacao(this.mensagem);
    final String mensagem;
  }
  ```
  O fluxo local usa apenas o caso “nenhum item entendido” (`resposta_invalida`).
- `lib/features/importacao/ui/modal_importar.dart`:
  - remover `import '../../ia/...'`, `enum ModoImportacao`, `_modo`/`modoInicial`, `_limite` condicional, o `SegmentedButton` e os ícones de modo;
  - limite fixo = `maxCaracteresImportLocal`;
  - `_extrair()` chama somente o parser local; lança/captura `ErroImportacao` no lugar de `ErroIa`;
  - `abrirModalImportar(...)` perde o parâmetro `modoInicial`.
- `lib/features/listas/ui/tela_lista_screen.dart`: renomear `_importarPorIa` → `_importarLista` e ajustar a chamada (L192-202, L365-368).
- `lib/features/convites/data/convites_repository.dart`: `AppStrings.iaSemConexao` → `AppStrings.erroSemConexao`.
- `lib/core/l10n/politica_privacidade.dart`: na seção “Com quem compartilhamos”, remover a fração que descreve o envio do texto ao Google Gemini (mantém Supabase e Sentry).
- Comentários incidentais: `supabase_auth_repository.dart:44`, `convite.dart:6`, `unidade.dart:2`, `categoria.dart:2`, `modal_previsao_importacao.dart:17`.

### 4.4 Strings (`AppStrings`)

- **Remover** (exclusivas da IA): `iaSessaoExpirada`, `iaTextoVazio`, `iaTextoLongo`, `iaRateLimit`, `iaCotaIa`, `iaTimeoutIa`, `iaErroInterno`, `modoIa`, `modoRapido`.
- **Renomear** (permanecem): `iaColeOuDigite`→`importColeOuDigite`, `iaExemplo`→`importExemplo`, `iaExtrairItens`→`importExtrairItens`, `iaLendo`→`importLendo`, `iaConfirmeItens`→`importConfirmeItens`, `iaAdicionarN`→`importAdicionarN`, `iaSeraoAdicionados`→`importSeraoAdicionados`, `iaRespostaInvalida`→`importRespostaInvalida`, `iaSemConexao`→`erroSemConexao`.
- Ajustar todos os callers (modal de importação, pré-visualização, convites) e testes.
- `fechar`, `importarLista`, `importLocalAvisoPadrao`, `importLocalTextoLongo` permanecem.

## 5. Arquivos

**Criar**
- `docs/04-importacao-lista.md` (conteúdo novo; o antigo `docs/04-ia-edge-function.md` é removido/renomeado)
- `supabase/migrations/0013_remover_ia_rate_limit.sql`
- `lib/core/importacao/erro_importacao.dart`
- `docs/superpowers/plans/2026-09-17-remocao-ia.md` (plano, etapa seguinte)

**Deletar**
- `supabase/functions/parse-lista/` (9 arquivos), `supabase/functions/.env`
- `lib/features/ia/` (3 arquivos), `test/features/ia/parse_lista_client_test.dart`
- `supabase/tests/parse_lista_e2e.mjs`
- `docs/04-ia-edge-function.md` (substituído por `04-importacao-lista.md`)

**Modificar (DB/CI)**
- `supabase/tests/excluir_conta_tests.sql`, `.github/workflows/ci.yml`

**Modificar (app)**
- `lib/features/importacao/ui/modal_importar.dart`, `lib/features/importacao/ui/modal_previsao_importacao.dart`
- `lib/features/listas/ui/tela_lista_screen.dart`, `lib/features/convites/data/convites_repository.dart`
- `lib/core/l10n/app_strings.dart`, `lib/core/l10n/politica_privacidade.dart`
- comentários incidentais listados em §4.3

**Modificar (testes)**
- `test/features/importacao/modal_importar_test.dart`, `test/features/importacao/modal_previsao_importacao_test.dart`
- `test/features/listas/tela_lista_screen_test.dart`, `test/features/convites/convites_repository_test.dart`, `test/features/listas/categoria_test.dart`

**Modificar (docs)**
- `docs/00`, `01`, `03`, `05`, `06`, `07`, `09`, `10`, `11`, `12`, `13`, `14`, `relatorio-usabilidade-fase5.md`
- `README.md`, `AGENTS.md`, `planejamento_lista_compras.md`
- repontar as ocorrências de link `04-ia-edge-function.md` (≈34 no total, incluindo specs/planos históricos que permaneçam válidos)

## 6. Testes

- **Flutter:** remover os casos de modo IA de `modal_importar_test.dart` (fake/override de `ParseListaClient`) e de `tela_lista_screen_test.dart` (caso `deve_abrir_modal_importar_ia…`); manter e confirmar os casos do modo local. Ajustar `convites_repository_test.dart` para `erroSemConexao`. Suíte verde.
- **SQL:** `supabase db reset` aplica `0004` (cria) e `0013` (remove); rodar `rls_tests.sql`, `excluir_conta_tests.sql` (E-01…E-05) e `aceitar_convite_tests.sql` — verdes.
- **Guarda de regressão (grep):** nenhuma ocorrência de `gemini|GEMINI|parse-lista|parse_lista|ia_rate_limit|registrar_requisicao_ia|features/ia|ErroIa|iaSemConexao|responseSchema` em `lib/`, `test/`, `supabase/tests`, `.github/` nem nos docs donos. Ficam fora do escopo da guarda (histórico): `supabase/migrations/0004_ia_rate_limit.sql`, `supabase/migrations/0013_remover_ia_rate_limit.sql` e os specs/planos anteriores em `docs/superpowers/`.
- **CI:** `dart format --set-exit-if-changed .` + `flutter analyze` + `flutter test` + jobs `supabase` verdes.

## 7. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **04** | Reaproveitado como `04-importacao-lista.md`: dono do contrato do parser local (algoritmo, limites, enum, sugestão de categoria); remove contrato HTTP/prompt/`responseSchema`/rate limit/estrutura da function |
| **12 PRD** | Remove **RF-06** e **RNF-04** (tabela + matriz); reescreve RF-15 (sem “IA sugere no import”) e RF-16 (sem “IA permanece como modo opcional”); atualiza P3/US-08/matriz e o link do doc 04 |
| **00** | Produto/stack sem IA/Edge Functions/Gemini; remove riscos R-02/R-04, `GEMINI_API_KEY` dos segredos, linhas de cota; atualiza ADR-005/ADR-011, diagrama, cronograma (Fase 2) e índice |
| **01** | Árvore de migrations (nota da `0004`/`0013`), §3 sem `responseSchema`, §4.3/L168 sem IA |
| **03** | Nav e remissão de deduplicação sem IA |
| **05** | Árvore sem `features/ia/`; §6.2-6.4 sem modo IA; remove provider inexistente (L67); limites/link 04 |
| **06** | §1 DoD da Fase 2 e “Edge Function protegida” removidos; **tabela LGPD sem a linha Google Gemini**; §4 métricas sem IA |
| **07** | Matriz/scripts/jobs sem Edge Function/e2e; Sentry só Flutter |
| **09** | Remove a **seção 3 inteira** (Gemini/Edge Function: cota, erro, rotação da key), §4.3 (abuso da function) e linhas de Secrets/quota |
| **10** | Wireframes: sem “Importar por IA”, sem seletor Rápido\|IA; aviso do parser |
| **11** | T2 renomeado para importação de lista (parser local) |
| **13** | Stack/ADRs/contratos/comandos sem Gemini; remissão ao 04 |
| **14** | Nova **Fase 17**; Fase 2 anotada como removida e **linha F2 fora da tabela de progresso**; Fase 4 → “Sincronização”; ajustes F6-T05/F9-T05/F11; total segue **102/100** (102 − 5 da F2 + 5 da F17) |
| **README/AGENTS/planejamento** | Remover Gemini; AGENTS mapeia “importação em `04`”, remove regra `GEMINI_API_KEY` e comando `functions deploy` |

## 8. Fora de escopo

- Remover a **importação por texto** ou o parser local (RF-16) — permanecem.
- Reintroduzir outra IA/LLM ou outra Edge Function (a futura `enviar-convite` da Fase 7 fica intocada).
- Alterar schema/RLS/Realtime/sync para além do `drop` de `ia_rate_limit` e do ajuste de `excluir_conta`.
- Reescrever specs/planos históricos em `docs/superpowers/` (ficam como registro; corrigir apenas links que apontem ao doc 04 renomeado, se necessário).

## 9. Critério de pronto

- Nenhuma ocorrência de IA/Gemini em código, CI, segredos ou docs donos (guarda da §6).
- `docs/04-importacao-lista.md` é o dono da importação local; links repontados.
- Migrations `0004` + `0013` aplicam limpo; `excluir_conta_tests.sql` verde; `ia_rate_limit`/`registrar_requisicao_ia` não existem após `reset`.
- `dart format` + `flutter analyze` + `flutter test` verdes; CI verde.
- Checklist operacional (§10) executado ou agendado com o dono.

## 10. Operacional (manual, requer o dono)

Ordem obrigatória em produção:
1. `supabase functions delete parse-lista` (parar a IA **antes** de aplicar a migration; app antigo com modo IA passa a receber 404 → erro amigável, sem crash).
2. `supabase db push` (aplica `0013`).
3. `supabase secrets unset GEMINI_API_KEY`.
4. Revogar a API key no **Google AI Studio**.
5. Apagar os `.env` locais (`supabase/.env`, `supabase/functions/.env`) e o gerado `supabase/.temp/**/docker.env`.

## 11. Breakdown proposto (Fase 17)

- [ ] **F17-T00** — Spec + planejamento: RF-06/RNF-04 fora do 12, RF-15/16 reescritos, Fase 17 no 14, ajustes de índice — sem tocar código.
- [ ] **F17-T01** — Banco/backend: migration `0013` + `excluir_conta` recriado + `excluir_conta_tests.sql`; deletar `supabase/functions/parse-lista/`, `.env` e `parse_lista_e2e.mjs`; docs `01`/`04` (parte de banco).
- [ ] **F17-T02** — App: deletar `lib/features/ia/`; `ErroImportacao`; modal de modo único; rename `_importarLista`; strings e política de privacidade; comentários incidentais.
- [ ] **F17-T03** — Testes/CI: deletar `test/features/ia/`, ajustar testes compartilhados, limpar `ci.yml`, doc `07`.
- [ ] **F17-T04** — Docs e fechamento: reaproveitar `04-importacao-lista.md` e repontar links; `00/03/05/06/09/10/11/12/13/README/AGENTS/planejamento`; progresso em `14`; guarda de grep; CI verde.
