-- 0014_agora_servidor.sql — RPC do relógio do servidor para a observabilidade
-- de divergência de relógio (doc 03 §5, doc 07 §4 evento 2, achado R-06).
-- A detecção compara `ts_local` do dispositivo com o `now()` do banco; o
-- relógio local não serve porque é ele que gerou o `ts_local`.
-- Docs donos: 02 §4.5, 03 §5, 07 §4.

create or replace function public.agora_servidor()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select now();
$$;

-- Só usuário autenticado precisa consultar; anônimo não tem o que monitorar.
revoke execute on function public.agora_servidor() from public, anon;
grant execute on function public.agora_servidor() to authenticated;
