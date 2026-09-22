# C4 — CSP recomendada no Web (endurecimento) (design)

> **Status:** aprovado em 22/09/2026 (decisões na Seção 6)
> **Fase:** 35 · **Referência:** R-21 · **ADR:** ADR-013
> **Docs donos:** [06](../06-mvp-entregas.md) (entregas/LGPD), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

A R-21 registra a ausência de CSP no Web **sem tratá-la como divergência** — é recomendação de endurecimento. Como o **ADR-013** cancelou a publicação Web (uso local; artefatos de hosting removidos) e o doc 06 §3.4.1 diz que o endurecimento só volta a fazer sentido se a publicação for retomada, o entregável útil é **deixar a política pronta** para quem servir `build/web` ou retomar a publicação — sem impor uma CSP ao vivo que não traz benefício no uso local e arriscaria quebrar o Flutter/Drift WASM.

## 2. Escopo

**Dentro:**
- Documentar a **CSP recomendada** (string pronta) + **COOP/COEP** no doc 06 §3.4.1, com os caveats e o gatilho de aplicação.
- Fechamento: doc 14 (Fase 35) e doc 16 (C4 concluído).

**Fora:**
- Sem `<meta http-equiv="Content-Security-Policy">` no `web/index.html`, sem `web/_headers` (contraria o ADR-013), sem código/migrations, sem RF novo.

## 3. Política recomendada (conteúdo do doc 06 §3.4.1)

Aplicável **quando o Web for servido por um static server ou a publicação for retomada** (não se aplica ao `flutter run -d chrome`, que já funciona sem configuração extra). Preferir **header HTTP**; em `<meta>` os diretivos `frame-ancestors`, `report-uri`/`report-to` e `sandbox` são ignorados.

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com;
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: blob:;
  font-src 'self' data: https://fonts.gstatic.com;
  connect-src 'self' https://SEU-PROJETO.supabase.co wss://SEU-PROJETO.supabase.co https://www.gstatic.com;
  worker-src 'self' blob:;
  object-src 'none';
  base-uri 'self';
  form-action 'self';
  frame-ancestors 'none'
```

> **CanvasKit (CDN por padrão):** `flutter build web` usa `--web-resources-cdn` por padrão, então o CanvasKit é carregado de `https://www.gstatic.com/flutter-canvaskit/<rev>/`. O `canvaskit.js` é buscado por `import()` dinâmico (→ `script-src`) e o `canvaskit.wasm` por fetch (→ `connect-src`) — por isso `https://www.gstatic.com` aparece nas duas diretivas. **Alternativa mais restrita:** compilar com `flutter build web --no-web-resources-cdn` empacota o CanvasKit em `build/web`; aí `script-src 'self' 'wasm-unsafe-eval'` (sem gstatic) é exato e o `connect-src` pode dispensar a origem do gstatic.

Cabeçalhos de isolamento (SharedArrayBuffer/OPFS do Drift WASM):

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Notas a registrar:
- `script-src 'wasm-unsafe-eval'` cobre o CanvasKit/skwasm; `style-src 'unsafe-inline'` é exigido pelos estilos inline do Flutter.
- `worker-src 'self' blob:` cobre o `drift_worker.js`; `sqlite3.wasm`/`drift_worker.js` são servidos do próprio `build/web` (`'self'`) — ou do CDN junto com o CanvasKit no build padrão.
- `connect-src` precisa das origens **https e wss** do projeto Supabase (ajuste o `SEU-PROJETO`) e, no build padrão, de `https://www.gstatic.com` (fetch do `canvaskit.wasm`); ao servir local, o dev server do Flutter já atende `'self'`.
- `font-src` inclui `https://fonts.gstatic.com` para a fonte de fallback que o Flutter baixa.
- Se `SENTRY_DSN` estiver definido no build Web (o init do Sentry só roda com DSN não vazio), inclua também a origem de ingest do Sentry (ex.: `https://o*.ingest.sentry.io`) em `connect-src`.
- Com COEP `require-corp`, recursos cross-origin exigem CORP — os assets locais são same-origin e, no build padrão, o CanvasKit vem do gstatic já com CORP. Fetches cross-origin por **CORS** (Supabase REST) e **WebSocket** (Realtime) **não** são governados por CORP, então funcionam sem header CORP.

## 4. Documentos donos no mesmo PR
- `06 §3.4.1` (a CSP recomendada, no lugar da frase genérica "endurecimento futuro"), `14` (Fase 35), `16` (C4 concluído).

## 5. Verificação
- Revisão de conteúdo: a política é coerente com Flutter Web + Drift WASM + Supabase e não contradiz o ADR-013.
- Gate inalterado (sem código): `dart format`/`flutter analyze`/`flutter test` seguem verdes.

## 6. Decisões registradas (22/09/2026)

1. C4 = **documentar a CSP recomendada** (não aplicar ao vivo), alinhado a R-21 (recomendação) e ADR-013 (Web local-only).
2. Sem `<meta>` no `index.html` e sem `web/_headers`; preferir header HTTP quando o Web for servido/publicado.
3. Fase **35**; sem ADR novo; sem RF novo.

## 7. Documentos relacionados
- [06 MVP & Entregas](../06-mvp-entregas.md) — §3.4/§3.4.1 (Web e cabeçalhos)
- [14 Tarefas](../14-tarefas.md) — Fase 35 · [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda C (C4)
- [00 Visão Geral](../00-visao-geral.md) — ADR-013
