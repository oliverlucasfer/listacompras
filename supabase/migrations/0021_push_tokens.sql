-- 0021_push_tokens.sql — tokens de push por dispositivo (doc 01 §4.5, RF-30,
-- F38). Device-only: sem fila/Drift; o app chama `registrar_push_token`
-- (reatribui pelo `token` unique) e a Edge Function `enviar-push` lê com
-- service_role.

create table public.push_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  token         text not null unique,
  plataforma    text not null default 'android'
                  check (plataforma in ('android', 'ios')),
  atualizado_em timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index idx_push_tokens_user on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
alter table public.push_tokens force row level security;

create policy push_tokens_select on public.push_tokens
  for select using (user_id = auth.uid());

create policy push_tokens_insert on public.push_tokens
  for insert with check (user_id = auth.uid());

create policy push_tokens_update on public.push_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy push_tokens_delete on public.push_tokens
  for delete using (user_id = auth.uid());

-- Reatribuição de token (device handoff): o mesmo aparelho passa a pertencer a
-- auth.uid(). O RLS owner-only impede o upsert direto do cliente sobre a linha
-- de outro dono; este RPC `security definer` reatribui e os grants restringem a
-- `authenticated` (anon não executa).
create or replace function public.registrar_push_token(p_token text, p_plataforma text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'SEM_SESSAO';
  end if;
  delete from public.push_tokens where token = p_token and user_id <> auth.uid();
  insert into public.push_tokens (user_id, token, plataforma)
  values (auth.uid(), p_token, p_plataforma)
  on conflict (token) do update
    set user_id = auth.uid(),
        plataforma = excluded.plataforma,
        atualizado_em = now();
end;
$$;

revoke execute on function public.registrar_push_token(text, text) from public, anon;
grant execute on function public.registrar_push_token(text, text) to authenticated;
