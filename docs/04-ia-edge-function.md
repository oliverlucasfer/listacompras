# 04 — IA (Edge Function + Gemini)

> Navegação: [← 03 Sincronização](03-sincronizacao-offline.md) · [05 App Flutter →](05-app-flutter.md)

**Este documento é o dono do contrato da Edge Function, do prompt de sistema e do `responseSchema`.** A API Key do Gemini vive **apenas** em Supabase Secrets — nunca no client.

---

## 1. Visão geral

```
App Flutter ──POST /functions/v1/parse-lista──► Edge Function (Deno/TS)
                                                  │ 1. valida JWT + rate limit + tamanho
                                                  │ 2. monta prompt + responseSchema
                                                  ▼
                                              Gemini API (gemini-3.5-flash-lite, JSON mode)
                                                  │
App Flutter ◄──200 { itens: [...] }──────────────┘
```

Fluxo de UX completo (modal, pré-visualização, confirmação) está em [05 App Flutter](05-app-flutter.md).

---

## 2. Contrato HTTP

### Request

```
POST https://<projeto>.supabase.co/functions/v1/parse-lista
Authorization: Bearer <jwt do usuário Supabase>
Content-Type: application/json

{ "texto": "1kg de arroz, 2 leites, 500g de queijo prato e macarrão" }
```

### Response 200

```json
{
  "itens": [
    { "nome": "Arroz", "quantidade": 1, "unidade": "kg" },
    { "nome": "Leite", "quantidade": 2, "unidade": "un" },
    { "nome": "Queijo prato", "quantidade": 500, "unidade": "g" },
    { "nome": "Macarrão", "quantidade": 1, "unidade": "un" }
  ],
  "aviso": null
}
```

* `aviso` (string nullable): observação da IA (ex.: item ambíguo interpretado) — exibida no modal de pré-visualização.
* `unidade` restrito ao enum de [01 §3](01-banco-de-dados.md): `un, kg, g, l, ml, caixa, pacote, pct, dz`.
* Conversão normalizada: se o usuário escreve "500g de queijo", a IA pode retornar `0.5 kg` **ou** `500 g` — decisão: **manter a unidade literal do usuário** quando estiver no enum; converter apenas valores sem enum possível (ex.: "meio quilo" → `0.5 kg`).

### Erros (mensagem amigável exibida no app)

Corpo de erro: `{ "code": "...", "message": "..." }` — `message` traz a string amigável pronta (mesma da tabela abaixo); o app usa `code` para lógica e pode exibir `message` diretamente.

| Código HTTP | `code` | Quando | Mensagem ao usuário |
| :--- | :--- | :--- | :--- |
| 401 | `unauthorized` | JWT ausente/inválido | "Sessão expirada. Faça login novamente." |
| 400 | `texto_vazio` | texto vazio/só espaços | "Digite ou cole um texto com os itens." |
| 400 | `texto_longo` | > 2.000 caracteres | "Texto muito longo. Envie até 2.000 caracteres." |
| 422 | `resposta_invalida` | JSON do Gemini fora do schema | "Não consegui entender a lista. Tente reescrever." |
| 429 | `rate_limit` | > 10 req/min do usuário | "Muitas solicitações. Aguarde um instante." |
| 429 | `cota_ia` | Gemini retornou quota exceeded | "Limite diário de importações atingido. Tente amanhã." |
| 504 | `timeout_ia` | > 15s na chamada | "A IA demorou demais. Tente novamente." |
| 500 | `erro_interno` | falha inesperada (logado no Sentry) | "Erro inesperado. Tente novamente." |

> **CORS:** a Web SPA consome a função de outra origem. A função responde `OPTIONS` (preflight) e inclui `Access-Control-Allow-Origin: *` nas respostas — seguro pois a autenticação usa header `Authorization` (JWT), nunca cookies. Um JWT **malformado** pode ser rejeitado pelo gateway antes da função (401 com corpo do gateway); JWT **ausente** chega à função e recebe o contrato acima.

---

## 3. Parâmetros operacionais

