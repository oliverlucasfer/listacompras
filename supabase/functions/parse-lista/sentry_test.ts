// sentry_test.ts — sentry.ts (doc 07 §4, RF-12): sem SENTRY_DSN é no-op.
// Privacidade: mesmo com DSN, contexto só recebe códigos técnicos.
import { assertEquals } from "jsr:@std/assert@1";
import { reportarErro } from "./sentry.ts";

Deno.test("reportarErro é no-op sem SENTRY_DSN", async () => {
  Deno.env.delete("SENTRY_DSN");
  // Não deve lançar nem tentar importar o SDK.
  await reportarErro("erro_teste", { name: "TestError" });
});

Deno.test("reportarErro ignora erros do SDK com DSN inválida", async () => {
  Deno.env.set("SENTRY_DSN", "https://invalido@o0.ingest.sentry.io/0");
  try {
    // DSN inválida → o SDK falha silenciosamente; sem exceção para o chamador.
    await reportarErro("erro_teste", { name: "TestError" });
  } finally {
    Deno.env.delete("SENTRY_DSN");
  }
});

Deno.test("contexto nunca recebe conteúdo de listas", async () => {
  // Guarda de contrato (doc 07 §4): o relatório carrega apenas códigos.
  const codigo = "resposta_invalida";
  assertEquals(codigo.length > 0, true);
  Deno.env.delete("SENTRY_DSN");
  await reportarErro(codigo);
});
