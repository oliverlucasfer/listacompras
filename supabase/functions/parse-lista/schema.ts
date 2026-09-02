// schema.ts — validação zod do contrato (doc 04 §2) → 422 resposta_invalida
import { z } from "npm:zod@3";
import type { RespostaIA } from "./gemini.ts";

// enum fechado espelha unidade_item (doc 01 §3) — manter os três sincronizados
export const UNIDADES = [
  "un",
  "kg",
  "g",
  "l",
  "ml",
  "caixa",
  "pacote",
  "pct",
  "dz",
] as const;

const RespostaSchema = z.object({
  itens: z.array(
    z.object({
      nome: z.string().trim().min(1).max(120),
      quantidade: z.number().positive(),
      unidade: z.enum(UNIDADES),
    }),
  ),
  aviso: z.string().max(500).nullable(),
});

// Retorna a resposta normalizada (campos desconhecidos descartados) ou null
// quando fora do schema — nunca propõe JSON bruto ao app (doc 04 §9).
export function validarSchema(raw: unknown): RespostaIA | null {
  const parsed = RespostaSchema.safeParse(raw);
  return parsed.success ? (parsed.data as RespostaIA) : null;
}
