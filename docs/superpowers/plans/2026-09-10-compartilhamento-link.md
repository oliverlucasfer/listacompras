# Compartilhamento por Link (F7) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convidar pessoas por link (papel editor/leitor) para uma lista, com aceite via RPC idempotente, Realtime de participação e UI completa de membros.

**Architecture:** Migration 0007 (tabela `convites` + RLS + RPC + publication), seguindo verbatim o doc dono 08 §2/§3.1/§7. Client: `ConvitesRepository` com chamadas diretas ao servidor (sem fila offline), papel do usuário em memória (`PapelRepository` alimentado pelo bootstrap + eventos Realtime de `lista_membros`), feature `convites` nova com UI reusando os padrões existentes (Riverpod + go_router + strings centralizadas).

**Tech Stack:** Flutter + Riverpod + go_router + Drift + supabase_flutter; Postgres migrations + scripts de teste SQL em `supabase/tests/`.

**Spec:** [`docs/superpowers/specs/2026-09-10-compartilhamento-link-design.md`](../specs/2026-09-10-compartilhamento-link-design.md)

## Global Constraints

- Doc dono: [`08`](../../../docs/08-compartilhamento-colaborativo.md); decisões da rodada em §1.1. O SQL de `convites`/`aceitar_convite` lá é normativo.
- `sync_dono` intocado (transferência adiada). Convites gerados só com `tipo = 'link'`.
- Nenhuma chave/segredo em código, commit ou log.
- Comentários só quando indispensáveis; nomes camelCase (Dart) / snake_case (SQL); todas as strings da UI em `lib/core/l10n/app_strings.dart`.
- Testes nomeados `deve_<resultado>_quando_<condição>`; TDD: teste → FAIL → implementar → PASS.
- Convite é operação online por natureza: sem fila do Drift; falha de rede → estado de erro com retry manual.
- Scheme deep link existente: `br.com.oliverlucas.listacompras` (auth usa host `login-callback`); convite usará host `entrar`.
- Drift não muda (v3 permanece): papel fica em memória, recarregado a cada bootstrap.
- Cada tarefa termina com `dart format . && flutter analyze` limpos e `flutter test` verde. Tarefa SQL fecha com `supabase db reset` + testes SQL locais rodando ok.
- Mensagem de commit em pt-BR, citando ID da tarefa e RF (`F7-Txx: ... (RF-13)`).

---

### Task 1: Migration 0007 — `convites`, RLS, RPC `aceitar_convite`, publication (F7-T01)

**Files:**
- Create: `supabase/migrations/0007_convites.sql`
- Create: `supabase/tests/aceitar_convite_tests.sql`
- Modify: `supabase/tests/rls_tests.sql` (acrescentar N-11…N-14 ao final, no mesmo formato dos casos existentes)
- Modify: `docs/02-seguranca-rls.md` §5 (documentar N-11…N-14 — regra do AGENTS.md: doc dono no mesmo PR)
- Modify: `.github/workflows/ci.yml` (job `supabase`: acrescentar `aceitar_convite_tests.sql` à lista de arquivos executados — seguir como `excluir_conta_tests.sql` está wired)

**Interfaces:**
- Produces: tabela `public.convites` (colunas do 08 §2); RPC `public.aceitar_convite(p_token uuid) returns uuid` com exceções `CONVITE_INVALIDO` e `CONVITE_NAO_DIRIGIDO_A_VOCE` — consumidos pela Task 2 (Dart) e validados nesta tarefa por SQL.

- [ ] **Step 1: Escrever a migration (sem placeholders — copiar o SQL de 08 §2 e §3.1 exatamente como está lá)**

Estrutura do arquivo (ordem):

