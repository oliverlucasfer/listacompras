// rate-limit.ts — janela por usuário via RPC registrar_requisicao_ia (doc 04 §4)
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export async function excedeuRateLimit(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await admin.rpc("registrar_requisicao_ia", {
    p_user_id: userId,
  });
  if (error) throw new Error(`rate limit indisponível: ${error.message}`);
  return data === true;
}
