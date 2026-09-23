import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  exportPKCS8,
  generateKeyPair,
} from "https://deno.land/x/jose@v5.9.6/index.ts";
import { enviarFcm, obterAccessToken } from "./fcm.ts";

function respOk() {
  return new Response(JSON.stringify({ name: "ok" }), { status: 200 });
}
function respErro(status: number, corpo: string) {
  return new Response(corpo, { status });
}

Deno.test("deve_enviar_para_todos_quando_tokens_validos", async () => {
  let chamadas = 0;
  const fake: typeof fetch = () => {
    chamadas++;
    return Promise.resolve(respOk());
  };
  const invalidos = await enviarFcm(
    "tk",
    "proj",
    ["a", "b"],
    {
      titulo: "T",
      corpo: "C",
    },
    { tipo: "membro" },
    fake,
  );
  assertEquals(chamadas, 2);
  assertEquals(invalidos, []);
});

Deno.test("deve_devolver_invalidos_quando_unregistered", async () => {
  const fake: typeof fetch = (_url, init) => {
    const body = JSON.parse((init?.body as string) ?? "{}");
    const token = body.message.token;
    return Promise.resolve(
      token === "morto"
        ? respErro(404, '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}')
        : respOk(),
    );
  };
  const invalidos = await enviarFcm(
    "tk",
    "proj",
    ["vivo", "morto"],
    {
      titulo: "T",
      corpo: "C",
    },
    { tipo: "membro" },
    fake,
  );
  assertEquals(invalidos, ["morto"]);
});

Deno.test("deve_nao_marcar_invalido_quando_invalid_argument_de_payload", async () => {
  const fake: typeof fetch = () =>
    Promise.resolve(
      respErro(
        400,
        '{"error":{"message":"Invalid JSON payload received","status":"INVALID_ARGUMENT"}}',
      ),
    );
  const invalidos = await enviarFcm(
    "tk",
    "proj",
    ["a"],
    {
      titulo: "T",
      corpo: "C",
    },
    { tipo: "membro" },
    fake,
  );
  assertEquals(invalidos, []);
});

Deno.test("deve_marcar_invalido_quando_mensagem_de_registration_token", async () => {
  const fake: typeof fetch = () =>
    Promise.resolve(
      respErro(
        400,
        '{"error":{"message":"The registration token is not a valid FCM registration token","status":"INVALID_ARGUMENT"}}',
      ),
    );
  const invalidos = await enviarFcm(
    "tk",
    "proj",
    ["a"],
    {
      titulo: "T",
      corpo: "C",
    },
    { tipo: "membro" },
    fake,
  );
  assertEquals(invalidos, ["a"]);
});

Deno.test("deve_lancar_quando_oauth_falha", async () => {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const pem = await exportPKCS8(privateKey);
  const fake: typeof fetch = () =>
    Promise.resolve(new Response("nao", { status: 401 }));
  await assertRejects(() =>
    obterAccessToken(
      { client_email: "x@y.z", private_key: pem, project_id: "p" },
      fake,
    )
  );
});
