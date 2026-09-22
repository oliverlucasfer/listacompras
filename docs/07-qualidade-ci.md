# 07 — Qualidade, Testes, CI e Observabilidade

> Navegação: [← 06 MVP & Entregas](06-mvp-entregas.md) · [← Índice](../planejamento_lista_compras.md)

**Este documento é o dono da estratégia de qualidade.** Princípio: **cobertura por risco, não por percentual** — os componentes mais arriscados (Sync Engine, RLS) recebem os testes mais pesados.

---

## 1. Estratégia de testes (pirâmide adaptada)

| Camada | Ferramenta | O quê | Prioridade |
| :--- | :--- | :--- | :--- |
| **Sync Engine** (unit) | `flutter_test` | LWW, coalescing, tombstones, retry, casos-limite de [03 §5](03-sincronizacao-offline.md) | **Máxima** (RF-08) |
| **RLS** (integração SQL) | Testes com 2 usuários reais em Supabase dev | Casos N-01…N-10 e P-01…P-05 de [02 §5](02-seguranca-rls.md) | **Máxima** (RNF-03) |
| **Repositórios** (unit) | `flutter_test` + Drift in-memory | CRUD local + enfileiramento de mutações | Alta (RF-03) |
| **Widgets** | `flutter_test` + `golden_toolkit` (opcional) | Telas críticas: lista, importação local, auth | Média (RF-01…RF-05, RF-16) |
| **Fluxos críticos** (E2E no widget) | `flutter_test` + router real + Drift in-memory | Caminhos criar/adicionar/marcar/limpar, importar, entrar por código e offline — roda no CI | Alta (RNF-08) |
| **E2E** (integração app) | `integration_test` (opcional, pós-MVP) | Fluxo completo offline→online | Baixa (RNF-02) |

**Convenções:**
* Nomes: `deve_<resultado>_quando_<condição>` (ex.: `deve_manter_item_removido_offline_ao_receber_edicao_remota_antiga`).
* Sync Engine testado com fake de conectividade + fake do Supabase (determinístico, sem rede real no CI).
* Fila de mutações testada com cenários do checklist [03 §8](03-sincronizacao-offline.md).
* **Fluxos críticos (E2E no widget, F33, RNF-08):** rodam no CI via `flutter test` — o harness `test/fluxos/fluxo_harness.dart` monta o app real (router + Drift in-memory, sessão/sync/convites fake) e cobre criar/adicionar/marcar/limpar/desfazer, importar por texto, entrar por código e offline (item local + fila).

**Adiados (não rodam no CI atual):** **goldens** são sensíveis à plataforma — o dev gera no Windows e o CI roda Linux; revisitar quando houver runner Linux dedicado. **`integration_test` (device/emulador)** exige device; é validado por smoke manual, como o deep link físico. Nenhum dos dois bloqueia o merge.

## 2. O que é testado vs. aceito sem teste

| Testado | Aceito sem teste (MVP) |
| :--- | :--- |
| Sync Engine, RLS, repositórios, widgets críticos | UI de detalhe (animações), theming visual, i18n (pt-BR único), performance fino |

---

## 3. CI — GitHub Actions (desde a Fase 1)

Pipeline único `.github/workflows/ci.yml`, disparado em PR e push em `main`:

```
┌────────────────────────────────────────────────┐
│ job: flutter                                   │
│  1. dart format --set-exit-if-changed .        │
│  2. flutter analyze                            │
│  3. flutter test (unit + widget)               │
│  4. flutter build web --release                │
├────────────────────────────────────────────────┤
│ job: supabase (paralelo)                       │
│  1. supabase db reset (aplica migrations)      │
│  2. testes SQL de negação/positivos RLS        │
├────────────────────────────────────────────────┤
│ job: desktop (matriz, paralelo)                │
│  Linux: deps (clang/cmake/ninja/gtk) + build   │
│  Windows: flutter build windows                │
└────────────────────────────────────────────────┘
```

* PR só mergea com CI verde (branch protection).
* **Builds de plataforma (F18-T05, ADR-012):** o job `flutter` compila o Web (`flutter build web --release`) e o job `desktop` valida `flutter build linux` (ubuntu-latest, instala `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libcurl4-openssl-dev libssl-dev` — as duas últimas são exigidas pelo `sentry-native` via `FindCURL`) e `flutter build windows` (windows-latest) numa matriz com `fail-fast: false`. Os builds usam **valores fictícios** de `--dart-define` (`SUPABASE_URL=https://exemplo.supabase.co`, `SUPABASE_ANON_KEY=teste`) — nenhum segredo real entra no CI.
* **Assets WASM do Drift versionados (F18-T01):** `web/drift_worker.js` e `web/sqlite3.wasm` são cópias fiéis da release oficial `drift-2.34.4` (mesma versão pinada em `pubspec.lock`), necessárias ao banco no navegador (`WasmDatabase`/OPFS-IndexedDB, [05 §2](05-app-flutter.md), ADR-012). Para regenerar (ex.: subir o Drift), baixar da release correspondente e substituir os dois arquivos:
  ```bash
  curl -L -o web/drift_worker.js https://github.com/simolus3/drift/releases/download/drift-2.34.4/drift_worker.js
  curl -L -o web/sqlite3.wasm    https://github.com/simolus3/drift/releases/download/drift-2.34.4/sqlite3.wasm
  ```
  A versão do Drift em `pubspec.lock` e os assets devem andar juntos; `flutter build web --release` valida a **compilação** — a corretude dos assets WASM é de **runtime**, não de build.