1. Cabeçalho de comentário apontando 08 §2/§3.1/§7 e RF-13.
2. `create table public.convites ...` — verbatim do 08 §2 (com os dois índices parciais).
3. `alter table public.convites enable row level security;` + `force row level security;`.
4. Policies conforme a tabela de RLS do 08 §2:
   - SELECT para dono da lista (`exists (select 1 from public.lista_membros m where m.lista_id = convites.lista_id and m.user_id = auth.uid() and m.papel = 'dono')`);
   - SELECT para qualquer autenticado ver apenas convites `tipo='email'` dirigidos a si (condição `estado = 'pendente'`; irrelevante nesta rodada, exigida pelo doc);
   - INSERT para dono com `with check (criado_por = auth.uid())`;
   - UPDATE (revogar) para dono;
   - DELETE para dono.
5. RPC `aceitar_convite` — o bloco plpgsql verbatim do 08 §3.1.
6. Publication: `alter publication supabase_realtime add table public.lista_membros;` e `alter publication supabase_realtime add table public.convites;` (08 §7).

- [ ] **Step 2: Aplicar e validar**

Run: `supabase db reset`
Expected: sem erros.

Smoke (psql após reset):
```sql
\df public.aceitar_convite
select count(*) = 0 from public.convites;
```
Expected: função listada; tabela vazia.

- [ ] **Step 3: Escrever testes SQL primeiro (TDD no banco)**

`supabase/tests/aceitar_convite_tests.sql` — setup pré-existente dos testes (usuários A/B via `auth.users`, autenticação) copiando o bootstrapping de `excluir_conta_tests.sql`. Casos:
- A-01: link pendente válido → CREATE USER B autenticado chama `select public.aceitar_convite('<token>')` → retorna `lista_id`; `lista_membros` tem linha (B, papel_oferecido); convite `estado = 'aceito'`.
- A-02: mesmo convite aceito 2ª vez (B ou C), idempotente: retorna `lista_id`, não duplica membro.
- A-03: convite expirado (`expira_em in the past`: update manual `expira_em = now() - interval '1 day'` na preparação de um cenário separado) → exception `CONVITE_INVALIDO`.
- A-04: convite revogado (`estado = 'revogado'`) → exception `CONVITE_INVALIDO`.
- A-05: anon não aceita (`select ... aceitar_convite` como anon → exception; security definer não abre portão para anônimo porque o corpo usa `auth.uid()` — sem uid deve rejeitar; validar comportamento e, se anon entra por cofre da função, adicionar guarda `auth.uid() is null → CONVITE_INVALIDO` na função e re-testar).

In `rls_tests.sql` (usando o style/setup dos casos N-, P- existentes):
- N-11: usuário não-membro não lê convite da lista de outrem (0 linhas).
- N-12: dono lê convites da própria lista (>0).
- N-13: editor não insere convite para lista em que é só editor (exception esperada).
- N-14: editor não revoga (UPDATE `estado='revogado'` devolve 0 linhas afetadas via policy).

- [ ] **Step 4: Rodar testes localmente**

Run: `supabase db reset`, depois executar os scripts na ordem do CI (mesma chamada usada para `rls_tests.sql`/`excluir_conta_tests.sql` — ver `.github/workflows/ci.yml`).
Expected: todos os casos PASS.

- [ ] **Step 5: Docs donos + CI + commit**

- `docs/02-seguranca-rls.md` §5: tabela N-11…N-14 (descrição uma linha por caso).
- `.github/workflows/ci.yml`: incluir o novo script no job de DB.
- Commit:

```bash
git add supabase/migrations/0007_convites.sql supabase/tests/ docs/02-seguranca-rls.md .github/workflows/ci.yml
git commit -m "F7-T01: migration 0007 (convites + RLS + aceitar_convite + publication) (RF-13)"
```

- [ ] **Step 6: Marcar F7-T01 em `docs/14-tarefas.md`** (`- [x]` + nota do que foi feito) e atualizar tabela de progresso. Commit junto com o acima ou em seguida, no estilo dos commits anteriores.

---

### Task 2: `ConvitesRepository` + `PapelRepository` + papel no bootstrap (F7-T02)

