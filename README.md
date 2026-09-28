# ListaCompras

App de lista de compras inteligente e colaborativa (Flutter + Supabase).

- **Offline-first**: escrita local (Drift/SQLite) + fila de sincronização (LWW)
- **Importação de lista**: parser local determinístico e offline (texto livre, RF-16)
- **Realtime**: sincronização multi-dispositivo via WebSockets (Supabase Realtime)
- **Segurança**: Row Level Security em todas as tabelas

## Stack

Flutter · Riverpod · Drift · Supabase (Postgres, Auth, Realtime) · GitHub Actions

## Documentação

Índice completo em [`planejamento_lista_compras.md`](planejamento_lista_compras.md).
Contexto técnico em uma leitura: [`docs/13-premodelo-tecnico.md`](docs/13-premodelo-tecnico.md).

## Desenvolvimento

```bash
flutter test                        # testes
dart format . && flutter analyze    # estilo e lint (CI exige)
supabase db reset                   # aplica migrations local
supabase start                      # stack local (testes SQL/Realtime)
```

### Flavors (`prod`/`lite`) e builds

Todo build exige `--flavor`. O flavor **não** seleciona o modo Dart — o entrypoint é que seleciona:

- `prod` (colaborativo): Supabase, Realtime e push (RF-30).
- `lite` (100% no aparelho): sem conta/Supabase/sync/push — exige `-t lib/main_lite.dart`.

```bash
flutter run --flavor prod
flutter run --flavor lite -t lib/main_lite.dart
flutter build apk --release --flavor prod --dart-define-from-file=dart_defines_prod.json
flutter build apk --release --flavor lite -t lib/main_lite.dart --dart-define-from-file=dart_defines_prod.json
```

O CI (`.github/workflows/ci.yml`) roda `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` e os builds Web (`flutter build web --release`), apk debug dos dois flavors (`--flavor prod` e `--flavor lite -t lib/main_lite.dart`) e desktop (Linux/Windows). Build/distribuição (Firebase App Distribution) e push/Firebase em [`docs/09`](docs/09-runbook-operacoes.md) §2.8–§2.9.

### Testes

- **RLS** (doc 02 §5): inventário de negação `N-01…N-26` e positivos `P-01…P-14` — `supabase/tests/rls_tests.sql` (N-01…N-18 + N-23, P-01…P-11 + P-13/P-14) e `supabase/tests/push_tokens_tests.sql` (N-19…N-22, N-24…N-26 e P-12).
- **Realtime:** `node supabase/tests/realtime_test.mjs` (requer `supabase start`).

### `google-services.json`

`android/app/google-services.json` **permanece rastreado**: a API key Android do Firebase não é segredo por si — é restringível no console **por package + SHA-1**. Restrinja-a ao package `br.com.oliverlucas.listacompras` e aos SHA-1 de debug/release no console. Arquivos realmente secretos (`dart_defines_prod.json`, `android/key.properties`) ficam fora do git.
