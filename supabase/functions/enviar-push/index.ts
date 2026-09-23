import { createClient } from "jsr:@supabase/supabase-js@2";
import { montarMensagem, tipoDoEvento } from "./mensagem.ts";
import { enviarFcm, obterAccessToken, type ServiceAccount } from "./fcm.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function json(status: number, corpo: unknown): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: JSON_HEADERS,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { code: "method_not_allowed" });

  const segredo = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (segredo && req.headers.get("x-webhook-secret") !== segredo) {
    return json(401, { code: "unauthorized" });
  }

  const corpo = await req.json().catch(() => null) as
    | {
      evento?: string;
      destinatario_id?: string;
      lista_id?: string;
      token?: string;
      titulo_lista?: string;
    }
    | null;
  if (!corpo?.evento || !corpo?.destinatario_id || !corpo?.lista_id) {
    return json(400, { code: "bad_request" });
  }

  const tipo = tipoDoEvento(corpo.evento);
  const mensagem = montarMensagem(
    corpo.evento,
    corpo.titulo_lista ?? "uma lista",
  );
  if (!tipo || !mensagem) {
    return json(200, { ok: true, ignorado: "evento_desconhecido" });
  }

  const contaBruta = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!contaBruta) return json(200, { ok: true, ignorado: "sem_fcm" });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: linhas, error } = await admin
    .from("push_tokens")
    .select("token")
    .eq("user_id", corpo.destinatario_id);
  if (error) return json(500, { code: "db_erro" });
  const tokens = (linhas ?? []).map((l) => l.token as string);
  if (tokens.length === 0) {
    return json(200, { ok: true, ignorado: "sem_token" });
  }

  const conta = JSON.parse(contaBruta) as ServiceAccount;
  let accessToken: string;
  try {
    accessToken = await obterAccessToken(conta);
  } catch (_) {
    return json(500, { code: "fcm_erro" });
  }
  const data: Record<string, string> = {
    tipo,
    lista_id: String(corpo.lista_id),
    titulo: mensagem.titulo,
    corpo: mensagem.corpo,
  };
  if (corpo.token) data.token = String(corpo.token);

  const invalidos = await enviarFcm(
    accessToken,
    conta.project_id,
    tokens,
    mensagem,
    data,
  );
  if (invalidos.length > 0) {
    await admin.from("push_tokens").delete().in("token", invalidos);
  }
  return json(200, { ok: true, enviados: tokens.length - invalidos.length });
});
