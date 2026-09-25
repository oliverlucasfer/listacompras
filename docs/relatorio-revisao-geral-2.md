# Relatório — Revisão geral da aplicação 2 (2026-09-25)

> Navegação: [14 Tarefas](14-tarefas.md) · Fonte dos achados da **Fase 43 — Correções da revisão geral 2**.

Revisão de leitura do código no commit `f3bf54a` (branch `main`, pós-F42), em 5 frentes independentes (sync, banco/RLS, UI/design system, repositórios/domínio/Lite, testes/CI/docs), com **verificação manual** dos achados Críticos/Importantes no código antes de entrarem aqui. Cada achado tem ID (`G-xx`), evidência `arquivo:linha`, **doc dono** e o veredito.

**Verificação objetiva no HEAD:** `flutter analyze` → *No issues found!*; `flutter test` → **695 testes, todos verdes**; `dart format --set-exit-if-changed .` → 242 arquivos, 0 alterados.

**Legenda de status:** `confirmado` (código/doc relido) · `suspeita` (leitura, exige teste em runtime) · `latente` (não afeta o app hoje).

---

## 1. Crítico

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **G-01** | **Backup exporta itens de listas soft-deletadas e a restauração falha.** `excluirLista` marca só o tombstone da lista; `exportarJson` filtra listas e itens de forma independente, então o `.json` sai com `listas: []` + itens órfãos. Restaurar em banco limpo viola a FK `item_local.lista_id → lista_local` e **derruba a importação inteira** (`FOREIGN KEY constraint failed`). | `lib/features/backup/data/backup_repository.dart:43-48`; `lib/features/listas/data/listas_repository.dart:207-220`; `lib/drift/tables/item_local.dart:12-13` | [05](05-app-flutter.md) §6.10 · [03](03-sincronizacao-offline.md) §3 (RF-31) | confirmado |

## 2. Importantes

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **G-02** | **Dedup cross-device burlada pelo coalescing.** Item criado **e editado** offline coalesce para `operacao='UPDATE'`; sem linha remota, o envio cai em `insert` → viola `uq_item_ativo` (23505) e queima tentativas até `ErroSync`. O dedup só roda com `operacao=='INSERT'`. | `lib/features/sync/data/supabase_sync_remoto.dart:77-98` × `sync_engine.dart:253` | [03](03-sincronizacao-offline.md) §5 (RF-10) | confirmado |
| **G-03** | **Editor soft-deleta/ressuscita a lista inteira.** A policy de UPDATE de `listas` não restringe colunas, então `deletado_em` é gravável por qualquer editor — apesar de o DELETE ser dono-only. | `supabase/migrations/0002_rls_policies.sql:75-85`; `0012:13-23`; `0018:11-26` | [02](02-seguranca-rls.md) §3/§4.1 | confirmado |
| **G-04** | **PII sobrevive ao `excluir_conta`.** `convites.email` não tem FK para o destinatário; o e-mail do titular excluído permanece (até 7 dias) e pode ser herdado por quem re-registrar o mesmo endereço. | `0013_remover_ia_rate_limit.sql:10-27`; `0007_convites.sql:16` | [06](06-mvp-entregas.md) §3.3.1 (LGPD) | confirmado |
| **G-05** | **Sem localização pt-BR do Material.** `MaterialApp.router` sem `localizationsDelegates`/`supportedLocales`/`locale` → tooltips nativos (ex.: "Back") em inglês. | `lib/app.dart:28-36` | [05](05-app-flutter.md) §7 · [15](15-design-system.md) §4 | confirmado |
| **G-06** | **Exclusão de conta trava no erro de rede.** O catch cobre só `AuthException`; erro de rede em `entrar()` deixa `_verificando` preso e o diálogo no spinner sem mensagem. | `lib/features/configuracoes/ui/configuracoes_screen.dart:200-219` | [05](05-app-flutter.md) §6 · [15](15-design-system.md) §3 | confirmado |
| **G-07** | **Carregando da Tela da Lista usa spinner cru** em vez de `AppEsqueleto` (painel/membros/mercado já usam). | `lib/features/listas/ui/tela_lista_screen.dart:305` | [10](10-wireframes-telas.md) §6 · [15](15-design-system.md) §3 | confirmado |
| **G-08** | **Alça de "Ordenar categorias" com 24dp** sem padding (wireframe exige ≥48dp; na tela da lista a alça tem `AppSpacing.md`). | `lib/features/listas/ui/tela_ordenar_categorias.dart:53-56` | [10](10-wireframes-telas.md) · [15](15-design-system.md) §4 | confirmado |
| **G-09** | **Campo do link de convite sem nome acessível** (`readOnly` sem `label`/`hint`). | `lib/features/convites/ui/sheet_convidar.dart:315` | [15](15-design-system.md) §4 | confirmado |
| **G-10** | **Erro de restauração vira "erro ao ler".** Falha de FK/CHECK (`SqliteException`) é mapeada para `leituraErro`, sugerindo arquivo ilegível quando o arquivo é válido porém irrestaurável. | `lib/features/backup/ui/secao_backup.dart:124-138`; `backup_repository.dart:218-226` | [05](05-app-flutter.md) §6.10 | confirmado |
| **G-11** | **Doc dono do CI defasado.** `07 §3` manda `flutter build apk --debug --flavor lite` **sem `-t lib/main_lite.dart`** (reproduz o APK errado) e lista 8 scripts `psql` contra 10 no `ci.yml` (faltam orçamento e push tokens). | `docs/07-qualidade-ci.md:64,99,125-132` × `.github/workflows/ci.yml:44,67-74` | [07](07-qualidade-ci.md) | confirmado |

