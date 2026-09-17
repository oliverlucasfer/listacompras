# Remoção da IA/Gemini — Implementation Plan (Fase 17)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remover integralmente o caminho de IA/Gemini (Edge Function `parse-lista`, modo IA do modal, `ia_rate_limit`, testes Deno/e2e, CI e segredos), deixando a importação de lista por texto apenas no modo local determinístico (RF-16).

**Architecture:** Remoção big-bang em cinco tarefas por camada — PRD/planejamento, banco (migration append-only `0013`), backend/CI, app Flutter + testes, e docs donos. Cada tarefa deixa a árvore verde (compila e testa). O doc dono `04` é reaproveitado como dono do parser local.

**Tech Stack:** Flutter/Dart 3 (Riverpod, Drift), PostgreSQL/Supabase (migrations SQL, RLS), Deno (a remover), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-17-remocao-ia-design.md`

## Global Constraints

- Escopo: remover **só** o caminho Gemini/IA. O import local (RF-16) **permanece** como único modo.
- `RF-06` e `RNF-04` **removidos** do PRD; **não renumerar** os demais RF/RNF.
- Migrations são **append-only**: `supabase/migrations/0004_ia_rate_limit.sql` permanece no repo; a remoção vai numa migration nova `0013`.
- **Nenhum segredo** em código/commit/log. A chave `GEMINI_API_KEY` é revogada fora do repo (checklist manual, não automatizável).
- RLS é sagrado: nenhuma mudança além de recriar `excluir_conta()` sem o `delete from ia_rate_limit`.
- Enum de unidades fechado e idêntico em Postgres (`01`), Dart e (extinto) `responseSchema`.
- Comentários apenas quando indispensáveis; pt-BR em docs/UI; commits pt-BR no padrão `F17-Tnn: ...`.
- Sempre rodar `dart format .`, `flutter analyze`, `flutter test` antes de cada commit de código.
- Ordem de produção (não executar agora, apenas registrar): `supabase functions delete parse-lista` **antes** de `supabase db push` (0013).

---

### Task 0 (F17-T00): PRD e planejamento

**Files:**
- Modify: `docs/12-prd.md` (RF/RNF, US-08, mapa do design, matriz)
- Modify: `docs/14-tarefas.md` (Fase 17, Fase 2, Fase 4, F6-T05, F9-T05, F11, progresso)
- Modify: `docs/13-premodelo-tecnico.md`
- Modify: `planejamento_lista_compras.md` (índice)

**Interfaces:**
- Consumes: spec `docs/superpowers/specs/2026-09-17-remocao-ia-design.md`
- Produces: IDs de fase `F17` e requisitos ajustados que os demais tasks citam.

- [ ] **Step 1: Remover RF-06 e RNF-04 de `docs/12-prd.md`**

Apagar a linha 30 inteira (`| RF-06 | Importação por texto livre via IA ...`). Apagar a linha 50 inteira (`| RNF-04 | Proteção da IA | ...`). Não renumerar nenhum outro ID.

- [ ] **Step 2: Reescrever RF-15 e RF-16 (linhas 39-40)**

Linha 39 — trocar:
`... (memória por nome → dicionário estático → \`outros\`); IA sugere no import |`
por:
`... (memória por nome → dicionário estático → \`outros\`) |`

Linha 40 — trocar:
`| RF-16 | Importação de lista por texto livre **sem IA** (parser local determinístico, offline) com pré-visualização editável; IA permanece como modo opcional | 05 §6.4 | F11 | [05 §8](05-app-flutter.md) |`
por:
`| RF-16 | Importação de lista por texto livre (parser local determinístico, offline) com pré-visualização editável | 05 §6.4 + 10 §4 | F11 | [05 §8](05-app-flutter.md) |`

- [ ] **Step 3: Ajustar RNF-07 e US-08**

Linha 53 — em RNF-07, trocar `Riscos R-01/R-02` por `Riscos R-01`.
Linhas 94-96 — trocar o bloco:
```
**US-08 — Sugestão automática sem IA**
Como P1 sem plano de IA, quero que itens comuns já venham categorizados mesmo offline, para não classificar manualmente.
- Given o app não usa IA, when digito "detergente" e pressiono Enter, then o item entra em Limpeza via dicionário local; nomes fora do dicionário entram em Outros e passam a ser lembrados (memória por nome).
```
por:
```
**US-08 — Sugestão automática local**
Como P1, quero que itens comuns já venham categorizados mesmo offline, para não classificar manualmente.
- Given o app usa um dicionário local, when digito "detergente" e pressiono Enter, then o item entra em Limpeza; nomes fora do dicionário entram em Outros e passam a ser lembrados (memória por nome).
```

- [ ] **Step 4: Atualizar o mapa do design (linha 107)**

Trocar:
`| IA e contrato serverless | [04](04-ia-edge-function.md) | Prompt, responseSchema, rate limit |`
por:
`| Importação de lista (parser local) | [04](04-importacao-lista.md) | Parser determinístico RF-16, limites, enum, sugestão de categoria |`

- [ ] **Step 5: Atualizar a matriz de rastreabilidade (linha 124)**

Apagar a linha `| RF-06 | US-02 | F4 | F2-T01…T05, F4-T01…T02 | Edge Function integração |`. Na linha do RF-16, trocar `F11-T01…T03` por `F11-T01…T03; F17-T01…T03`.

- [ ] **Step 6: Criar a Fase 17 em `docs/14-tarefas.md`**

Anotar o cabeçalho da Fase 2 (linha 39):
`## Fase 2 — Serviço de IA (Edge Function) — **removida na F17**`

Inserir, imediatamente antes de `## Progresso por fase (atualize ao concluir)`:
```markdown
## Fase 17 — Remoção da IA

Spec: [superpowers/specs/2026-09-17-remocao-ia-design.md](superpowers/specs/2026-09-17-remocao-ia-design.md) · Requisito: RF-16 (import local permanece); RF-06/RNF-04 removidos.

- [ ] **F17-T00** — PRD + planejamento (RF-06/RNF-04 fora do 12; Fase 17 no 14)
  Dep: — · Docs: [12](12-prd.md), [14](14-tarefas.md)
  CP: RF-06 e RNF-04 removidos do 12 (tabela + matriz); RF-15/RF-16 sem cláusulas de IA; Fase 17 no 14; sem tocar código.
- [ ] **F17-T01** — Migration `0013` + `excluir_conta` sem `ia_rate_limit`
  Dep: F17-T00 · Docs: [01](01-banco-de-dados.md), [06 §3.3.1](06-mvp-entregas.md)
  CP: `supabase db reset` aplica 0004+0013; `ia_rate_limit`/`registrar_requisicao_ia` inexistentes; `excluir_conta_tests.sql` E-01…E-05 verde.
- [ ] **F17-T02** — Remover Edge Function `parse-lista` e passos Deno/e2e do CI
  Dep: F17-T01 · Docs: [04](04-importacao-lista.md), [07](07-qualidade-ci.md)
  CP: pasta `supabase/functions/parse-lista/` e `parse_lista_e2e.mjs` removidos; CI sem setup-deno/deno test/e2e; pipeline verde.
- [ ] **F17-T03** — App: import local como único modo (+ testes Flutter)
  Dep: F17-T00 · Docs: [05 §6.4](05-app-flutter.md), [10 §4](10-wireframes-telas.md)
  CP: `lib/features/ia/` e `test/features/ia/` removidos; `ErroImportacao` no core; modal sem seletor de modo; strings sem prefixo `ia`; privacidade sem Gemini; `format`/`analyze`/`test` verdes.
- [ ] **F17-T04** — Docs donos, 04 reaproveitado e fechamento
  Dep: F17-T01, F17-T02, F17-T03 · Docs: [00](00-visao-geral.md), [04](04-importacao-lista.md), [12](12-prd.md), [14](14-tarefas.md)
  CP: `04-importacao-lista.md` dono do import local; ~34 links repontados; 00/03/05/06/09/10/11/13/README/AGENTS/planejamento sem IA/Gemini; guarda de grep da spec §6 vazia; Fase 17 na tabela de progresso.
```

- [ ] **Step 7: Ajustar a tabela de progresso (`docs/14-tarefas.md`, ~L423-440)**

Remover a linha `| F2 IA | 5 | 5 |`. Renomear `| F4 IA + Sync | 9 | 9 |` → `| F4 Sincronização | 9 | 9 |`. Inserir `| F17 Remoção da IA | 5 | 0 |` antes de `| **Total** | **102** | **100** |`. Ajustar o Total para `| **Total** | **102** | **95** |` enquanto a F17 não concluir (ao fechar a F17 volta a `102 | 100`).

- [ ] **Step 8: Ajustar `docs/13-premodelo-tecnico.md`**

- L13: remover a menção a “contrato de IA”.
- L24: backend sem “IA intermediada”.
- L25: apagar a linha `| IA | Gemini 2.0 Flash, JSON mode | Extrai itens de texto livre |`.
- L47/L49: remover “no `responseSchema` do Gemini” e “IA só refina o import”.
- L59-60: reescrever `### F3 — Importação IA` para `### F3 — Importação de lista (parser local)` e o fluxo `parse-lista/Gemini` para o fluxo local.
- L70-75: trocar o bloco “Contratos rápidos — Edge Function” (POST `parse-lista`, `cota_ia`) pelo contrato do parser local (`maxCaracteresImportLocal`, sem rede).
- L90: ADR-011 sem “IA só refina o import”.
- L104: remover `supabase functions deploy parse-lista`.

- [ ] **Step 9: Atualizar o índice `planejamento_lista_compras.md`**

- L17: trocar a linha do doc 04 por `**Importação de lista (parser local)** — contrato RF-16, limites, enum, sugestão de categoria`.
- L22: remover “cota Gemini”.
- L27: `F1–F16` → `F1–F17`.
- L34: remover `Gemini 2.0 Flash`.
- L38: trocar `Edge Function de IA` por `Importação local (parser)`.
- L44: remover/reescrever menções a Gemini.

- [ ] **Step 10: Commit**

```bash
git add docs/12-prd.md docs/14-tarefas.md docs/13-premodelo-tecnico.md planejamento_lista_compras.md
git commit -m "F17-T00: PRD e planejamento da remocao da IA (RF-16)"
```

---

### Task 1 (F17-T01): Banco de dados

**Files:**
- Create: `supabase/migrations/0013_remover_ia_rate_limit.sql`
- Modify: `supabase/tests/excluir_conta_tests.sql`
- Modify: `docs/01-banco-de-dados.md`

**Interfaces:**
- Consumes: nada (task independente).
- Produces: `public.excluir_conta()` sem dependência de `ia_rate_limit`; tabela/RPC ausentes — que Task 3 (app) e Task 4 (docs) assumem.

- [ ] **Step 1: Criar a migration `0013`**

```sql
-- 0013_remover_ia_rate_limit.sql — remoção do rate limit da IA
-- (spec F17, docs 04 e 09). A Edge Function parse-lista foi descontinuada;
-- a tabela e a RPC de rate limit deixam de existir.
-- `excluir_conta` é recriado sem a limpeza da tabela removida — era o único
-- vínculo restante (ver 0005_excluir_conta.sql).

drop function if exists public.registrar_requisicao_ia(uuid);
drop table if exists public.ia_rate_limit;

create or replace function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'autenticacao necessaria';
  end if;

  perform set_config('app.excluindo_conta', 'true', true);

  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;
```

- [ ] **Step 2: Remover o setup e a asserção de `ia_rate_limit` em `supabase/tests/excluir_conta_tests.sql`**

Remover o bloco (L45-47):
```sql
-- Rate limit da IA de E (sem FK — limpeza explícita no RPC).
insert into public.ia_rate_limit (user_id, janela, count)
values ('77777777-7777-7777-7777-777777777777', date_trunc('minute', now()), 1);
```
Remover a asserção (L92-93):
```sql
  select count(*) into c from public.ia_rate_limit where user_id = '77777777-7777-7777-7777-777777777777';
  if c > 0 then raise exception 'FALHOU E-03: ia_rate_limit do titular sobreviveu'; end if;
```
Atualizar o comentário do cabeçalho (L6) que menciona “TODAS as tabelas do titular” — mantém-se válido, nada a mudar.

- [ ] **Step 3: Rodar `supabase db reset`**

Run: `supabase db reset`
Expected: aplica `0001`…`0013` sem erro.

- [ ] **Step 4: Verificar que a tabela/RPC sumiram**

Run:
```powershell
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -c "select to_regclass('public.ia_rate_limit') as tabela, to_regprocedure('public.registrar_requisicao_ia(uuid)') as rpc;"
```
Expected: `tabela` e `rpc` ambos `NULL`.

- [ ] **Step 5: Rodar os testes de exclusão de conta**

Run: `psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/excluir_conta_tests.sql`
Expected: `OK E-01` … `OK E-05`, sem `FALHOU`.

- [ ] **Step 6: Atualizar `docs/01-banco-de-dados.md`**

- L5: trocar `o [04 IA](04-ia-edge-function.md) usa o enum...` por remissão ao `[04 Importação](04-importacao-lista.md)` (ou remover a frase).
- L44: na árvore de migrations, anotar `0004_ia_rate_limit.sql # rate limit da IA — removido na 0013 (F17)` e adicionar `├── 0013_remover_ia_rate_limit.sql # remove rate limit da IA (F17)`.
- L53: trocar `O [04 IA](04-ia-edge-function.md) replica estes valores no responseSchema;` por `O [04 Importação](04-importacao-lista.md) documenta o parser local;`.
- L168: trocar `(a **IA** e o usuário não criam item repetido...)` por `(o usuário não cria item repetido...)`.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0013_remover_ia_rate_limit.sql supabase/tests/excluir_conta_tests.sql docs/01-banco-de-dados.md
git commit -m "F17-T01: remove ia_rate_limit e RPC (RF-16)"
```

---

### Task 2 (F17-T02): Backend (Edge Function) e CI

**Files:**
- Delete: `supabase/functions/parse-lista/` (todos), `supabase/functions/.env`, `supabase/tests/parse_lista_e2e.mjs`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/07-qualidade-ci.md`

**Interfaces:**
- Consumes: `ia_rate_limit` já removido (Task 1) — nada mais referencia a function.
- Produces: CI sem qualquer step Deno/e2e.

- [ ] **Step 1: Deletar a Edge Function e artefatos**

```bash
git rm -r supabase/functions/parse-lista
git rm supabase/tests/parse_lista_e2e.mjs
```
`supabase/functions/.env` é untracked (`.gitignore:22`) — apagar do disco:
```powershell
Remove-Item -LiteralPath "supabase/functions/.env" -ErrorAction SilentlyContinue
Remove-Item -LiteralPath "supabase/.env" -ErrorAction SilentlyContinue
```

- [ ] **Step 2: Limpar `.github/workflows/ci.yml`**

Remover do job `supabase`:
- os dois steps `- uses: denoland/setup-deno@v2` (com `deno-version`), e
- os steps:
```yaml
      - name: Testes unitários das Edge Functions (deno)
        run: deno test --allow-env supabase/functions/parse-lista/
      - name: Testes e2e do contrato parse-lista (cenários sem Gemini)
        run: |
          supabase status -o env 2>&1 | grep -E '^(export )?(API_URL|SERVICE_ROLE_KEY)=' | sed -E 's/^export //; s/"//g; s/^/export /' > /tmp/sb_env.sh
          . /tmp/sb_env.sh
          npm ci --prefix supabase/tests
          node supabase/tests/parse_lista_e2e.mjs --sem-gemini
```
Manter o `supabase start -x studio …` (edge runtime será usado quando a Fase 7 criar `enviar-convite`). Atualizar o comentário do nome do step de start removendo “para e2e das functions”.

- [ ] **Step 3: Validar o YAML localmente**

Run: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml', encoding='utf-8'))" 2>$null; if (-not $?) { Write-Output "sem python, seguindo" }`
Expected: sem erro de parse (ou mensagem “sem python, seguindo”).

- [ ] **Step 4: Atualizar `docs/07-qualidade-ci.md`**

- L16: apagar a linha da matriz `| **Edge Function** (integração) | ... | Alta (RF-06, RNF-04) |`.
- L17: trocar “importação **IA**, auth | Média (RF-01…RF-06)” por “importação local, auth | Média (RF-01…RF-05, RF-16)”.
- L29: remover “Edge Function” da lista de alvos de teste.
- L47/L79: remover a linha/comentário `deno test nas Edge Functions`.
- L52: remover a nota do e2e de `parse-lista`/`SERVICE_ROLE_KEY`.
- L87: “Sentry ... nas Edge Functions” → “Sentry no Flutter”.
- L93: remover o item “Erros 422/500 da Edge Function”.

- [ ] **Step 5: Verificar que nada no repo referencia a function**

Run:
```powershell
Get-ChildItem -Path lib,test,supabase,.github -Recurse -File | Select-String -Pattern "parse-lista|parse_lista|GEMINI|gemini|deno test" | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
```
Expected: apenas `supabase/migrations/0004_ia_rate_limit.sql` (comentário histórico) e `0013_remover_ia_rate_limit.sql`.

- [ ] **Step 6: Commit**

```bash
git add -A .github/workflows/ci.yml docs/07-qualidade-ci.md supabase/functions supabase/tests/parse_lista_e2e.mjs
git commit -m "F17-T02: remove Edge Function parse-lista e passos Deno/e2e do CI"
```

---

### Task 3 (F17-T03): App Flutter — import local como único modo

**Files:**
- Create: `lib/core/importacao/erro_importacao.dart`
- Delete: `lib/features/ia/` (3 arquivos), `test/features/ia/parse_lista_client_test.dart`
- Modify: `lib/features/importacao/ui/modal_importar.dart`
- Modify: `lib/features/importacao/ui/modal_previsao_importacao.dart:17` (comentário)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart:192-202,368`
- Modify: `lib/features/convites/data/convites_repository.dart:146-150`
- Modify: `lib/core/l10n/app_strings.dart:152-186`
- Modify: `lib/core/l10n/politica_privacidade.dart:19`
- Modify: `lib/features/auth/data/supabase_auth_repository.dart:44`, `lib/features/convites/domain/convite.dart:6`, `lib/features/listas/domain/unidade.dart:2`, `lib/features/listas/domain/categoria.dart:2`
- Test: `test/features/importacao/modal_importar_test.dart` (reescrever), `test/features/importacao/modal_previsao_importacao_test.dart` (renomes), `test/features/listas/tela_lista_screen_test.dart` (remover caso IA), `test/features/convites/convites_repository_test.dart` (renome)

**Interfaces:**
- Consumes: `analisarListaLocal(_controller.text)` de `lib/core/importacao/parser_lista_local.dart`; `maxCaracteresImportLocal` de `lib/core/importacao/resposta_import.dart`; `sugestaoCategoriasProvider` de `lib/features/listas/providers/listas_providers.dart`.
- Produces: `ErroImportacao(String mensagem)`; `AppStrings.import*` / `AppStrings.erroSemConexao`; `abrirModalImportar(context, ref, listaId)` sem `modoInicial`.

- [ ] **Step 1: Criar `lib/core/importacao/erro_importacao.dart`**

```dart
/// Erro da importação local (RF-16): mensagem amigável pronta para a UI.
class ErroImportacao implements Exception {
  const ErroImportacao(this.mensagem);

  final String mensagem;
}
```

- [ ] **Step 2: Reescrever o bloco de strings em `lib/core/l10n/app_strings.dart` (L152-186)**

Remover `iaSessaoExpirada`, `iaTextoVazio`, `iaTextoLongo`, `iaRateLimit`, `iaCotaIa`, `iaTimeoutIa`, `iaErroInterno`, `modoIa`, `modoRapido` (e o bloco “Mensagens amigáveis do contrato de IA”). Substituir o trecho restante por:
```dart
  // Importação de lista (RF-16, doc 04): parser local offline
  static const fechar = 'Fechar';
  static const importColeOuDigite = 'Cole ou digite sua lista:';
  static const importExemplo = '1kg de arroz, 2 leites, 500g de queijo prato...';
  static const importExtrairItens = 'Extrair itens';
  static const importLendo = 'Lendo...';
  static const importConfirmeItens = 'Confirme os itens';
  static const importRespostaInvalida =
      'Não consegui entender a lista. Tente reescrever.';
  static const erroSemConexao =
      'Sem conexão. Verifique sua internet e tente novamente.';

  static String importAdicionarN(int n) => 'Adicionar $n';
  static String importSeraoAdicionados(int n, int total) =>
      '$n de $total serão adicionados';

  // Importação de lista (RF-16): modo local sem IA
  static const importarLista = 'Importar lista';
  static const importLocalAvisoPadrao =
      'Itens sem quantidade entraram com 1 un.';
  static const importLocalTextoLongo =
      'Texto muito longo. Envie até 10.000 caracteres.';
```
Atenção: `fechar` estava na linha 153, preservar exatamente uma definição (não duplicar).

- [ ] **Step 3: Reescrever `lib/features/importacao/ui/modal_importar.dart`**

Conteúdo final completo:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/importacao/erro_importacao.dart';
import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/importacao/resposta_import.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../listas/providers/listas_providers.dart';

/// Abre o modal de entrada da importação de lista (doc 04, wireframe 10 §4.1,
/// RF-16). Retorna os itens extraídos, ou null se cancelado.
Future<RespostaParse?> abrirModalImportar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) {
  return showDialog<RespostaParse>(
    context: context,
    builder: (_) => ModalImportar(listaId: listaId),
  );
}

class ModalImportar extends ConsumerStatefulWidget {
  const ModalImportar({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<ModalImportar> createState() => _ModalImportarState();
}

class _ModalImportarState extends ConsumerState<ModalImportar> {
  final _controller = TextEditingController();
  bool _carregando = false;
  String? _erro;

  int get _limite => maxCaracteresImportLocal;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _erro = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _caracteres => _controller.text.length;

  bool get _podeExtrair =>
      !_carregando &&
      _controller.text.trim().isNotEmpty &&
      _caracteres <= _limite;

  Future<void> _extrair() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await _extrairLocal(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroImportacao catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.mensagem;
        });
      }
    }
  }

  /// Parser local + categoria pela cadeia do app (memória → dicionário).
  Future<RespostaParse> _extrairLocal(String texto) async {
    final parse = analisarListaLocal(texto);
    if (parse.itens.isEmpty) {
      throw const ErroImportacao(AppStrings.importRespostaInvalida);
    }
    final sugestao = ref.read(sugestaoCategoriasProvider);
    final enriquecidos = <ItemExtraido>[];
    for (final item in parse.itens) {
      final categoria = await sugestao.sugerirCategoria(item.nome);
      enriquecidos.add(
        ItemExtraido(
          nome: item.nome,
          quantidade: item.quantidade,
          unidade: item.unidade,
          categoria: categoria,
        ),
      );
    }
    return RespostaParse(itens: enriquecidos, aviso: parse.aviso);
  }

  @override
  Widget build(BuildContext context) {
    final excedeu = _caracteres > _limite;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(AppStrings.importarLista)),
          IconButton(
            tooltip: AppStrings.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.importColeOuDigite),
          const SizedBox(height: AppSpacing.sm),
          AppCampoTexto(
            controller: _controller,
            hint: AppStrings.importExemplo,
            teclado: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLength: _limite,
            minLines: 5,
            maxLines: 5,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_caracteres/$_limite',
              style: excedeu
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
          ],
          const SizedBox(height: AppSpacing.md),
          AppBotao(
            rotulo: _carregando
                ? AppStrings.importLendo
                : AppStrings.importExtrairItens,
            icone: Icons.bolt_outlined,
            carregando: _carregando,
            onPressed: _podeExtrair ? _extrair : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Ajustar `lib/features/listas/ui/tela_lista_screen.dart`**

Trocar o comentário e o nome (L192-194):
```dart
  /// Importação de lista (doc 05 §6.4, RF-16): entrada → pré-visualização
  /// → gravação local dos itens confirmados.
  Future<void> _importarLista(
```
Trocar a chamada (L368):
```dart
                        onPressed: () => _importarLista(context, ref, listaId),
```
Manter `icone: Icons.smart_toy_outlined` ou trocar para `Icons.playlist_add` (opcional; se trocar, atualizar o wireframe 10 §3.4 apenas se ele citar o ícone).

- [ ] **Step 5: Ajustar convites e comentários incidentais**

`lib/features/convites/data/convites_repository.dart` L146, L148, L150: `AppStrings.iaSemConexao` → `AppStrings.erroSemConexao`.
`lib/features/convites/domain/convite.dart:6`: `(padrão de \`ErroIa\`, doc 04 §2)` → `(padrão de erro com code + mensagem amigável)`.
`lib/features/auth/data/supabase_auth_repository.dart:44`: remover menção a `ia_rate_limit` do comentário.
`lib/features/listas/domain/unidade.dart:2` e `categoria.dart:2`: remover menção a `responseSchema` da IA.
`lib/features/importacao/ui/modal_previsao_importacao.dart:17`: `RF-06` → `RF-16`; L346-347: trocar “sugestão da IA” por “sugestão local”.
`lib/features/importacao/ui/modal_previsao_importacao.dart` L94/160/176: `iaConfirmeItens`→`importConfirmeItens`, `iaSeraoAdicionados`→`importSeraoAdicionados`, `iaAdicionarN`→`importAdicionarN`.

- [ ] **Step 6: Ajustar a política de privacidade**

`lib/core/l10n/politica_privacidade.dart:19` — substituir:
`Seus dados ficam hospedados no Supabase (infraestrutura AWS). Para a função de importação por texto, o trecho que você colar é enviado ao Google Gemini para extração dos itens, sem identificadores pessoais. Registros de erro podem ser processados pelo Sentry, sem conteúdo das suas listas. Não vendemos nem compartilhamos seus dados com mais ninguém.`
por:
`Seus dados ficam hospedados no Supabase (infraestrutura AWS). A importação por texto acontece inteiramente no seu dispositivo (parser local, offline) — nenhum trecho colado é enviado a terceiros. Registros de erro podem ser processados pelo Sentry, sem conteúdo das suas listas. Não vendemos nem compartilhamos seus dados com mais ninguém.`

- [ ] **Step 7: Reescrever `test/features/importacao/modal_importar_test.dart`**

Conteúdo final completo:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/resposta_import.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/importacao/ui/modal_importar.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  FilledButton botaoExtrair(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
  );

  Future<void> abrir(
    WidgetTester tester, {
    ValueChanged<RespostaParse?>? onResultado,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: _TelaAbrirModal(onResultado: onResultado)),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('deve_desabilitar_extrair_quando_texto_vazio', (tester) async {
    await abrir(tester);
    expect(botaoExtrair(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_contador_atualizado_quando_digitar', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    expect(find.text('5/10000'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_bloquear_extracao_e_vermelho_quando_passa_de_10000', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'x' * 10001);
    await tester.pump();
    expect(find.text('10001/10000'), findsOneWidget);
    final contador = tester.widget<Text>(find.text('10001/10000'));
    final contexto = tester.element(find.text('10001/10000'));
    expect(contador.style?.color, Theme.of(contexto).colorScheme.error);
    expect(botaoExtrair(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_itens_quando_extracao_sucesso', (tester) async {
    RespostaParse? recebida;
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.enterText(find.byType(TextField), '1kg de arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(1));
    expect(recebida!.itens.single.nome, 'Arroz');
    expect(recebida!.itens.single.unidade.valor, 'kg');
    expect(find.text(AppStrings.importColeOuDigite), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_extrair_multiplos_itens_localmente', (tester) async {
    RespostaParse? recebida;
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.enterText(find.byType(TextField), '1kg de arroz, 2 leites');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(recebida!.itens, hasLength(2));
    expect(recebida!.itens.first.unidade.valor, 'kg');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_erro_quando_nenhum_item_reconhecido', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), ',,,');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.importRespostaInvalida), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_null_quando_fechar', (tester) async {
    RespostaParse? recebida = const RespostaParse(itens: [], aviso: null);
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.tap(find.byTooltip(AppStrings.fechar));
    await tester.pumpAndSettle();
    expect(recebida, isNull);
    expect(find.text(AppStrings.importColeOuDigite), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TelaAbrirModal extends ConsumerWidget {
  const _TelaAbrirModal({this.onResultado});

  final ValueChanged<RespostaParse?>? onResultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final resposta = await abrirModalImportar(context, ref, 'lista-1');
            onResultado?.call(resposta);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}
```
Nota: o teste de estado “Lendo...” do modo IA foi removido — o parser local não tem espera de I/O observável de forma determinística (antes era segurada por um `Completer` HTTP).

- [ ] **Step 8: Ajustar os testes compartilhados**

`test/features/importacao/modal_previsao_importacao_test.dart`: renomear `iaAdicionarN`→`importAdicionarN`, `iaSeraoAdicionados`→`importSeraoAdicionados`, `iaConfirmeItens`→`importConfirmeItens` (linhas 84, 113, 114, 125, 128, 148, 150, 165, 191, 294, 354, 386).
`test/features/convites/convites_repository_test.dart` L135 e L158: `AppStrings.iaSemConexao` → `AppStrings.erroSemConexao`.
`test/features/listas/categoria_test.dart:5`: remover menção a `responseSchema`.

- [ ] **Step 9: Remover o teste de IA da tela da lista**

Em `test/features/listas/tela_lista_screen_test.dart`: apagar o teste `deve_abrir_modal_importar_ia_quando_tocar_botao` (L738-780). Remover os imports agora sem uso: `package:http/http.dart as http` (L8), `package:http/testing.dart` (L9), `features/ia/data/parse_lista_client.dart` (L21), `features/ia/providers/ia_providers.dart` (L22). Se quiser cobrir a abertura do modal sem IA, adicionar:
```dart
  testWidgets('deve_abrir_modal_importar_quando_tocar_botao', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.importarLista));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.importColeOuDigite), findsOneWidget);
    expect(find.text(AppStrings.importExtrairItens), findsOneWidget);

    await fechar(tester);
  });
```

- [ ] **Step 10: Deletar `lib/features/ia/` e `test/features/ia/`**

```bash
git rm -r lib/features/ia test/features/ia
```

- [ ] **Step 11: Formatar, analisar e testar**

Run: `dart format .`
Run: `flutter analyze`
Expected: “No issues found!”
Run: `flutter test`
Expected: toda a suíte verde.

- [ ] **Step 12: Guarda de regressão (lib/test)**

Run:
```powershell
Get-ChildItem -Path lib,test -Recurse -Filter *.dart | Select-String -Pattern "gemini|GEMINI|parse-lista|parse_lista|ia_rate_limit|features/ia|ErroIa|iaSemConexao|responseSchema|ModoImportacao|maxCaracteresEntradaIa" | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
```
Expected: sem saída.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "F17-T03: import local como unico modo e remove cliente de IA (RF-16)"
```

---

### Task 4 (F17-T04): Docs donos, 04 reaproveitado e fechamento

**Files:**
- Rename/rewrite: `docs/04-ia-edge-function.md` → `docs/04-importacao-lista.md`
- Modify: `docs/00-visao-geral.md`, `docs/03-sincronizacao-offline.md`, `docs/05-app-flutter.md`, `docs/06-mvp-entregas.md`, `docs/09-runbook-operacoes.md`, `docs/10-wireframes-telas.md`, `docs/11-usabilidade-fase5.md`, `docs/relatorio-usabilidade-fase5.md`
- Modify: `README.md`, `AGENTS.md`, `planejamento_lista_compras.md`
- Modify: `docs/14-tarefas.md` (marcar Fase 17 e progresso)
- Modify (repoint de links): demais docs que citam `04-ia-edge-function.md`

**Interfaces:**
- Consumes: Tasks 1-3 concluídas (código e banco sem IA).
- Produces: documentação normativa consistente; nenhum link quebrado.

- [ ] **Step 1: Renomear e reescrever o doc 04**

```bash
git mv docs/04-ia-edge-function.md docs/04-importacao-lista.md
```
Conteúdo final:
```markdown
# 04 — Importação de lista (parser local)

> Navegação: [← 03 Sincronização](03-sincronizacao-offline.md) · [05 App Flutter →](05-app-flutter.md)

**Este documento é o dono do contrato da importação de lista por texto (RF-16): parser local determinístico, limites de entrada, enums e sugestão de categoria.** O app é offline-first: a extração acontece inteiramente no dispositivo, sem rede e sem IA.

---

## 1. Visão geral

```
Texto colado/colado ─► analisarListaLocal()  (lib/core/importacao/parser_lista_local.dart)
                          │ parser determinístico, offline
                          ▼
                    Sugestão de categoria (memória → dicionário → outros)
                          │
                    Pré-visualização editável ─► confirmação ─► gravação local (fila)
```

Fluxo de UX completo (modal, pré-visualização, confirmação) está em [05 §6.4](05-app-flutter.md) e [10 §4](10-wireframes-telas.md).

---

## 2. Contrato

- **Entrada:** texto livre em português, até **10.000 caracteres** (`maxCaracteresImportLocal`).
- **Saída:** `RespostaParse { itens: List<ItemExtraido>, aviso: String? }`.
- **Erro:** quando nenhum item é reconhecido, `ErroImportacao` com mensagem amigável (`AppStrings.importRespostaInvalida`); a UI nunca vê exceção crua.
- **Rede:** nenhuma. Não há chamada HTTP, Edge Function, API key ou rate limit.
- **`aviso`:** preenchido quando algum item entra com quantidade padrão (`AppStrings.importLocalAvisoPadrao`).

## 3. Algoritmo do parser

`analisarListaLocal(texto)`:

1. Segmenta o texto por `,`, `;`, quebra de linha e o conectivo ` e `.
2. Para cada segmento, lê quantidade/unidade no **início** ou no **fim** (`1kg de arroz`, `arroz 1kg`, `2 leites`, `leite 2`).
3. Sem quantidade → `1 un` e marca `aviso`.
4. Converte quantidade com vírgula (`1,5` → `1.5`); capitaliza o nome; ignora segmentos vazios.
5. `interpretarItemAvulso(texto, {unidadePadrao})` é usado pelo campo "Adicionar item" (F12-T06): unidade explícita do texto vence; sem unidade, usa a do seletor.

## 4. Enums

- **Unidades** (fonte única [01 §3.1](01-banco-de-dados.md)): `un, kg, g, l, ml, caixa, pacote, pct, dz` — replicado em `lib/features/listas/domain/unidade.dart`.
- **Categorias** (fonte única [01 §3.2](01-banco-de-dados.md)): `hortifruti, mercearia, frios, laticinios, congelados, padaria, bebidas, pet, limpeza, higiene, outros`.

## 5. Sugestão de categoria

Cadeia local em camadas (RF-15): memória por nome → dicionário estático → `outros` (`lib/core/categorias/sugestao_categorias.dart`). Não há IA; o usuário pode editar a categoria na pré-visualização.

## 6. Estrutura no repositório

```
lib/core/importacao/
├── parser_lista_local.dart   # parser determinístico (RF-16)
├── resposta_import.dart      # ItemExtraido / RespostaParse / limite
└── erro_importacao.dart      # ErroImportacao (mensagem amigável)

test/core/importacao/parser_lista_local_test.dart
test/features/importacao/modal_importar_test.dart
```

## 7. Testes

- `flutter test test/core/importacao/parser_lista_local_test.dart` (unit do parser)
- `flutter test test/features/importacao/` (modal + pré-visualização)
- `flutter test` — suíte completa; CI verde ([07](07-qualidade-ci.md)).

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — enums (fonte única)
- [05 App Flutter](05-app-flutter.md) — modal de importação e pré-visualização
- [12 PRD](12-prd.md) — RF-16
```

- [ ] **Step 2: Repontar os links para o doc 04**

Substituir todas as ocorrências de `04-ia-edge-function.md` por `04-importacao-lista.md` e ajustar o rótulo quando disser “IA / Edge Function”. Os números de linha abaixo refletem o estado **antes** da Task 0; após aquelas edições, localize cada link por busca (`04-ia-edge-function.md`). Arquivos (path:linha):
```
planejamento_lista_compras.md:17
docs/00-visao-geral.md:19, 106, 137, 152
docs/01-banco-de-dados.md:5, 53
docs/03-sincronizacao-offline.md:3, 137
docs/05-app-flutter.md:3, 177, 183, 223
docs/06-mvp-entregas.md:33
docs/07-qualidade-ci.md:16
docs/09-runbook-operacoes.md:90, 105
docs/10-wireframes-telas.md:225
docs/12-prd.md:50, 107
docs/13-premodelo-tecnico.md:60, 70
docs/14-tarefas.md:42, 45, 48, 51, 90, 161
docs/superpowers/specs/2026-09-11-importacao-local-design.md:52, 86
docs/superpowers/plans/2026-09-11-importacao-local.md:50, 56, 81, 99, 131
docs/superpowers/specs/2026-09-08-agrupamento-categorias-design.md:82, 141
```
Nas linhas que forem tarefas históricas (14:42/45/48/51) mantêm-se o texto histórico, apenas o link de arquivo é repontado — se a linha descrever algo inexistente, marcar o link como histórico não é necessário.

- [ ] **Step 3: Atualizar `docs/00-visao-geral.md`**

- L11: remover “com **Inteligência Artificial**”.
- L19: `| Importação inteligente por texto | IA extrai itens ... | [04 IA / Edge Function] |` → `| Importação por texto | Parser local determinístico (offline) extrai itens e sugere categoria | [04 Importação] |`.
- L28-54: no diagrama, remover a caixa `SUPABASE EDGE FUNCTIONS`, o ramo “Texto para extração” e a caixa `GOOGLE GEMINI API`.
- L61/L72: remover `Edge Functions` da linha de backend/tabela de tecnologia.
- L63: apagar a linha `| IA | **Google Gemini API** ... |`.
- L73: apagar a linha `| [Google AI Studio] | API Key do Gemini | ... |`.
- L81: remover “deploy das Edge Functions”.
- L82: apagar a linha do Node.js/Deno (ambiente das Edge Functions).
- L89: remover o item do checklist `API Key do Gemini ... supabase secrets set GEMINI_API_KEY ...`.
- L96: apagar a linha `| GEMINI_API_KEY | Supabase Secrets | repo, client, logs |`.
- L105: em R-01, remover “/IA”.
- L106: apagar o risco R-02 (cota Gemini).
- L108: apagar o risco R-04 (API key do Gemini).
- L122: ADR-005 — remover “alimenta o responseSchema do Gemini”.
- L128: ADR-011 — remover IA/responseSchema.
- L137: apagar a linha da Fase 2 no cronograma.
- L139: Fase 4 → “Integrar Sincronização”.
- L152: índice do doc 04 → `[04 Importação](04-importacao-lista.md) — parser local (RF-16)`.
- Cada renumeração de risco/ADR deve manter os IDs existentes (não renumerar).

- [ ] **Step 4: Atualizar `docs/05-app-flutter.md`**

- L3: nav → `[← 04 Importação]`.
- L43-45: remover o bloco `features/ia/` da árvore de pastas.
- L67: apagar a linha do `importacaoIaProvider` (provider inexistente).
- L78: remover “A IA não entra nesta cadeia…”.
- L110-128: trocar “Entrada por Texto Inteligente (IA)” / “Importar por IA” por “Importação de lista (parser local)”.
- L160: `| Botão de importação IA | Abre modal (6.4) |` → `| Botão de importação | Abre modal (6.4) |`.
- L173: título `### 6.4. Modal "Importar lista" (RF-16)`.
- L175-183: remover o seletor Rápido|IA e o item do modo IA; limite único `10.000`; erros do parser local; pré-visualização por repositório local.
- L212: CP de importação → parser local.
- L223: índice → `[04 Importação]`.

- [ ] **Step 5: Atualizar `docs/06-mvp-entregas.md`**

- L16: `*(RF-06)*` → `*(RF-16)*`.
- L20: remover o critério “Edge Function protegida: … trata erros do Gemini … *(RNF-04)*”.
- L33: apagar a linha `| **2 — IA** | ... |` da tabela de DoD.
- L35: reescrever a Fase 4 como “Sync”.
- L59: apagar a linha `| Google Gemini API | ... | EUA |` da tabela de subprocessadores (LGPD).
- L111: “Tempo médio de criação de lista via **IA** < 30s” → “via importação por texto < 30s”.
- L113: remover “Taxa de erro da **Edge Function** < 2%”.

- [ ] **Step 6: Atualizar `docs/09-runbook-operacoes.md`**

- L5: remover “**cota do Gemini**”.
- L14: apagar a linha `| GEMINI_API_KEY | ... | Edge Function de IA |`.
- L16: “Sentry ... Erros de app e Edge Function” → “Erros do app”.
- L18: apagar a linha `| Google AI Studio | ... |`.
- L56: apagar a linha `| Edge Function invocations | ... |`.
- L80: remover “Edge Functions”.
- L86: apagar a linha `supabase functions deploy parse-lista` (e `GEMINI_API_KEY`).
- L88/L90/L91: remover menções a contrato da function / importação IA / redeploy.
- L96-124: apagar a **seção 3 inteira** (“Gemini / Edge Function” — 3.1 cota, 3.2 erro, 3.3 rotação da key). Renumerar as seções seguintes, se o doc usar numeração sequencial.
- L143-147: apagar a subseção “Suspeita de abuso da Edge Function” (`ia_rate_limit`).
- L163: remover “Edge Function segue 3.2”.
- L170: “Uso de quotas Supabase/**Gemini**” → “Uso de quotas Supabase”.

- [ ] **Step 7: Atualizar `docs/10-wireframes-telas.md`**

- L20: remover “IA” do título da tela de login.
- L114: “Crie sua primeira lista ou **importe por texto com IA**.” → “Crie sua primeira lista ou **importe por texto**.”.
- L179: `(🤖 Importar por IA)` → `(Importar lista)`.
- L225: título `## 4. Importação de lista (RF-16 — [04](04-importacao-lista.md))`.
- L232: remover a linha do seletor `( Rápido | IA )`.
- L239: “contador; Rápido ≤ 10.000” → “contador ≤ 10.000”.
- L241: “Rápido: sem rede; IA: spinner + ‘Lendo…’” → “sem rede; spinner + ‘Lendo…’”.
- L243: remover remissão ao contrato de IA.
- L251: “aviso da IA” → “aviso do parser”.
- L301: “Botão com spinner (IA)” → “Botão com spinner”.

- [ ] **Step 8: Atualizar `docs/11-usabilidade-fase5.md` e o relatório**

- `docs/11-usabilidade-fase5.md` L44: `### T2 — Importação por IA` → `### T2 — Importação de lista (parser local)`.
- L46: “descobre o **botão IA** sozinho?” → “descobre o botão **Importar lista** sozinho?”.
- `docs/relatorio-usabilidade-fase5.md` L25: renomear T2 sem IA.

- [ ] **Step 9: Atualizar raiz**

`README.md`:
- L3: `(Flutter + Supabase + **Gemini**)` → `(Flutter + Supabase)`.
- L6: reescrever o bullet de IA para parser local.
- L12: remover `Gemini 2.0 Flash` da stack.

`AGENTS.md`:
- L3: remover `+ Gemini`.
- L16: `IA em \`04\`` → `importação em \`04\``.
- L17: apagar a regra do `GEMINI_API_KEY`.
- L20: remover `e \`responseSchema\` (\`04\`)`.
- L30: apagar a linha `supabase functions deploy parse-lista`.

`planejamento_lista_compras.md`:
- L5: `...entrada manual e importação por IA (texto livre)...` → `...entrada manual e importação de lista por texto...`.
- L34: remover `+ Edge Functions` de `Supabase (Postgres + Auth + Realtime + Edge Functions + RLS)` → `Supabase (Postgres + Auth + Realtime + RLS)`.
- L38: `4. **IA + Sync offline-first**` → `4. **Sincronização offline-first**`.

- [ ] **Step 10: Fechar a Fase 17 em `docs/14-tarefas.md`**

Marcar `- [x]` em `F17-T00`…`F17-T04` e ajustar a tabela de progresso (linha `| F17 Remoção da IA | 5 | 5 |`; Total de volta a `| **Total** | **102** | **100** |`).

- [ ] **Step 11: Guarda de regressão final**

Run:
```powershell
Get-ChildItem -Path lib,test,supabase/tests,.github -Recurse -File | Select-String -Pattern "gemini|GEMINI|parse-lista|parse_lista|ia_rate_limit|registrar_requisicao_ia|features/ia|ErroIa|iaSemConexao|responseSchema" | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
Get-ChildItem -Path docs -Filter *.md | Select-String -Pattern "Gemini|responseSchema|cota_ia|importa..o por IA" | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
```
Expected: somente ocorrências históricas em `supabase/migrations/0004_ia_rate_limit.sql`, `0013_remover_ia_rate_limit.sql` e nos specs/planos anteriores de `docs/superpowers/`. As menções a “Edge Function” em `docs/02`/`docs/08` são do fluxo `enviar-convite` (Fase 7) e **permanecem** — por isso não entram na guarda. A seção `## Fase 2 — Serviço de IA (Edge Function) — **removida na F17**` em `docs/14-tarefas.md` (título + tarefas F2-T01…T05) é registro histórico e fica **fora** da guarda.

- [ ] **Step 12: Verificação final**

Run: `dart format .`
Run: `flutter analyze`
Expected: “No issues found!”
Run: `flutter test`
Expected: suíte verde.
Run: `supabase db reset`
Run: `psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/excluir_conta_tests.sql`
Expected: E-01…E-05 OK.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "F17-T04: reaproveita 04 como importacao local e sincroniza docs (RF-16)"
```

---

## Checklist operacional (fora do repo — executar com o dono, só no lançamento)

- [ ] `supabase functions delete parse-lista` (antes do `db push`).
- [ ] `supabase db push` (aplica `0013`).
- [ ] `supabase secrets unset GEMINI_API_KEY`.
- [ ] Revogar a API key no Google AI Studio.
- [ ] Apagar `.env` locais (`supabase/.env`, `supabase/functions/.env`) e o gerado `supabase/.temp/**/docker.env` (já feito no Task 2, repetir se regenerado).
