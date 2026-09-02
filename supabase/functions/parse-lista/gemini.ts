// gemini.ts — chamada ao Gemini com JSON mode + timeout (doc 04 §3, §6)
export interface ItemIA {
  nome: string;
  quantidade: number;
  unidade: string;
}

export interface RespostaIA {
  itens: ItemIA[];
  aviso: string | null;
}

export class GeminiTimeoutError extends Error {}
export class GeminiQuotaError extends Error {}
export class GeminiRespostaError extends Error {}

// responseSchema do contrato (doc 04 §6) — enum espelha unidade_item (doc 01 §3)
const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    itens: {
      type: "array",
      items: {
        type: "object",
        properties: {
          nome: { type: "string" },
          quantidade: { type: "number" },
          unidade: {
            type: "string",
            enum: ["un", "kg", "g", "l", "ml", "caixa", "pacote", "pct", "dz"],
          },
        },
        required: ["nome", "quantidade", "unidade"],
      },
    },
    aviso: { type: "string", nullable: true },
  },
  required: ["itens", "aviso"],
};

const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

export async function chamarGemini(
  prompt: string,
  texto: string,
  timeoutMs: number,
  apiKey: string,
): Promise<RespostaIA> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: prompt }] },
        contents: [{ role: "user", parts: [{ text }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 1024,
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
        },
      }),
    });

    // free tier esgotado (RESOURCE_EXHAUSTED) → cota_ia (doc 04 §2)
    if (res.status === 429) throw new GeminiQuotaError();
    if (!res.ok) throw new GeminiRespostaError(`gemini http ${res.status}`);

    const data = await res.json();
    const textoJson = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof textoJson !== "string" || textoJson.length === 0) {
      throw new GeminiRespostaError("resposta sem conteúdo");
    }
    return JSON.parse(textoJson);
  } catch (e) {
    if (e instanceof GeminiQuotaError) throw e;
    if (e instanceof GeminiRespostaError) throw e;
    if (e instanceof Error && e.name === "AbortError") {
      throw new GeminiTimeoutError("timeout na chamada ao gemini");
    }
    throw new GeminiRespostaError(`falha na chamada: ${e instanceof Error ? e.message : "desconhecida"}`);
  } finally {
    clearTimeout(timer);
  }
}