## 3. Menores e dívidas

### 3.1 Sync e offline

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **G-12** | `_registrarFalha` incrementa tentativas de **todo** o registro, inclusive mutação enfileirada durante o `await` e nunca tentada; sem filtro `id <= ateId` nem `tentativas < max`. | `sync_engine.dart:351-355` | confirmado |
| **G-13** | Coalescing elege "última" por maior `id`, não por maior `ts_local` como manda o doc. | `sync_engine.dart:253,314-322` | suspeita |
| **G-14** | Off-by-one: `_reportarFalha` usa `tentativas` pré-incremento → evento ">5" dispara na 7ª falha. | `sync_engine.dart:299-308` | confirmado |
| **G-15** | `ts_local` é coluna morta; comentário ("vira updated_at no flush") e docstring divergem do uso real (`payload['updated_at']`). | `lib/drift/tables/mutacao_pendente.dart:11`; `lib/features/sync/data/sync_remoto.dart:38-39` × `sync_engine.dart:283-284` | confirmado |
| **G-16** | `historico_preco_local` não é limpo no logout/troca de usuário (chaveado só por nome) → preços do usuário anterior vazam para a conta seguinte. | `lib/features/sync/data/supabase_bootstrap.dart:192-197`; `lib/features/listas/data/historico_precos_repository.dart:22` | suspeita |
| **G-17** | Escrita local + `enfileirar` não são atômicas nos repositórios (o import de backup já é). Crash entre os dois deixa o registro sem mutação. | `lib/features/listas/data/listas_repository.dart:161-179` | latente |
| **G-18** | `sincronizarTudo`/`_baixarDoSupabase` só faz upsert, sem reconciliar remoções e sem paginação (limite 1000). | `supabase_bootstrap.dart:111-117,267-273` | latente |
| **G-19** | Ordem de aplicação no Realtime pode violar FK (item remoto antes da lista) e abortar o restante da cadeia. | `lib/features/sync/data/aplicador_remoto.dart:14`; `lib/drift/database.dart:135` | latente |
| **G-20** | Callback de status do canal ignora `error` e só re-sincroniza em `SUBSCRIBED`; `CHANNEL_ERROR` terminal mantém cache defasado até o próximo bootstrap. | `supabase_bootstrap.dart:237-242` | suspeita |
| **G-21** | R-11 (kick <5s) segue como limite de plataforma documentado (`_realtime.tenants.private_only`, sem opção no CLI). | `docs/08-compartilhamento-colaborativo.md` §9 | latente (sem ação) |