| Parâmetro | Valor | Motivo |
| :--- | :--- | :--- |
| Modelo | `gemini-3.5-flash-lite` | Free tier, rápido (≈1–2s), structured output. *(Original: `gemini-2.0-flash`, aposentado pela API para novos usuários — migrado em F2-T03. `gemini-3.6-flash`/`2.5-flash` também indisponíveis/inservíveis: pensam por padrão e estouram o timeout de 15s)* |
| Timeout da chamada ao Gemini | 15s | UX; falha vira erro `timeout_ia` |
| Entrada máxima | 2.000 caracteres | Custo/latência; evita abuso |
| Rate limit | 10 req/min por usuário | Protege o teto do free tier (R-02 em [00](00-visao-geral.md)) |
| Temperature | 0.1 | Extração determinística, criatividade indesejada |
| `maxOutputTokens` | 1.024 | ~50 itens é folga suficiente |

## 4. Rate limiting

Implementação simples com tabela no Postgres (sem dependência externa):

```sql
create table public.ia_rate_limit (
  user_id uuid not null,
  janela  timestamptz not null,          -- início da janela de 1 minuto
  count   int not null default 0,
  primary key (user_id, janela)
);

-- invocada pela Edge Function (service role):
create or replace function public.registrar_requisicao_ia(p_user_id uuid)
returns boolean          -- true = usuário EXCEDEU o limite (→ 429 rate_limit)
language plpgsql
security definer
set search_path = public
as $$
declare
  janela_atual timestamptz := date_trunc('minute', now());
  cnt int;
begin
  delete from public.ia_rate_limit
  where janela < now() - interval '10 minutes';

  insert into public.ia_rate_limit (user_id, janela, count)
  values (p_user_id, janela_atual, 1)
  on conflict (user_id, janela)
  do update set count = public.ia_rate_limit.count + 1
  returning count into cnt;

  return cnt > 10;
end;
$$;

-- Executável apenas pela service_role:
revoke execute on function public.registrar_requisicao_ia(uuid) from public;
revoke execute on function public.registrar_requisicao_ia(uuid) from anon;
revoke execute on function public.registrar_requisicao_ia(uuid) from authenticated;
```

* A função de janela é atômica (upsert com incremento + checagem + limpeza em uma chamada). Janela fixa por minuto (`date_trunc('minute', now())`).
* A tabela tem RLS `enable` + `force` **sem policies** (deny-all): só a `service_role` acessa — RLS não se aplica a ela.
* `execute` na função é revogado de `public`, `anon` e `authenticated`; apenas a `service_role` invoca.

## 5. Prompt de sistema

> Versionado em arquivo próprio na pasta da função: `supabase/functions/parse-lista/prompt.ts` (não embutido como string mágica no handler — o edge runtime só empacota imports, arquivos estáticos como `.md` não são suportados). Rascunho inicial:

```text
Você é um extrator de itens de lista de compras. Receberá um texto livre
em português (pode conter gírias, abreviações e quantidades informais).

TAREFA: extrair TODOS os itens de compra mencionados e retornar APENAS um
objeto JSON válido, sem texto fora do JSON, no formato:
{ "itens": [ { "nome": string, "quantidade": number, "unidade": string } ],
  "aviso": string | null }

REGRAS:
1. "nome": nome canônico curto do produto, capitalizado, sem quantidade no
   texto (ex.: "Leite", "Arroz", "Queijo prato").
2. "quantidade": número decimal > 0. Textos como "meio", "1/2" → 0.5;
   "um par" → 2; sem quantidade explícita → 1.
3. "unidade": um de ["un","kg","g","l","ml","caixa","pacote","pct","dz"].
   - massa/volume: use a unidade mencionada ("500g" → g).
   - conversões: "meio quilo" → 0.5 kg; "2 litros" → 2 l.
   - contagens ("2 leites", "3 ovos") → un.
   - embalagens ("1 caixa de leite") → caixa/pacote conforme mencionado.
   - se a unidade mencionada não estiver na lista, converta para a mais
     próxima ou use "un" e registre a dúvida em "aviso".
4. AGRUPE produtos repetidos: somar quantidades quando as unidades
   coincidirem (ex.: "leite" citado 2x com 1 un → 1 item, quantidade 2).
5. IGNORE palavras que não são produtos (ex.: "várias coisas para bolo"
   não vira item "coisas para bolo"; se impossível separar, liste como
   ingrediente concreto ou omita e avise).
6. NÃO invente itens que não estão no texto.
7. "aviso": soma dúvidas/ambiguidades em uma frase curta, ou null.
```

