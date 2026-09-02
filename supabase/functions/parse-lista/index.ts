// index.ts — handler HTTP do parse-lista (doc 04 §2, §7)
// Ordem do contrato: 401 → 429 rate_limit → 400×2 → IA (504/429 cota/500) → 422 → 200
import { createClient } from "jsr:@supabase/supabase-js@2";
import { chamarGemini, GeminiQuotaError, GeminiTimeoutError } from "./gemini.ts";
import { excedeuRateLimit } from "./rate-limit.ts";
import { validarSchema } from "./schema.ts";

const PROMPT = await Deno.readTextFile(new URL("./prompt.md", import.meta.url));

const MAX_CHARS = 2000;
const TIMEOUT_MS = 15_000;
const LIMITE_POR_MINUTO = 10;

// Web SPA consome a função de outra origem; JWT via header (sem cookies) →
// "*" não expõe credenciais.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { "Content-Type": "application/json", ...CORS };

function erro(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: JSON_HEADERS,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    // 1. Autenticação: JWT do usuário (não aceita anon) — doc 04 §7
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return erro(401, "unauthorized", "Sessão expirada. Faça login novamente.");
    }

    // 2. Rate limit (service role, tabela ia_rate_limit) — doc 04 §4
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    if (await excedeuRateLimit(admin, user.id)) {
      return erro(429, "rate_limit", "Muitas solicitações. Aguarde um instante.");
    }

    // 3. Validação de entrada — doc 04 §2
    let texto: unknown;
    try {
      ({ texto } = await req.json());
    } catch {
      return erro(400, "texto_vazio", "Digite ou cole um texto com os itens.");
    }
    if (typeof texto !== "string" || !texto.trim()) {
      return erro(400, "texto_vazio", "Digite ou cole um texto com os itens.");
    }
    if (texto.length > MAX_CHARS) {
      return erro(400, "texto_longo", "Texto muito longo. Envie até 2.000 caracteres.");
    }

    // 4. Chamada ao Gemini com timeout — doc 04 §3
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY não configurada");
    let respostaIA;
    try {
      respostaIA = await chamarGemini(PROMPT, texto, TIMEOUT_MS, apiKey);
    } catch (e) {
      if (e instanceof GeminiTimeoutError) {
        return erro(504, "timeout_ia", "A IA demorou demais. Tente novamente.");
      }
      if (e instanceof GeminiQuotaError) {
        return erro(429, "cota_ia", "Limite diário de importações atingido. Tente amanhã.");
      }
      throw e;
    }

    // 5. Validação do JSON retornado (zod) — nunca vaza JSON bruto (doc 04 §9)
    const resposta = validarSchema(respostaIA);
    if (!resposta) {
      return erro(422, "resposta_invalida", "Não consegui entender a lista. Tente reescrever.");
    }

    return new Response(JSON.stringify(resposta), {
      headers: JSON_HEADERS,
    });
  } catch (e) {
    // Privacidade (doc 07 §4): log NUNCA contém texto de listas — só IDs/técnicos.
    console.error("erro_interno:", e instanceof Error ? `${e.name}: ${e.message}` : e);
    return erro(500, "erro_interno", "Erro inesperado. Tente novamente.");
  }
});