### 3.2 Banco e RLS

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **G-22** | `aceitar_convite` (`security definer`) sem `revoke` de PUBLIC/anon — único RPC sensível sem revogação explícita. | `0007_convites.sql:122-157` | confirmado |
| **G-23** | `search_path = public` nos definers (o guia Supabase recomenda `''`); sem exploração atual (referências qualificadas). | `0002:8-51`, `0007`, `0010`, `0016`, `0018`, `0019`, `0021`, `0022` | latente |
| **G-24** | `convites` sem CHECK `tipo`↔`email`: `tipo='email'` com `email NULL` é aceito (comparação NULL não bloqueia). | `0007_convites.sql:14-23,138-145` | confirmado |
| **G-25** | `updated_at` sem teto: cliente pode carimbar data futura e vencer sempre no LWW. | `0001_init.sql:72-82`; `0012:13-23` | suspeita |
| **G-26** | `membros_update_papel_dono` permite trocar `user_id`/`lista_id` da linha, não só `papel`. | `0009_rls_membros_papeis.sql:13-23` | confirmado |
| **G-27** | `convites_insert_dono` não restringe `estado`/`expira_em` (dá para criar convite já aceito ou sem expiração). | `0007_convites.sql:66-76` | confirmado |
| **G-28** | Push sem rate-limit: todo INSERT de convite-email/membro dispara `net.http_post` externo. | `0022_notificar_push.sql:59-81` | confirmado |
| **G-29** | Sem limite de tamanho em `push_tokens.token` e `itens_lista.quantidade`. | `0021_push_tokens.sql:9`; `0001_init.sql:49` | confirmado |
| **G-30** | Cobertura de testes incompleta: falta negação de soft-delete por editor, anon em `lista_membros`/`convites`/`push_tokens`, grants de `agora_servidor` e enums inválidos. | `supabase/tests/rls_tests.sql`; `docs/01` §8 | confirmado |

### 3.3 UI, design system e a11y

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **G-31** | SnackBar cru (fora do `mostrarSnackBar`) na falha de exclusão de conta. | `configuracoes_screen.dart:79-83` | confirmado |
| **G-32** | Notificação em primeiro plano usa `SnackBar` cru no `app.dart`. | `lib/app.dart:25` | confirmado |
| **G-33** | R-14 parcial: `/login-callback` com `FilledButton` cru e progresso sem rótulo semântico. | `lib/router.dart:200,214-217` | confirmado |
| **G-34** | Strings órfãs em `AppStrings` (`offline`, `importLocalTextoLongo`, `mudarPapel`, `tituloLista`). | `lib/core/l10n/app_strings.dart:352,234,317,64` | confirmado |
| **G-35** | Strings duplicadas (`sairDaLista`/`sairListaTitulo`, `removerItem`/`removerMembro`). | `lib/core/l10n/app_strings.dart:318-321,136,318` | confirmado |
| **G-36** | Modo leitor sem a dica prevista ao tocar (item com `onTap: null`). | `tela_lista_screen.dart:927` × `docs/10:286-287` | confirmado |
| **G-37** | Faixa "Marcados"/rodapé do modo mercado sem `SafeArea` inferior. | `lib/features/listas/ui/mercado_screen.dart:132-155,241-248` | suspeita |
| **G-38** | `AlertDialog` de importação não rolável com conteúdo alto/teclado. | `lib/features/importacao/ui/modal_importar.dart:105-154` | suspeita |
| **G-39** | Sufixo do campo "Adicionar item" acumula unidade + microfone + adicionar; em 2x pode faltar largura. | `tela_lista_screen.dart:704-744` | suspeita |
| **G-40** | Números mágicos em componentes (`SizedBox 12/8` no `AppBotao`; ícone 20 no `AppBanner`). | `lib/core/widgets/app_botao.dart:77,85`; `app_banner.dart:73` | confirmado |
| **G-41** | `SeletorTema` usa `DropdownButtonFormField` cru no ramo responsivo. | `lib/core/theme/seletor_tema.dart:67-87` | confirmado |
| **G-42** | E-mail da Conta sem fallback (`Text(email ?? '')`). | `configuracoes_screen.dart:123` | confirmado |