## 6. `responseSchema` (structured output)

Enviado na chamada ao Gemini (`generationConfig.response_mime_type = "application/json"` + `response_schema`):

```json
{
  "type": "object",
  "properties": {
    "itens": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "nome": { "type": "string" },
          "quantidade": { "type": "number" },
          "unidade": {
            "type": "string",
            "enum": ["un", "kg", "g", "l", "ml", "caixa", "pacote", "pct", "dz"]
          }
        },
        "required": ["nome", "quantidade", "unidade"]
      }
    },
    "aviso": { "type": "string", "nullable": true }
  },
  "required": ["itens", "aviso"]
}
```

## 7. Esqueleto da Edge Function (TypeScript/Deno)

```typescript
// supabase/functions/parse-lista/index.ts
import { createClient } from "jsr:@supabase/supabase-js@2";

const PROMPT = await Deno.readTextFile(
  new URL("./prompt.md", import.meta.url),
);

const MAX_CHARS = 2000;
const TIMEOUT_MS = 15_000;
const LIMITE_POR_MINUTO = 10;

Deno.serve(async (req) => {
  // 1. Autenticação: JWT do usuário (não aceita anon)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return erro(401, "unauthorized");

  // 2. Rate limit (service role, tabela ia_rate_limit)
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  if (await excedeuRateLimit(admin, user.id, LIMITE_POR_MINUTO)) {
    return erro(429, "rate_limit");
  }

  // 3. Validação de entrada
  const { texto } = await req.json();
  if (!texto?.trim()) return erro(400, "texto_vazio");
  if (texto.length > MAX_CHARS) return erro(400, "texto_longo");

  // 4. Chamada ao Gemini com timeout
  const resposta = await chamarGemini(PROMPT, texto, TIMEOUT_MS);

  // 5. Validação do JSON retornado (zod ou validação manual)
  if (!validarSchema(resposta)) return erro(422, "resposta_invalida");

  return new Response(JSON.stringify(resposta), {
    headers: { "Content-Type": "application/json" },
  });
});
```

> Os utilitários `chamarGemini`, `validarSchema`, `erro` e `excedeuRateLimit` serão implementados na Fase 2 seguindo este contrato. Logs de erro inesperados → Sentry ([07](07-qualidade-ci.md)).

## 8. Estrutura da pasta no repositório

```
supabase/
├── migrations/                 (ver 01)
└── functions/
    └── parse-lista/
        ├── index.ts            # handler HTTP
        ├── gemini.ts           # chamada + schema + timeout
        ├── rate-limit.ts       # janela por usuário
        ├── schema.ts           # validação zod do contrato
        ├── prompt.ts           # prompt de sistema versionado
        ├── gemini_test.ts      # unit: erros do Gemini (fetch fake)
        └── schema_test.ts      # unit: validação do contrato (422)
```

Testes: `deno test supabase/functions/parse-lista/` (unit) e `node supabase/tests/parse_lista_e2e.mjs` (e2e contra stack local; `--sem-gemini` roda só os cenários sem IA, usados no CI).

## 9. Checklist de validação (Fase 2)

- [ ] Sem JWT → 401; com JWT válido → processa.
- [ ] Texto > 2.000 chars → 400 `texto_longo`.
- [ ] 11 requisições em 1 min → a 11ª recebe 429.
- [ ] Prompt com lista desestruturada real extrai itens corretamente (3+ exemplos de teste).
- [ ] Gemini fora do ar / lento → 504 com mensagem amigável.
- [ ] Resposta fora do schema → 422 (nunca vaza JSON bruto ao app).
- [ ] `prompt.md` versionado; secrets só via `supabase secrets set`.

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — enum de unidades (fonte única)
- [05 App Flutter](05-app-flutter.md) — modal de importação e pré-visualização
- [00 Visão Geral](00-visao-geral.md) — risco R-02 (cota do free tier)