**Files:**
- Create: `lib/features/convites/domain/papel.dart` — `enum Papel { dono, editor, leitor; String get valor; static Papel fromValor(String v); }` (espelha CHECK do 0001).
- Create: `lib/features/convites/domain/convite.dart` — `class Convide { id, listaId, token, papelOferecido, estado, expiraEm }` e `class MembroLista { userId; papel }`.
- Create: `lib/features/convites/data/convites_repository.dart` — item abaixo.
- Create: `lib/features/convites/data/papel_repository.dart` — item abaixo.
- Create: `lib/features/convites/providers/papel_providers.dart` — `papelRepositoryProvider`, `papelNaListaProvider = Provider.family<Papel?, String>` (lê o mapa carregado; null = desconhecido => tratar como leitor na UI até carregar).
- Modify: `lib/features/sync/data/supabase_boostrap.dart` — `sincronizarTudo()` chama `papelRepository.carregar(userId)` antes do download das tabelas; `_limparCache()` chama `papelRepository.limpar()`.
- Test: `test/features/convites/convites_repoository_test.dart`, `test/features/convites/papel_repository_test.dart`.

**Interfaces (produces):**
- `class ErroConvite implements Exception { final String code; final String message; }`
- `class ConvitesRepository { ConvitesRepository(this._client); final SupabaseClient _client; }` com métodos:
  - `Future<Convite> criarLink({required String listaId, required Papel papel})` → INSERT em `convites` (`tipo: 'link'`, `papel_oferecido`) e retorna `Convite.fromMap`.
  - `Future<void> revogar(String conviteId)` → UPDATE `estado='revogado'`.
  - `Future<List<Convite>> pendentesDaLista(String listaId)` → SELECT donos.
  - `Future<List<MembroLista>> membrosDaLista(String listaId)` → SELECT `lista_membros` ordenado dono→editor→leitor.
  - `Future<void> mudarPapel({required String listaId, required String userId, required Papel papel})` → UPDATE de `lista_membros` (dono; RLS garante).
  - `Future<void> removerMembro({required String listaId, required String userIdd})` → DELETE `lista_membros` (dono; teste SQL de 0002 cobre).
  - `Future<void> sairDaLista(String listaId)` → DELETE da própria linha (usuário atual).
  - `Future<String> aceitar(String token)` → `client.rpc('aceitar_convite', params: {'p_token': token})`; sucesso = lista_id. Captura: mensagem da exception PostgrestException contendo `CONVITE_...` → `ErroConvite(code, mensagemAplicavel)`; falhas `SocketException/ClientException/Timeout` → `ErroConvite('sem_conexao', AppStrings.iaSemConexao)`.
  - `String linkConvite(String token)` → `'br.com.oliverlucas.listacompras://entrar?token=$token'`.
- `class PapelRepository { Future<void> carregar(String userId); Stream<Map<String,Papel>> watch(); Papel? papelDe(String listaId); void atualizar(String listaId, Papel p); void remover(String listaId); void limpar(); }` — estado interno `ValueNotifier<Map<String,Papel>>`; `carregar` faz `client.from('lista_membros').select('lista_id,papel').eq('user_id', userId)`.
- Bootstrap ganha parâmetro opcional `papelRepository` (nullable; null => pular carga) para os testes injetarem fake.

**Strings novas (Task 3 usa; criar já nesta task):** `conviteInvalido`, `conviteSemConexao`, `conviteInesperado`.

- [ ] **Step 1: Testes falhando** — mocks do `SupabaseClient` (stub `from().select()/insert()/update()/delete()` e `rpc()`; padrão dos fakes usados em `supabase_sync_remoto_test.dart`). Casos: `deve_aceitar_convite_quando_rpc_retorna_lista_id`, `deve_mapear_erro_quando_token_invalido`, `deve_mapear_erro_quando_sem_conexao`, `deve_gerar_link_com_host_entrar`, `deve_carregar_papeis_quando_bootstrap_carrega` (fake rest), `deve_limpar_papeis_quando_cache_limpo`.
- [ ] **Step 2: Run** `flutter test test/features/convites` → FAIL (arquivos ausentes).
- [ ] **Step 3: Implementar** conforme Interfaces.
- [ ] **Step 4: Run** testes → PASS; `dart format . && flutter analyze` limpos.
- [ ] **Step 5: Commit** `F7-T02: ConvitesRepository + PapelRepository + papel no bootstrap (RF-13)`.

