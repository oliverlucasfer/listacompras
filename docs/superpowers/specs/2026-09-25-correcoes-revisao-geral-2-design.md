# Fase 43 — Correções da revisão geral 2 (design)

> **Status:** aprovado em 25/09/2026 (decisões na Seção 10)
> **Fase:** 43 · **Requisito:** RNF-08 (qualidade) · **Doc dono:** [01](../01-banco-de-dados.md), [02](../02-seguranca-rls.md), [03](../03-sincronizacao-offline.md), [04](../04-importacao-lista.md), [05](../05-app-flutter.md), [06](../06-mvp-entregas.md), [07](../07-qualidade-ci.md), [10](../10-wireframes-telas.md), [15](../15-design-system.md)
> **Origem:** [relatório da revisão geral 2](../../relatorio-revisao-geral-2.md) — achados `G-01…G-58` com evidência `arquivo:linha`.

---

## 1. Motivação

A revisão de 25/09/2026 (HEAD `f3bf54a`, pós-F42) confirmou que as camadas não negociáveis seguem
sólidas (RLS `enable`+`force` nas 5 tabelas, definers com `search_path`, offline-first, enums
fechados, nenhum segredo versionado, CI verde). Restaram **58 achados**: 1 Crítico, 10 Importantes e
47 menores/dívidas. Esta fase fecha todos, do backup ao CI, sem mudança de arquitetura.

## 2. Escopo

**Dentro:**
- Backup: exportar o banco inteiro (G-01) e distinguir erro de leitura × restauração (G-10).
- Sync: dedup com coalescing (G-02); robustez do flush, coalescing por `ts_local`, relatórios e
  canal (G-12…G-15, G-19, G-20); histórico de preços no logout (G-16); atomicidade (G-17);
  paginação (G-18).
- Banco/RLS: `deletado_em` protegido (G-03); PII no `excluir_conta` (G-04); `revoke` e CHECKs de
  `convites` (G-22, G-24); higiene de policies e limites (G-26, G-27, G-29); `search_path=''`
  (G-23); testes de negação (G-30). `updated_at` sem teto e rate-limit do push são **documentados**
  (G-25, G-28).
- App: i18n Material (G-05); erros de exclusão/carregamento/importação (G-06, G-52); estados e a11y
  (G-07…G-09, G-31…G-42); validações (G-49, G-50); domínio (G-43…G-48, G-51, G-53).
- Docs/CI: doc 07 e 14, README, `ci.yml`, contagem de testes, nota do `google-services.json`
  (G-11, G-54…G-58).

**Fora (explícito):**
- **Sem mudança de contrato** de sync/RLS/schema além do estritamente listado; nenhuma tabela nova.
- **Sem** migration para inteiro de milésimos; `quantidade` continua `real` no Drift.
- **G-21** (kick <5s) permanece limite de plataforma documentado — **sem código**.
- **G-25** (`updated_at` sem teto) e **G-28** (rate-limit do push) viram **risco aceito documentado**
  no doc dono, não código (mitigar quebraria o LWW / adicionaria estado novo).
- **G-53:** `sqlite3` **não é removido** se for usado por testes; a tarefa confirma o uso e
  documenta a dependência direta (era o desfecho do R-16 na F20).
- Sem refatoração ampla de repositórios além da transação da G-17; sem novas dependências de
  runtime (só `flutter_localizations`).

## 3. Arquitetura da mudança

Nenhum módulo novo. As mudanças se concentram em:

```
lib/features/backup/          exportação sem filtro + exceção de restauração
lib/features/sync/            dedup, flush, coalescing, histórico, paginação
lib/features/listas/data/     transações + validações + query com orçamento
lib/features/*/ui/            a11y, estados, erros
lib/app.dart, router.dart     l10n Material e resíduos
supabase/migrations/0023+     policies/triggers/CHECKs/RPCs (só migrations novas)
.github/workflows/ci.yml, docs/  CI e docs donos
```