* Segurança no CI: secrets do Supabase de **ambiente de teste**, nunca produção; JWTs de teste criados na hora.
* Flutter **e** CLI do Supabase do CI **pinados** às versões usadas pelo dev (`flutter-version` no `flutter-action`, `version` no `setup-cli`) — o formatter do Dart muda entre versões (quebraria `dart format --set-exit-if-changed`) e o CLI fica pinado ao do dev para paridade.
* Tempo alvo do pipeline: < 10 min.

### Esqueleto de referência

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.44.5 }
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
      - run: >-   # valores fictícios (nunca segredos reais)
          flutter build web --release
          --dart-define=SUPABASE_URL=https://exemplo.supabase.co
          --dart-define=SUPABASE_ANON_KEY=teste

  desktop:
    strategy:
      fail-fast: false
      matrix:
        include:
          - { os: ubuntu-latest,  comando: flutter build linux }
          - { os: windows-latest, comando: flutter build windows }
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.44.5 }
      - if: matrix.os == 'ubuntu-latest'
        run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libcurl4-openssl-dev libssl-dev
      - run: ${{ matrix.comando }} --dart-define=SUPABASE_URL=https://exemplo.supabase.co --dart-define=SUPABASE_ANON_KEY=teste

  supabase:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: supabase/setup-cli@v3
        with: { version: 2.116.0 }   # pinado ao CLI do dev
      - run: supabase start -x studio -x mailpit -x logflare -x vector -x imgproxy -x storage-api
      - run: supabase db reset   # valida migrations (desde 0001 até a última)
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/rls_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/excluir_conta_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/aceitar_convite_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/transferir_dono_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/preco_item_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/arquivar_listas_tests.sql
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/convites_email_tests.sql
      - name: Teste de Realtime (01 §7, 02 §5 P-05)
        working-directory: supabase/tests
        run: |
          # Chaves do stack local (export no próprio shell — `>> $GITHUB_ENV`
          # só vale a partir do próximo step).
          set -a
          eval "$(supabase status -o env | sed 's/^/export /; s/"//g')"
          set +a
          npm ci
          # O tenant do Realtime reconecta ao banco por alguns segundos após o
          # `supabase start`/reset — a 1ª roda cai com CLOSED (R-23, infra do
          # stack local, não do app). Aguarda e tenta 2 vezes.
          for i in 1 2; do
            sleep $((i * 15))
            npm test && break
            if [ "$i" = "2" ]; then echo "Realtime falhou 2x"; exit 1; fi
          done
```

> `$DB` = `postgresql://postgres:postgres@127.0.0.1:54322/postgres` (stack local do CI); os três scripts rodam com `ON_ERROR_STOP=1` e falham o job em qualquer negação indevida.
>
> **Teste de Realtime (`supabase/tests/realtime_test.mjs`, F20-T07):** `npm ci && npm test` no mesmo job, com as chaves do stack exportadas (`supabase status -o env`). O step tenta o teste **2 vezes**: logo após `supabase start`/`db reset` o tenant do Realtime ainda está reconectando ao banco e a 1ª execução cai com `CLOSED` (flake de infraestrutura local, R-23 — não do app). Falha só se as duas tentativas caírem.

---

## 4. Observabilidade

* **Sentry (plano free)** no Flutter (ADR-009):
  * Crash nativos, erros não tratados, `syncStatus = Erro` persistente.
  * **Regra de privacidade:** logs **nunca** contêm nomes de itens nem conteúdo de listas ([06 §3.1](06-mvp-entregas.md)); apenas IDs técnicos. No app, `sendDefaultPii = false` e o `beforeSend` (`limparDadosDoSentry`, `lib/core/observabilidade/`, com teste unitário) limpa **breadcrumbs, `extra` e `contexts`** antes do envio (R-13/F21-T02) — nada de payload de Drift/PostgREST sai do dispositivo.
* Eventos mínimos monitorados:
  1. Falha de flush com fila > 10 mutações ou mutação com > 5 tentativas.
  2. Divergência grosseira de relógio (`ts_local` vs `now()` do servidor — RPC `agora_servidor`, ver [03 §5](03-sincronizacao-offline.md)).
* Dashboards: Sentry issues + métricas da Seção 5 de [06](06-mvp-entregas.md) (manual no MVP).

---

## 5. Checklist de qualidade por PR (disciplina leve)

- [ ] `dart format` e `flutter analyze` sem queixas.
- [ ] Novo comportamento de sync/RLS tem teste correspondente.
- [ ] CI verde antes do merge.
- [ ] Sem segredo/chave em código ou logs.

---

## Documentos relacionados
- [02 Segurança RLS](02-seguranca-rls.md) — testes de negação que rodam no CI
- [03 Sincronização Offline-First](03-sincronizacao-offline.md) — prioridade máxima de testes
- [06 MVP & Entregas](06-mvp-entregas.md) — DoD por fase e privacidade dos logs