---

### Task 3: UI A — sheet "Convidar", tela de membros, sair da lista (F7-T03)

**Files:**
- Create: `lib/features/convites/ui/sheet_convidar.dart` — dono escolhe papel (radio editor/leitor) → botão "Gerar link" → sucesso mostra campo com `linkConvite(token)` + botões "Copiar link" (Clipboard + SnackBar `linkCopiado`) e "Compartilhar" (`share_plus` → `Share.share(link)`).
- Create: `lib/features/convites/ui/tela_membros_screen.dart` — FutureProvider.family por listaId via `membrosDaLista`; ListTile por membro com chip do papel; próprio usuário ("Você") destacado; dono tem: PopupMenuTrocar papel para editor↔leitor + "Remover" (diálogo confirmatório destrutivo — padrão das confirmações da tela da lista); botãoAppBar "Sair da lista" (não-dono) com diálogo → `repo.sairDaLista` → `context.go('/listas')`.
- Modify: `lib/core/l10n/app_strings.dart` — strings: convidar, convidarPapelEditor, convidarPapelLeitor, gerarLink, copiarLink, compartilhar, linkCopiado, membros, voce (róbulo "Você"), mudarPapel, removerMembro, removerMembroMensagem, sairDaLista, sairListaTitulo/sairListaMensagem, e as mensagens de erro de convite (Task 2).
- Modify: `pubspec.yaml` — `share_plus` (versão compatível com Flutter 3.44 pinned no CI).
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` — menu ⋮ ganha: "Membros" (dono e membros veem) e "Convidar" (só dono) abrindo os novos componentes; papel vem de `papelNaListaProvider`.
- Test: `test/features/convites/sheet_convidar_test.dart`, `test/features/convites/tela_membros_screen_test.dart`.

**Interfaces:**
- Consumes: `ConvitesRepository`, `PapelRepository`, `papelNaListaProvider` (Task 2); `appDatabaseProvider`/`authRepositoryProvider` (existentes) para userId atual.
- Produces: `Future<void> abrirSheetConvidar(BuildContext, WidgetRef, String listaId)` exibida para dono.
- Acesso de e-mail do usuário: **não** existe (RLS não expõe auth.users de terceiros). Membros exibem papel + "Você"; nomes ficam para F5+"realtime profile" futura (nota no 08 §8 — abrir doc na execução).

- [ ] **Step 1: Widget tests falhando** (`deve_gerar_link_quando_escolhe_papel_e_confirma`, `deve_mostrar_erro_quando_criar_link_falha` (ErroConvite), `deve_listar_membros_com_papeis`, `deve_remover_membro_apos_confirmacao`, `deve_sair_da_lista_quando_seleciona_e_confirma`, `deve_ocultar_acoes_dono_quando_nao_e_dono`).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implementar** (pattern dos dialogs/sheets existentes; `Navigator.pop` antes das ações; snackbar de sucesso).
- [ ] **Step 4: Run** → PASS; format + analyze.
- [ ] **Step 5: Commit** `F7-T03: UI convidar por link e membros (RF-13)`.

---

### Task 4: UI B — banner "Você é leitor" + bloqueio de escritas (F7-T04)

**Files:**
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` — watch `papelNaListaProvider(listaId)`:
  - papel `leitor` (ou null/desconhecido): esconde `_CampoAdicionar` e botão IA, mostra banner fixo (Container surfaceVariant com `AppStrings.somenteLeitura` + dica), `_LinhaItem` sem checkbox/sem swipe (Dismissible não instanciado), sem alça de drag; menu ⋮ reduzido (só "Sair da lista" — detalhado na Task 3).
  - papel `editor`: sem itens de dono no menu (excluir lista, convidar/membros-de-dono); desmarcar/limpar/renomear permitidos? — **conforme 08 §1**: renomear lista: editor ✔; excluir lista: ✘ → item "Excluir lista" só para dono.
