-- 0004_ia_rate_limit.sql — rate limiting da Edge Function (doc 04 §4)
-- Janela fixa de 1 minuto por usuário; a 11ª requisição excede o limite.
-- Acesso: apenas service_role (bypassa RLS). RLS deny-all para os demais.

create table public.ia_rate_limit (
  user_id uuid not null,
  janela  timestamptz not null,          -- início da janela de 1 minuto
  count   int not null default 0,
  primary key (user_id, janela)
);

alter table public.ia_rate_limit enable row level security;
-- force: nem o dono da tabela consulta sem policy (service_role é superuser)
alter table public.ia_rate_limit force row level security;

-- Função de janela: upsert atômico com incremento; limpa janelas > 10 min;
-- retorna true quando o usuário EXCEDEU o limite (→ 429 rate_limit).
create or replace function public.registrar_requisicao_ia(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  janela_atual timestamptz := date_trunc('minute', now());
  cnt int;
begin
  -- limpeza barata de janelas antigas (doc 04 §4)
  delete from public.ia_rate_limit
  where janela < now() - interval '10 minutes';

  insert into public.ia_rate_limit (user_id, janela, count)
  values (p_user_id, janela_atual, 1)
  on conflict (user_id, janela)
  do update set count = public.ia_rate_limit.count + 1
  returning count into cnt;

  return cnt > 10;
end;
$$;

-- Executável apenas pela service_role (Edge Function)
revoke execute on function public.registrar_requisicao_ia(uuid) from public;
revoke execute on function public.registrar_requisicao_ia(uuid) from anon;
revoke execute on function public.registrar_requisicao_ia(uuid) from authenticated;
