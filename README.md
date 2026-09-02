# ListaCompras

App de lista de compras inteligente e colaborativa (Flutter + Supabase + Gemini).

- **Offline-first**: escrita local (Drift/SQLite) + fila de sincronização (LWW)
- **IA**: importação de listas por texto livre (Edge Function + Gemini, JSON mode)
- **Realtime**: sincronização multi-dispositivo via WebSockets (Supabase Realtime)
- **Segurança**: Row Level Security em todas as tabelas

## Stack

Flutter · Riverpod · Drift · Supabase (Postgres, Auth, Realtime, Edge Functions) · Gemini 2.0 Flash · GitHub Actions

## Documentação

Índice completo em [`planejamento_lista_compras.md`](planejamento_lista_compras.md).
Contexto técnico em uma leitura: [`docs/13-premodelo-tecnico.md`](docs/13-premodelo-tecnico.md).

## Desenvolvimento

```bash
flutter test                        # testes
dart format . && flutter analyze    # estilo e lint
supabase db reset                   # aplica migrations local
supabase test db                    # n/a — testes RLS via psql (ver CI)
```

Testes RLS: `supabase/tests/rls_tests.sql` (negação N-01…N-10 + positivos P-01…P-05, doc 02 §5).
Testes Realtime: `node supabase/tests/realtime_test.mjs` (requer `supabase start`).
