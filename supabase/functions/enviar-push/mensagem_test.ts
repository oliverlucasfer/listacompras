import { assertEquals } from "jsr:@std/assert@1";
import { montarMensagem, tipoDoEvento } from "./mensagem.ts";

Deno.test("deve_mapear_convite_quando_evento_email", () => {
  assertEquals(tipoDoEvento("convite_email_criado"), "convite");
});

Deno.test("deve_mapear_membro_quando_evento_entrou", () => {
  assertEquals(tipoDoEvento("membro_entrou"), "membro");
});

Deno.test("deve_devolver_null_quando_evento_desconhecido", () => {
  assertEquals(tipoDoEvento("outro"), null);
  assertEquals(montarMensagem("outro", "X"), null);
});

Deno.test("deve_montar_corpo_com_titulo_da_lista", () => {
  assertEquals(montarMensagem("convite_email_criado", "Compras"), {
    titulo: "Convite para lista",
    corpo: 'Você recebeu um convite para "Compras".',
  });
});
