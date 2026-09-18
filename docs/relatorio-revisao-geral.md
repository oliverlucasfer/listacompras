# Relatório — Revisão geral da aplicação (2026-09-18)

> Navegação: [14 Tarefas →](14-tarefas.md) · Fonte dos achados da **Fase 20 — Correções da revisão**.

Revisão de leitura do código no commit `368b23c` (branch `f19/publicacao-web` = `main` + F19-T00/T01), em 5 frentes independentes, com **verificação manual** de todo achado Crítico/Importante antes de entrar aqui. Cada achado tem ID (`R-xx`), evidência `arquivo:linha`, **doc dono** e o veredito de verificação.

**Legenda de status:** `confirmado` (relido pelo revisor no código/doc) · `suspeita` (leitura, exige teste em runtime) · `latente` (não afeta o app hoje).

---

## 1. Críticos

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **R-01** | Vírgula decimal corrompe a quantidade: `"1,5 kg de arroz"` vira `1` + `"5 kg de arroz"` (grava 5 kg). O parser usa `,` como separador **antes** de converter o decimal, contrariando o algoritmo documentado. Nenhum teste cobre o caso. | `lib/core/importacao/parser_lista_local.dart:37` × `docs/04:39` (e a contradição com `docs/04:36`) | [04](04-importacao-lista.md) §3 | confirmado |
| **R-02** | Quantidade `0` chega ao repositório e lança `ArgumentError` não tratado no meio da importação: itens anteriores são gravados, o restante se perde e o usuário não recebe erro. | `parser_lista_local.dart:146-153` → `modal_previsao_importacao.dart:33` (sem `try/catch`) → `listas_repository.dart:161-163` | [04](04-importacao-lista.md) §2/§3 | confirmado (edições posteriores do relatório: a parte "edição inline aceita 0" era **incorreta** — `_quantidadeLida` já rejeitava `≤ 0`; corrigida na F20-T12) |
| **R-03** | Mutação perdida no flush: no sucesso o engine apaga **todas** as linhas do registro, inclusive uma mutação enfileirada durante o `await` de rede — o servidor fica defasado em silêncio. O docstring promete o contrário. | `sync_engine.dart:123` + `:126/:131/:138` + `:258-263` × docstring `:84-88` | [03](03-sincronizacao-offline.md) §3/§4 | confirmado |

## 2. Importantes

| ID | Achado | Evidência | Doc dono | Status |
| :--- | :--- | :--- | :--- | :--- |
| **R-04** | Autodeadlock do `flush()`: a reentrância `await flush()` dentro do próprio trabalho espera a si mesma (ciclo de futures) e o sync só volta com restart do app. | `sync_engine.dart:101-103`, `:105`, `:91` | [03](03-sincronizacao-offline.md) §4 | confirmado |
| **R-05** | Erro mascarado no bootstrap: com a fila esgotada em 10 tentativas nada drena (early-return) e o status fica `Sincronizado`/`Offline`, sem "tentar de novo". | `sync_engine.dart:53`, `:98`, `:333-340` | [03](03-sincronizacao-offline.md) §6 | confirmado |
| **R-06** | Detecção de relógio adiantado nunca dispara: compara `updated_at` com o relógio **do próprio dispositivo** que gerou o carimbo. | `sync_engine.dart:227-237` × `docs/03:135` | [03](03-sincronizacao-offline.md) §5 | confirmado |
| **R-07** | Convite pendente não pode ser revogado pela UI: o repositório tem `revogar()` e nenhum chamador; o link vazado vale 7 dias. | `lib/features/convites/data/convites_repository.dart:58` (sem uso em `lib/`) | [08](08-compartilhamento-colaborativo.md) §2/§5 | confirmado |
| **R-08** | Dicionário de categorias erra compostos: desempata por ordem alfabética do termo, então `"Suco de laranja"` cai em Hortifrúti em vez de Bebidas. | `lib/core/categorias/sugestao_categorias.dart:44-58` | [04](04-importacao-lista.md) §5 | confirmado |
| **R-09** | Docs donos divergentes do banco/CI: (a) publication de `lista_membros`/`convites`; (b) `06 §4`/ADR-013 afirmam deploy automático já entregue (a F19-T03 está aberta); (c) o esqueleto do `07 §3` não corresponde ao `ci.yml`; (d) `convites` fora do inventário do 01/02. | (a) `docs/01:340` × `0007_convites.sql:162-163`; (b) `docs/06:96`, `docs/00:115` × `ci.yml`; (c) `docs/07:70,109` × `ci.yml:5-8`; (d) `docs/01`, `docs/02:88-95` | 01, 02, 06, 07 | confirmado |
| **R-10** | O CI não executa o teste de Realtime (`realtime_test.mjs`); o CP da F1-T07 / `02 §5 P-05` não tem validação automática. | `.github/workflows/ci.yml:51-56` | [02](02-seguranca-rls.md) §5, [07](07-qualidade-ci.md) §3 | confirmado |
| **R-11** | O `DELETE` de `lista_membros` pode não chegar ao membro removido (a Realtime avalia a RLS por assinante e, após a remoção, `is_member` é falso): o cache local dele não seria limpo, contra o prazo de < 5 s documentado. | `0002_rls_policies.sql:122-124` + `0008` × `docs/08:171` | [08](08-compartilhamento-colaborativo.md) §7/§9 | suspeita — exige teste com 2 contas |
| **R-12** | Canal Realtime assinado sem callback de status/erro: sem re-sync em `CHANNEL_ERROR`/`TIMED_OUT`, o cache pode defasar até o próximo bootstrap. | `lib/features/sync/data/supabase_bootstrap.dart:197-230` × `docs/03:70` | [03](03-sincronizacao-offline.md) §4 | suspeita |
| **R-13** | `beforeSend` do Sentry limpa apenas breadcrumbs: `extra`, `contexts` e mensagem de exceção podem carregar dados de itens. | `lib/main.dart:50-53` × `docs/07:121` | [07](07-qualidade-ci.md) §4 | suspeita |