- Modify: `lib/core/l10n/app_strings.dart` — `somenteLeitura`, `somenteLeituraDica`.
- Test: `test/features/listas/tela_lista_screen_test.dart` — novos casos com `papelRepository`/provider override (`papelNaListaProvider(listaId) → leitor|editor|dono`): `deve_mostrar_banner_quando_leitor`, `deve_bloquear_escritas_quando_leitor`, `deve_esconder_itens_dono_quando_editor`, `deve_manter_tudo_quando_dono`.

**Interfaces:**
- Consumes: `papelNaListaProvider` (Task 2).
- Produces: nenhuma assinatura nova; apenas comportamento na tela.

- [ ] Steps 1–5 (testes → fail → implement → pass → format/analyze/commit): `F7-T04: banner leitor e bloqueio de escritas por papel (RF-13)`.

---

### Task 5: Rota `/entrar` + deep link scheme + "Entrar com código" + retomada pós-login (F7-T05)

**Files:**
- Modify: `lib/router.dart`:
  - Tratar `/entrar` como pública no `redirect` (não mandar para `/login` quando não autenticado: a própria tela decide);
  - `/login` e `/registro` recebem `?next=` e após autenticação vo para `next` (guard já faz refreshListenable; ajustar o push pós-success usando `queryParameters['next']`);
- Create: `lib/features/convites/ui/entrar_screen.dart` — lê `token` de `state.uri.queryParameters`; três estados:
  - sem sessão: card "Você foi convidado para uma lista" + botões Entrar/Registrar → `/login?next=<url-encoded /entrar?token=...>`;
  - com sessão: chama `repo.aceitar(token)`; loading → sucesso `context.go('/listas/<listaId>')`; erro → mensagem de `ErroConvite` + "Tentar novamente".
  - já membro: RPC é idempotente e retorna lista_id — mesmo caminho de sucesso.
- Modify: `android/app/src/main/AndroidManifest.xml` — novo intent-filter:
```xml
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="br.com.oliverlucas.listacompras"
          android:host="entrar"/>
</intent-filter>
```
- Modify: `lib/features/listas/ui/minhas_listas_screen.dart` — AppBar: ícone `person_add` "Entrar com código": diálogo com TextField (cola token cru) → `repo.aceitar` → navegar (sucesso) ou SnackBar de ErroConvite.
- Test: `test/features/convites/entrar_screen_test.dart` (overrider de repo fake): `deve_aceitar_e_navegar_quando_token_valido_e_autenticado`, `deve_mostrar_convite_invalido_quando_erro`, `deve_mostrar_contexto_convidado_quando_sem_sessao`, `deve_aceitar_quando_volta_do_login_pelo_next`, `deve_entrar_com_codigo_quando_colado`.

**Interfaces:**
- Consumes: `ConvitesRepository.aceitar`/`ErroConvite`/`linkConvite` (Task 2), auth (existente), go_router.
- Produces: `next` pattern em auth screens (consumível por outros fluxos).

- [ ] Steps 1–5: como nas anteriores. Commit: `F7-T05: rota entrar com deep link e código (RF-13)`.

---

### Task 6: Realtime de `lista_membros` — papel ao vivo, entrada e perda de acesso < 5s (F7-T06)

