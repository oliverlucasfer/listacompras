// schema_test.ts — unit: validação zod do contrato (doc 04 §2) → 422 resposta_invalida
import { assertEquals } from "jsr:@std/assert@1";
import { validarSchema } from "./schema.ts";

const VALIDA = {
  itens: [
    { nome: "Arroz", quantidade: 1, unidade: "kg", categoria: "mercearia" },
    { nome: "Leite", quantidade: 2, unidade: "un", categoria: "laticinios" },
  ],
  aviso: null,
};

Deno.test("deve_aceitar_resposta_valida_do_gemini", () => {
  const r = validarSchema(VALIDA);
  assertEquals(r, VALIDA);
});

Deno.test("deve_aceitar_categorias_do_enum_f6t05", () => {
  const categorias = [
    "hortifruti",
    "mercearia",
    "frios",
    "laticinios",
    "congelados",
    "padaria",
    "bebidas",
    "pet",
    "limpeza",
    "higiene",
    "outros",
  ];
  for (const categoria of categorias) {
    const r = validarSchema({
      itens: [{ nome: "X", quantidade: 1, unidade: "un", categoria }],
      aviso: null,
    });
    assertEquals(r?.itens[0].categoria, categoria, `categoria ${categoria}`);
  }
});

Deno.test("deve_rejeitar_categoria_fora_do_enum_retornando_null_f6t05", () => {
  const r = validarSchema({
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "kg", categoria: "alimentos" }],
    aviso: null,
  });
  assertEquals(r, null);
});

Deno.test("deve_normalizar_categoria_faltante_para_outros_f6t05", () => {
  // Defesa contra resposta do Gemini sem a categoria exigida pelo schema.
  const r = validarSchema({
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "kg" }],
    aviso: null,
  });
  assertEquals(r?.itens[0].categoria, "outros");
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
    itens: [
      { nome: "Arroz", quantidade: 1, unidade: "kg", categoria: "mercearia", marca: "X" },
    ],
    aviso: null,
    extra: true,
  });
  assertEquals(r, {
    itens: [{ nome: "Arroz", quantidade: 1, unidade: "kg", categoria: "mercearia" }],
    aviso: null,
  });
});

Deno.test("deve_aceitar_aviso_textual", () => {
  const r = validarSchema({ ...VALIDA, aviso: "Quantidade assumida." });
  assertEquals(r?.aviso, "Quantidade assumida.");
});