### 3.4 Repositórios, domínio e Lite

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **G-43** | `ListaComContagem` sempre sem orçamento (query não seleciona `orcamento_centavos`). | `listas_repository.dart:116-151` | confirmado |
| **G-44** | Opt-out de notificação pode ser revertido: `definirAtivas` não marca `_chavePedido`; `talvezPedirPermissao` religa. | `lib/features/notificacoes/data/notificacoes_service.dart:26-59` | suspeita |
| **G-45** | Providers tocam `Supabase.instance.client` no construtor; quebram no Lite se consumidos. | `notificacoes_providers.dart:22-24`; `convites_providers.dart:12-14`; `papel_providers.dart:11-13` | latente |
| **G-46** | Memória de categoria varre itens de listas soft-deletadas (os frequentes excluem). | `lib/core/categorias/sugestao_categorias.dart:23-28` × `listas_repository.dart:76-80` | confirmado |
| **G-47** | Escritas sem `await`/`catch` na UI (`_reordenarGrupo`, `_marcar`/`_desmarcar`). | `tela_lista_screen.dart:778-780`; `mercado_screen.dart:41-53` | suspeita |
| **G-48** | Parser não lê quantidade+unidade separadas no fim (`"leite 2 kg"`), só colado. | `lib/core/importacao/parser_lista_local.dart:197-229` | suspeita |
| **G-49** | `definirOrcamento` sem validação de faixa/negativo (depende da UI). | `listas_repository.dart:244-260` × `preco.dart:44-48` | latente |
| **G-50** | Título de lista sem limite de 120 na UI → estoura o CHECK e cai em erro genérico. | `lib/features/listas/ui/sheet_titulo_lista.dart:44-55`; `lista_local.dart:9` | confirmado |
| **G-51** | Token de push removido só no logout manual; expiração/revogação deixa o token no servidor. | `configuracoes_screen.dart:34`; `notificacoes_service.dart:79-83` | suspeita |
| **G-52** | Importação engole falha de categoria (só captura `ErroImportacao`); erro de Drift deixa `_carregando=true`. | `lib/features/importacao/ui/modal_importar.dart:62-77` | latente |
| **G-53** | `sqlite3` sem uso em `lib/` (R-16 persiste); verificar uso em teste antes de remover. | `pubspec.yaml:47` | confirmado |

### 3.5 Docs e CI

| ID | Achado | Evidência | Status |
| :--- | :--- | :--- | :--- |
| **G-54** | Tabela de progresso do 14 incoerente: F5 `7|5` com 2 tarefas abertas, mas total `224|224`. | `docs/14-tarefas.md:913,950` | confirmado |
| **G-55** | README desatualizado: cita `N-01…N-10`/`P-01…P-05` (hoje `N-22`/`P-12`) e ignora flavors/push. | `README.md:28` × `docs/02` §5 | confirmado |
| **G-56** | `ci.yml` com andaime legado da Fase 1 (step condicional `check`/`if` e comentário de fase). | `.github/workflows/ci.yml:16-22,103` | confirmado |
| **G-57** | CP da F42-T02 cita "suíte verde (693)"; a contagem no HEAD é 695. | `docs/14-tarefas.md:904` | suspeita |
| **G-58** | `google-services.json` rastreado com API key real — decisão documentada; a restrição no console não é verificável no repositório. | `android/app/google-services.json` × `docs/09` §2 | confirmado |

## 4. Pontos fortes confirmados

- **Correções da Fase 20 mantidas:** R-01/R-02 (parser), R-03 (mutação durante o flush), R-04 (sem reentrância), R-06 (relógio do servidor via RPC `agora_servidor`), R-09/R-10/R-12/R-13/R-17/R-18/R-19/R-22 resolvidos.
- **RLS `enable`+`force`** nas 5 tabelas; toda função `SECURITY DEFINER` fixa `search_path`; RPCs sensíveis com `revoke` + grant a `authenticated` e validação de `auth.uid()`; segredo do `pg_net` no Vault; nenhum segredo real versionado.
- **Offline-first íntegro:** escrita sempre no Drift + fila, UUID v4 no cliente, LWW com empate para o servidor, tombstones, migração Drift v7→v8 testada.
- **Enums fechados** idênticos em Postgres/Dart/parser (9 unidades, 11 categorias); dinheiro em centavos `int`.
- **Lite bem isolado** (`AppCapacidades` + override do container + outbox desligada); **Sentry sem conteúdo de listas**.
- **CI completo** (format/analyze/test, web, 2 flavors, desktop, `db reset`, 10 suítes SQL/RLS + realtime, Deno) e backup mensal cifrado; cobertura F22–F42 sem lacunas relevantes.

## 5. Documentos relacionados

- [Spec da Fase 43](superpowers/specs/2026-09-25-correcoes-revisao-geral-2-design.md)
- [14 Tarefas](14-tarefas.md) — Fase 43
- [relatório da revisão geral 1](relatorio-revisao-geral.md) (Fase 20)
