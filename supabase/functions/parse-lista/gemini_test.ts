// gemini_test.ts — unit: mapeamento de erros do Gemini (doc 04 §2, §3)
// Os códigos 429 cota_ia e 504 timeout_ia não são determinísticos e2e; aqui
// são exercitados com fetch fake.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  chamarGemini,
  GeminiQuotaError,
  GeminiRespostaError,
  GeminiTimeoutError,
} from "./gemini.ts";

const PROMPT = "prompt";
const TEXTO = "1kg de arroz";
const API_KEY = "teste";

type FakeFetch = (
  url: string | URL | Request,
  init?: RequestInit,
) => Response | Promise<Response>;

function comFetchFake(fake: FakeFetch, fn: () => Promise<void>) {
  const original = globalThis.fetch;
  globalThis.fetch = fake as unknown as typeof fetch;
  return fn().finally(() => {
    globalThis.fetch = original;
  });
}

function respostaGemini(textoJson: string, status = 200): Response {
  return new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: textoJson }] } }],
    }),
    { status },
  );
}

Deno.test("deve_retornar_json_parseado_quando_gemini_responde", () =>
  comFetchFake(
    () => respostaGemini(JSON.stringify({ itens: [], aviso: null })),
    async () => {
      const r = await chamarGemini(PROMPT, TEXTO, 1000, API_KEY);
      assertEquals(r, { itens: [], aviso: null });
    },
  ));

Deno.test("deve_mapear_http_429_para_GeminiQuotaError_quando_cota_excedida", () =>
  comFetchFake(
    () => new Response("quota", { status: 429 }),
    async () => {
      await assertRejects(
        () => chamarGemini(PROMPT, TEXTO, 1000, API_KEY),
        GeminiQuotaError,
      );
    },
  ));

Deno.test("deve_mapear_abort_para_GeminiTimeoutError_quando_estoura_timeout", () =>
  comFetchFake(
    (_url, init) =>
      new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          const e = new Error("aborted");
          e.name = "AbortError";
          reject(e);
        });
      }),
    async () => {
      await assertRejects(
        () => chamarGemini(PROMPT, TEXTO, 10, API_KEY),
        GeminiTimeoutError,
      );
    },
  ));

Deno.test("deve_mapear_http_5xx_para_GeminiRespostaError_quando_gemini_falha", () =>
  comFetchFake(
    () => new Response("boom", { status: 503 }),
    async () => {
      await assertRejects(
        () => chamarGemini(PROMPT, TEXTO, 1000, API_KEY),
        GeminiRespostaError,
      );
    },
  ));

Deno.test("deve_lancar_GeminiRespostaError_quando_resposta_sem_conteudo", () =>
  comFetchFake(
    () => respostaGemini("", 200),
    async () => {
      await assertRejects(
        () => chamarGemini(PROMPT, TEXTO, 1000, API_KEY),
        GeminiRespostaError,
      );
    },
  ));

Deno.test("deve_lancar_GeminiRespostaError_quando_json_malformado", () =>
  comFetchFake(
    () => respostaGemini("não é json"),
    async () => {
      await assertRejects(
        () => chamarGemini(PROMPT, TEXTO, 1000, API_KEY),
        GeminiRespostaError,
      );
    },
  ));