**Regra transversal:** correção de banco nunca edita migration já aplicada em produção — sempre
`0023+` (o histórico aplicado está em [09 §2.6](../09-runbook-operacoes.md)).

## 4. Backup (G-01, G-10)

- **G-01:** `BackupRepository.exportarJson` **remove os filtros** de `listas.deletado_em is null` e
  `item_local.deletado_em is null`; exporta o banco inteiro, com `deletado_em` preservado. Assim a
  FK `item_local.lista_id → lista_local` é sempre satisfeita no restore e o arquivo é fiel ao banco
  (a UI continua ocultando as excluídas). `historicoPrecos` já era integral.
- **G-10:** novo `BackupRestauracaoException` (falha de FK/CHECK durante a transação). Em
  `secao_backup.dart`, `BackupInvalidoException` → `backupInvalido` (arquivo) e
  `BackupRestauracaoException`/erro genérico → `backupRestauracaoErro` (mensagem nova em
  `AppStrings`). A transação continua revertendo tudo.
- **Testes:** round-trip exportar→importar com lista soft-deletada e itens (não deve lançar FK);
  importar backup cujo item aponta para lista inexistente → `BackupRestauracaoException`; mensagem
  correta na UI.

## 5. Sincronização (G-02, G-12…G-20)

- **G-02 (dedup):** em `SupabaseSyncRemoto.enviar`, quando **não há linha remota** e a mutação é de
  `itens_lista` com `payload['deletado_em'] == null`, roda `_buscarDuplicado` **independente de a
  operação ser INSERT ou UPDATE coalescido**. Defesa em profundidade: capturar `PostgrestException`
  com `code == '23505'` no `insert` e refazer o caminho de dedup uma vez.
- **G-12:** `_registrarFalha` incrementa apenas as linhas do lote (`tabela`+`registro_id` com
  `id <= ateId`), sem tocar mutação enfileirada durante o `await`.
- **G-13:** o vencedor do coalescing passa a ser a mutação de maior `ts_local` (desempate por
  maior `id`); a remoção continua apagando todas as linhas do grupo até o maior `id` do lote.
- **G-14:** `_reportarFalha` calcula `tentativas` já incrementadas (usa o lote reconsultado ou +1).
- **G-15:** comentário/docstring de `ts_local` alinhados ao uso real (`payload['updated_at']`).
- **G-16:** `_limparCache` do bootstrap também limpa `historico_preco_local`.
- **G-17:** as escritas dos repositórios (`ListasRepository`) que aplicam no Drift **e** chamam
  `_outbox.enfileirar` passam a rodar dentro de `_db.transaction(...)`, como o import de backup.
- **G-18:** `_baixarDoSupabase` pagina com `range` em laços até esgotar; **não** reconcilia remoções
  (a app só faz soft delete) — a decisão fica registrada no doc 03.
- **G-19:** ao aplicar um remoto cuja FK pai ainda não existe, o erro é ignorado (a cadeia não
  aborta) e o próximo bootstrap/re-sync reconcilia — documentado no doc 03 §4/§7.
- **G-20:** `_aoMudarStatusCanal` também re-sincroniza em `CHANNEL_ERROR`/`TIMED_OUT` (além de
  `SUBSCRIBED`), com a guarda de `_disposed`.
- **Testes:** `supabase_sync_remoto_enviar_test` (UPDATE coalescido com duplicado remoto → Duplicado;
  `23505` → dedup), `sync_engine_test` (falha não incrementa mutação fora do lote; coalescing por
  `ts_local`; relatório na 6ª falha), `supabase_bootstrap_test` (histórico limpo no logout; canal em
  `CHANNEL_ERROR` re-sincroniza; paginação).

## 6. Banco e RLS (G-03, G-04, G-22…G-30)

Migration **`0023_revisao_geral_2.sql`** (e, se preciso, `0024`), sempre aditiva:

