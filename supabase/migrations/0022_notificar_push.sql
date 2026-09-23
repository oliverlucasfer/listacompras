-- 0022_notificar_push.sql — dispara a Edge Function `enviar-push` (doc 08 §7,
-- RF-30, F38). URL e segredo vêm do Vault (nunca hardcoded); sem eles, a
-- função é no-op (dev/teste). Destinatário resolvido aqui, para a função não
-- precisar de auth.users.

create extension if not exists pg_net;

create or replace function public.notificar_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_segredo text;
  v_dest uuid;
  v_titulo text;
  v_corpo jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_function_url'
  order by created_at desc limit 1;
  select decrypted_secret into v_segredo
  from vault.decrypted_secrets where name = 'push_webhook_secret'
  order by created_at desc limit 1;
  if v_url is null or v_segredo is null then
    return new;
  end if;

  if tg_argv[0] = 'convite_email_criado' then
    select id into v_dest from auth.users
    where lower(email) = lower(new.email) limit 1;
    if v_dest is null or v_dest = new.criado_por then
      return new;
    end if;
    select titulo into v_titulo from public.listas where id = new.lista_id;
    v_corpo := jsonb_build_object(
      'evento', 'convite_email_criado',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'token', new.token,
      'titulo_lista', v_titulo
    );
  else
    select dono_id, titulo into v_dest, v_titulo
    from public.listas where id = new.lista_id;
    if v_dest is null or v_dest = new.user_id then
      return new;
    end if;
    v_corpo := jsonb_build_object(
      'evento', 'membro_entrou',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'titulo_lista', v_titulo
    );
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_segredo
    ),
    body := v_corpo
  );
  return new;
end;
$$;

create trigger trg_convites_push
  after insert on public.convites
  for each row
  when (new.tipo = 'email' and new.estado = 'pendente')
  execute function public.notificar_push('convite_email_criado');

create trigger trg_membros_push
  after insert on public.lista_membros
  for each row
  when (new.papel <> 'dono')
  execute function public.notificar_push('membro_entrou');
