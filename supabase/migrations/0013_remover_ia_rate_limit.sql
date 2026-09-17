-- 0013_remover_ia_rate_limit.sql — remoção do rate limit da IA
-- (spec F17, docs 04 e 09). A Edge Function parse-lista foi descontinuada;
-- a tabela e a RPC de rate limit deixam de existir.
-- `excluir_conta` é recriado sem a limpeza da tabela removida — era o único
-- vínculo restante (ver 0005_excluir_conta.sql).

drop function if exists public.registrar_requisicao_ia(uuid);
drop table if exists public.ia_rate_limit;

create or replace function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'autenticacao necessaria';
  end if;

  perform set_config('app.excluindo_conta', 'true', true);

  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;