1. **G-03 — `deletado_em` protegido (defesa em profundidade):**
   - Recriar `listas_update_editores` acrescentando ao `with check`: `papel_na_lista(id) = 'dono'`
     **ou** `deletado_em is not distinct from (select l.deletado_em from public.listas l where l.id = listas.id)`
     (mesmo padrão da imutabilidade de `dono_id`).
   - Trigger `protege_deletado_em` (BEFORE UPDATE) rejeitando mudança por não-dono, espelhando
     `protege_arquivo_dono` (incluindo o tratamento de `auth.uid()` nulo como allow).
   - Testes SQL: editor muda `deletado_em` → negado; dono exclui → permitido; editor renomeia →
     permitido.
2. **G-04 — PII no `excluir_conta`:** recriar a função (versão atual em `0013`) para, antes do
   `delete from auth.users`, apagar `public.convites` cujo `lower(email) = lower(<e-mail do uid>)`.
   Teste: convite por e-mail endereçado ao titular some após E-xx; convite de terceiro permanece.
3. **G-22:** `revoke execute on function public.aceitar_convite(...) from public, anon` (mantém
   grant a `authenticated`); teste de anon continua rejeitado por grant, não só por guarda.
4. **G-24:** CHECK `convites_tipo_email_check`: `(tipo = 'link' and email is null) or
   (tipo = 'email' and email is not null)`; ajustar `aceitar_convite` para comparar e-mail com
   `is not null` explícito (link segue valendo para qualquer autenticado).
5. **G-26:** recriar a policy de UPDATE de `lista_membros` exigindo `user_id`/`lista_id` iguais à
   snapshot antiga (só `papel` muda).
6. **G-27:** `convites_insert_dono` ganha `with check (estado = 'pendente' and expira_em > now())`.
7. **G-29:** `check (char_length(token) between 1 and 4096)` em `push_tokens`; teto superior de
   `quantidade` (ex.: `<= 1000000`) em `itens_lista` — com espelho no Drift (migração v8→v9).
8. **G-30:** novos casos SQL (soft-delete por editor, anon negado em `lista_membros`/`convites`/
   `push_tokens`, grants de `agora_servidor`, enums inválidos).
9. **G-23 — `search_path=''`:** recriar os definers com `set search_path = ''` e **qualificar
   todos** os identificadores internos (`public.`, `auth.`); coberto pelas suítes SQL existentes.
   Tarefa de maior risco — se a auditoria apontar referência não qualificável, fica isolada.
10. **G-25 / G-28:** documentar como risco aceito (03 §5 / 01 §7), sem código.

## 7. App, UI e domínio (G-05…G-09, G-31…G-53)

- **G-05:** `flutter_localizations` no `pubspec.yaml`; `app.dart` com `localizationsDelegates`
  (`GlobalMaterialLocalizations`/`Widgets`/`Cupertino`) e `supportedLocales: [Locale('pt','BR')]`.
- **G-06:** `configuracoes_screen.dart` — catch genérico na reautenticação, mensagem inline e
  `_verificando=false` garantido (novo teste com fake que lança erro de rede).
- **G-07/G-08/G-09:** `AppEsqueleto` no loading da lista; alça de 48dp; `label`/`hint` no campo do
  link (teste de semântica/tap target).
- **G-31/G-32:** snackbars crus → `mostrarSnackBar` (com `scaffoldMessengerKey` no primeiro plano).
- **G-33:** `/login-callback` com `AppBotao` e rótulo semântico de progresso.
- **G-34/G-35/G-42:** remover strings órfãs, unificar duplicadas, fallback `semValor` no e-mail.
- **G-36…G-41:** dica ao leitor; `SafeArea` no mercado; import rolável; sufixo do campo em 2x;
  tokens em `AppBotao`/`AppBanner`; `AppDropdown` no `SeletorTema`.