**Files:**
- Modify: `lib/features/sync/data/supabase_bootstrap.dart` — em `_assinarRealtime`, o callback atual já recebe eventos de todas as tabelas do canal; hoje filtra registro vazio e aplica via `aplicarRemoto`. Estender:
  - extrair handler por tabela: `listas`/`itens_lista` → lógica atual (LWW); `lista_membros` → delega a `_aoMembro(usuarioAtual, payload, papelRepository, onPerdaAcesso)` (função pura testável):
    - `DELETE` com `oldRecord.user_id == usuarioAtual` → executar `onPerdaAcesso()`: limpar cache (reusar `_limparCache`) + re-sync (a lista some do download);
    - `UPDATE` de linha própria → `papelRepository.atualizar(listaId, papel)`; ou `Papel from old/new`;
    - `INSERT/DELETE/UPDATE` de outro usuário → nada no papel (a UI de membros refetch ao abrir).
  - Bootstrap ganha injeção opcional de `PapelRepository` e `void Function()? onPerdaAcesso` (default: recarrega estado interno da própria instância).
- Modify: `lib/features/convites/providers/` — `papelNaListaProvider` passa a `watch()` do repositorio (Stream via ValueNotifier) ⇒ re-render automático ao mudar papel.
- Test: `test/features/sync/supabase_bootstrap_test.dart` + `test/features/convites/papel_repository_test.dart` — casos fake-canal (padrão existente): `deve_limpar_cache_quando_membro_removido_sou_eu`, `deve_atualizar_papel_quando_update_meu_membro`, `deve_ignorar_membros_de_outros_quando_atualizacao`, `deve_refletir_papel_na_ui_quando_realtime_muda`.

**Interfaces:**
- Consumes: `PapelRepository` (Task 2), bootstrap atual (canal em `_assinarRealtime` ~linha 149).
- Produces: garantia do checklist 08 §9 (remoção < 5s) — sem mudança de motor de sync (LWW da Tasks 05 etc. intocado).

- [ ] Steps 1–5 idem. Commit: `F7-T06: realtime de lista_membros (papel ao vivo, perda de acesso) (RF-13)`.

---

### Task 7: Validação da fase + distribuição (F7-T07)

**Files:**
- Modify: `docs/14-tarefas.md` — F7-T01…T06 marcadas; tabela de progresso.
- Modify: `docs/09-runbook-operacoes.md` §2.5 — histórico de rollout v1.1.1+4.
- Modify: `pubspec.yaml` — version: 1.1.1+4.

**Interfaces:**
- Consumes: tudo das Tasks 1–6; `dart_defines_prod.json` local (gitignored) para build de produção.

- [ ] **Step 1:** rodar suite completa local: `supabase db reset` + scripts SQL de teste; `flutter test`; `dart format . && flutter analyze`. Corrigir regressões antes de continuar.
- [ ] **Step 2:** checklist recorte link-only do 08 §9 manualmente com 2 contas locais (dono cria convite → convidado aceita pelo deeplink no emulador; removido perde acesso < 5s; idempotência; leitor bloqueado).
- [ ] **Step 3:** CI verde no push (branch protection). Corrigir falhas, se houver.
- [ ] **Step 4:** apk release + Firebase App Distribution (grupo `testadores`) — version bump `1.1.1+4`; doc 09 §2.5 + commit `F7-T07: validação checklist 08 §9 e distribuição 1.1.1+4 aos testadores (RF-13)`.
- [ ] **Step 5:** atualizar `14-tarefas.md` (todas as F7 marcadas; progresso) — commit do doc em separadinho se necessário.

---

## Self-review (feito ao escrever)

1. **Cobertura da spec:** §3 banco → Task 1; §4.1 dado/repos → Task 2; §4.2 UI (todos os componentes da tabela) → Tasks 3–5 (painel "Convites pendentes" fica fora — link-only, sem entradas, conforme §2 da spec); §4.3 sync → Task 6 (motor intocado); §5 testes → dentro de cada task; §6 CP → Task 7.
2. **Sem placeholders:** cada Step tem regra concreta; TODOS SQL normativos vêm verbatim do doc 08 (também é bug-block: ninguém reescreve o SQL a mão na execução, copia do doc).
3. **Consistência de tipos:** `Papel` enum e `ErroConvite` definidos na Task 2 e consumidos nas Tasks 3–6 com o mesmo nome; `linkConvite` um único place (Task 2) usado em 3 e 5; `papelNaListaProvider` definido na Task 2, consumido em 3/4/6.
