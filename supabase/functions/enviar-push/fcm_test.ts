import { assertEquals } from "jsr:@std/assert@1";
import { enviarFcm } from "./fcm.ts";

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
  const invalidos = await enviarFcm("tk", "proj", ["a", "b"], {
    titulo: "T",
    corpo: "C",
  }, { tipo: "membro" }, fake);
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
  const invalidos = await enviarFcm("tk", "proj", ["vivo", "morto"], {
    titulo: "T",
    corpo: "C",
  }, { tipo: "membro" }, fake);
  assertEquals(invalidos, ["morto"]);
});