## 3. Menores e dívidas

| ID | Achado | Evidência | Doc dono |
| :--- | :--- | :--- | :--- |
| **R-14** | Única tela fora do design system/i18n: `EdgeInsets.all(24)`, `SizedBox(16)` e 2 textos literais na tela de callback do login Web. | `lib/router.dart:174-182` | [05](05-app-flutter.md) §7, [15](15-design-system.md) |
| **R-15** | Comentário obsoleto: diz que a versão pública da política sai na F5-T06 (foi a F19-T01). | `lib/core/l10n/politica_privacidade.dart:2` | [06](06-mvp-entregas.md) §3.3.2 |
| **R-16** | Dependências diretas sem uso em `lib/`: `cupertino_icons`; `sqlite3` (verificar o pin do WASM no Web antes de remover). | `pubspec.yaml:38,50` | [07](07-qualidade-ci.md) |
| **R-17** | `convites.criado_por` sem `on delete cascade` e fora da lista de cascatas do doc 06 — hoje não aborta `excluir_conta` (só o dono cria convite), mas vira risco com a transferência de dono (Fase 6). | `0007_convites.sql:13` × `docs/06:73-74` | [01](01-banco-de-dados.md), [06](06-mvp-entregas.md) §3.3.1 |
| **R-18** | `membros_insert_dono` aceita `papel = 'dono'` para terceiro e o comentário afirma o oposto; o invariante "1 dono" só é sustentado pelo trigger. Falta defesa em profundidade. | `0002_rls_policies.sql:126-132` (trigger: `0005:51-55`) | [02](02-seguranca-rls.md) §4.3 |
| **R-19** | `convites.atualizado_em` sem trigger de atualização (só `default now()`). | `0007_convites.sql:22` | [01](01-banco-de-dados.md) |
| **R-20** | Acessibilidade/UX. **Corrigido (2 de 6):** `AppLogo` fora da árvore semântica (`ExcludeSemantics`) e spinner do sync em 16 dp. **Pendente (4 de 6):** `SeletorTema` sem tratamento de largura/escala; telas sem scroll (`_VerificacaoEmail`, estados do login); indicador de sync ausente no painel de listas contra o wireframe. | `app_logo.dart`, `indicador_sync.dart:31`; pendentes: `seletor_tema.dart:14-35`, `registro_screen.dart:241`, `entrar_screen.dart:91`, `painel_listas.dart:97-117` × `docs/10:84` | [10](10-wireframes-telas.md), [11](11-usabilidade-fase5.md), [15](15-design-system.md) §4 |
| **R-21** | Sem CSP (`meta` ou header) no Web. **Não é divergência**: a spec da F19 não a exige — é recomendação de endurecimento. | `web/index.html`, `firebase.json:6-30` | [06](06-mvp-entregas.md) §3.4 |
| **R-22** | `supabase/config.toml` declara `sql_paths = ["./seed.sql"]`, mas o arquivo não existe: o `db reset` avisa `no files matched pattern` e o banco local fica sem dados de apoio (nenhum `seed` é carregado). | `supabase/config.toml:70` (sem `supabase/seed.sql`) | [09](09-runbook-operacoes.md) §2.4 |
| **R-23** | **Realtime local é flaky logo após `supabase start`/`db reset`** (não é a publishable key). Repro medido na F20-T11/T12: a 1ª execução do P-05 cai com os canais `CLOSED` ou com o membro sem receber o evento; a 2ª passa sempre. Causa nos logs do serviço: `Tenant realtime-dev is initializing` — o tenant reconecta ao banco (e à replication slot) por alguns segundos depois do reset, e os WS abertos nessa janela morrem. **Mitigação:** o step do CI tenta o teste **2 vezes** (com ~15 s/30 s de espera), falhando só se as duas caírem; o teste mantém 3 retentativas de assinatura. Nenhum impacto de produto (o app reconecta sozinho — R-12). | `supabase/tests/realtime_test.mjs` (1ª execução pós-`db reset`) | [03](03-sincronizacao-offline.md) §4, [07 §3](07-qualidade-ci.md) |

## 4. Já coberto por tarefas abertas (não duplicar)

- Link da Política de Privacidade no cadastro → **F19-T04** (`registro_screen.dart:177-184`).
- Deploy automático, `preview`/`live` e rollback documentado → **F19-T03**.
- Minors deferred da F19 (`docs/14:139`, `docs/00:114`, spec §4.3 duplicado, `max-age` de `/privacidade`) → fechamento da **F19**.

## 5. Pontos fortes confirmados

- Enums fechados idênticos em Postgres, Dart e docs (9 unidades, 11 categorias).
- Toda função `SECURITY DEFINER` fixa `search_path`; RLS com `enable`+`force` em todas as tabelas; unique parcial `(lista_id, lower(nome))` ativo correto.
- Escrita sempre local + fila, sem `await` de rede antes do Drift; UUID v4 no cliente; LWW com empate para o servidor.
- Suíte determinística (sem rede/relógio real) e dois testes-guarda de paridade (política de privacidade e `version.json`).
- Nenhum segredo rastreado; `dart_defines_prod.json`, `.firebase/` e keystores ignorados.

## 6. Correções de rumo desta revisão

Três achados foram recalibrados após verificação: (a) `convites.criado_por` sem cascade é **latente** (a policy exige `is_dono_de` e `criado_por = auth.uid()`), não Crítico; (b) ausência de CSP **não** é divergência de spec; (c) o link da política no cadastro já é escopo da F19-T04.
