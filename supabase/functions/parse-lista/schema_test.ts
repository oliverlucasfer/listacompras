// schema_test.ts — unit: validação zod do contrato (doc 04 §2) → 422 resposta_invalida
import { assertEquals } from "jsr:@std/assert@1";
import { validarSchema } from "./schema.ts";

const VALIDA = {
  itens: [
    { nome: "Arroz", quantidade: 1, unidade: "kg" },
    { nome: "Leite", quantidade: 2, unidade: "un" },
  ],
  aviso: null,
};

Deno.test("deve_aceitar_resposta_valida_do_gemini", () => {
  const r = validarSchema(VALIDA);
  assertEquals(r, VALIDA);
});

Deno.test("deve_rejeitar_unidade_fora_do_enum_retornando_null", () => {
  const r = validarSchema({
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "quilos" }],
    aviso: null,
  });
  assertEquals(r, null);
});

Deno.test("deve_rejeitar_quantidade_zero_ou_negativa_retornando_null", () => {
  assertEquals(
    validarSchema({
      itens: [{ nome: "Arroz", quantidade: 0, unidade: "kg" }],
      aviso: null,
    }),
    null,
  );
  assertEquals(
    validarSchema({
      itens: [{ nome: "Arroz", quantidade: -2, unidade: "kg" }],
      aviso: null,
    }),
    null,
  );
});

Deno.test("deve_rejeitar_item_sem_nome_retornando_null", () => {
  assertEquals(
    validarSchema({ itens: [{ quantidade: 1, unidade: "un" }], aviso: null }),
    null,
  );
});

Deno.test("deve_rejeitar_quando_itens_ausente_retornando_null", () => {
  assertEquals(validarSchema({ aviso: null }), null);
});

Deno.test("deve_descartar_campos_desconhecidos_normalizando_resposta", () => {
  const r = validarSchema({
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "kg", marca: "X" }],
    aviso: null,
    extra: true,
  });
  assertEquals(r, {
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "kg" }],
    aviso: null,
  });
});

Deno.test("deve_aceitar_aviso_textual", () => {
  const r = validarSchema({ ...VALIDA, aviso: "Quantidade assumida." });
  assertEquals(r?.aviso, "Quantidade assumida.");
});
