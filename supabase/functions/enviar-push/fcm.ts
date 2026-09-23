export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

export async function obterAccessToken(
  conta: ServiceAccount,
  fetchFn: typeof fetch = fetch,
): Promise<string> {
  const { importPKCS8, SignJWT } = await import("https://deno.land/x/jose@v5.9.6/mod.ts");
  const chave = await importPKCS8(conta.private_key, "RS256");
  const agora = Math.floor(Date.now() / 1000);
  const tokenUri = conta.token_uri ?? "https://oauth2.googleapis.com/token";
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(conta.client_email)
    .setAudience(tokenUri)
    .setIssuedAt(agora)
    .setExpirationTime(agora + 3600)
    .sign(chave);
  const resp = await fetchFn(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await resp.json();
  return json.access_token as string;
}

export async function enviarFcm(
  accessToken: string,
  projetoId: string,
  tokens: string[],
  mensagem: { titulo: string; corpo: string },
  data: Record<string, string>,
  fetchFn: typeof fetch = fetch,
): Promise<string[]> {
  const invalidos: string[] = [];
  for (const token of tokens) {
    const resp = await fetchFn(
      `https://fcm.googleapis.com/v1/projects/${projetoId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: mensagem.titulo, body: mensagem.corpo },
            data,
          },
        }),
      },
    );
    if (!resp.ok) {
      const corpo = await resp.text();
      if (
        resp.status === 404 || corpo.includes("UNREGISTERED") ||
        corpo.includes("INVALID_ARGUMENT")
      ) {
        invalidos.push(token);
      }
    }
  }
  return invalidos;
}