- **G-43:** `watchListasComContagem` inclui `orcamento_centavos`.
- **G-44:** `definirAtivas` marca `_chavePedido` para o opt-out não ser revertido.
- **G-45:** providers que dependem de `Supabase.instance` só resolvem quando há capacidade de rede
  (guarda no Lite).
- **G-46:** memória de categoria exclui itens de listas soft-deletadas.
- **G-47:** escritas da UI com `await` + feedback de erro.
- **G-48:** parser reconhece `"<nome> <qtd> <unidade>"` no fim (separado).
- **G-49/G-50:** validação de orçamento no repositório; `maxLength` de 120 no título com contador.
- **G-51:** remover token de push no fim de sessão (não só no logout manual).
- **G-52:** importação trata erro de categoria sem deixar `_carregando=true`.
- **G-53:** confirmar uso de `sqlite3` em teste; documentar a dependência direta (sem remover).

## 8. Docs e CI (G-11, G-54…G-58)

- **G-11:** `07 §3` com `-t lib/main_lite.dart` no build lite e os 2 scripts `psql` faltantes; nota
  "três scripts" → "dez scripts".
- **G-54:** corrigir a tabela do `14` (F5) para refletir as 2 tarefas abertas e o total real.
- **G-55:** README — inventário `N-22`/`P-12`, flavors (`-t lib/main_lite.dart`), push.
- **G-56:** remover o andaime legado do `ci.yml`.
- **G-57:** corrigir a contagem citada na F42-T02 (ou anotar a contagem atual).
- **G-58:** nota no README/09 sobre a restrição da API key Android no console Firebase.

## 9. Testes e CI

- Toda correção de comportamento entra com teste que **falha primeiro** (TDD), nome
  `deve_<resultado>_quando_<condição>`.
- Correções de banco entram em migration nova com casos SQL no `supabase/tests/` e step no
  `ci.yml`; o `db reset` + suítes SQL + `realtime_test.mjs` são executados no stack local.
- Fechamento: `dart format .`, `flutter analyze`, `flutter test`, `supabase db reset` e suítes
  SQL/Deno verdes; nenhum passo novo de CI além dos que as tarefas exigirem.
- Nenhum segredo novo; `google-services.json` permanece rastreado (decisão registrada).

## 10. Decisões registradas (25/09/2026)

1. **Escopo:** corrigir **tudo** (Críticos + Importantes + Menores), decisão do usuário.
2. **Processo:** convenção completa do projeto — relatório + spec + Fase 43 no `14` com tarefas/CP +
   docs donos no mesmo PR.
3. **G-01:** exportar o banco inteiro, **sem filtro** (backup fiel, com tombstones).
4. **G-02:** dedup **proativo** (sem linha remota) **e** catch de `23505`.
5. **G-03:** **policy + trigger** (defesa em profundidade).
6. **G-04:** **apagar** os convites endereçados ao e-mail do titular no `excluir_conta` (não
   anonimizar, que ampliaria o risco de link).
7. **G-25/G-28:** risco aceito documentado, sem código.
8. **Migrations:** sempre novas (`0023+`); `sqlite3` mantido se usado por testes.
9. Sem novo requisito: a fase é qualidade interna sob **RNF-08**.

## 11. Documentos relacionados

- [Relatório da revisão geral 2](../../relatorio-revisao-geral-2.md) — achados `G-xx`
- [14 Tarefas](../14-tarefas.md) — Fase 43 (breakdown e progresso)
- [01 Banco](../01-banco-de-dados.md) · [02 RLS](../02-seguranca-rls.md) · [03 Sync](../03-sincronizacao-offline.md) · [04 Importação](../04-importacao-lista.md) · [05 App](../05-app-flutter.md) · [06 Entregas](../06-mvp-entregas.md) · [07 CI](../07-qualidade-ci.md) · [10 Wireframes](../10-wireframes-telas.md) · [15 Design System](../15-design-system.md)
