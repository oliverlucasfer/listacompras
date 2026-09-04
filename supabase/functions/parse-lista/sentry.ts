// sentry.ts — relatórios Sentry das Edge Functions (doc 07 §4, RF-12).
// Sem SENTRY_DSN configurada é no-op (dev/testes/CI não enviam nada).
// Privacidade (doc 07 §4, 06 §3.1): NUNCA envia texto de listas — só
// códigos técnicos e contexto sem conteúdo do usuário.

export async function reportarErro(
  codigo: string,
  contexto: Record<string, unknown> = {},
): Promise<void> {
  const dsn = Deno.env.get("SENTRY_DSN");
  if (!dsn) return;
  try {
    const Sentry = await import("npm:@sentry/deno");
    Sentry.init({ dsn });
    Sentry.captureMessage(codigo, (scope) => {
      for (const [chave, valor] of Object.entries(contexto)) {
        scope.setExtra(chave, valor);
      }
      return scope;
    });
    await Sentry.flush(2000);
  } catch {
    // Observabilidade nunca pode quebrar o fluxo do usuário.
  }
}
