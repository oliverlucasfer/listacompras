-- ============================================================================
-- excluir_conta_tests.sql — Exclusão de conta (doc 06 §3.3.1, RF-11, F5-T03)
-- Casos:
--   E-01: RPC sem autenticação → exceção, nada é apagado.
--   E-02: RPC como usuário autenticado → apaga o usuário e as cascatas.
--   E-03: SELECT pós-exclusão retorna vazio em TODAS as tabelas do titular.
--   E-04: Dados de terceiros permanecem; participação do titular some.
--   E-05: RPC concede apenas a authenticated (anon falha permissão).
--
-- Execução (após `supabase db reset`):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/excluir_conta_tests.sql
--
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

-- ===== setup (superuser, fora do alcance das policies) =====
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('77777777-7777-7777-7777-777777777777', 'e@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('88888888-8888-8888-8888-888888888888', 'f@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- Lista L1: de E (dono) com item.
insert into public.listas (id, titulo, dono_id)
values ('99999999-9999-9999-9999-999999999999', 'Lista do E', '77777777-7777-7777-7777-777777777777');
insert into public.lista_membros (lista_id, user_id, papel)
values ('99999999-9999-9999-9999-999999999999', '77777777-7777-7777-7777-777777777777', 'dono')
on conflict (lista_id, user_id) do nothing;
insert into public.itens_lista (id, lista_id, nome)
values ('aaaaaaa1-0000-0000-0000-000000000000', '99999999-9999-9999-9999-999999999999', 'Leite');

-- Lista L2: do F, com E apenas como editor (doc 06 §3.3.1).
insert into public.listas (id, titulo, dono_id)
values ('99999999-9999-9999-9999-aaaaaaaaaaaa', 'Lista do F', '88888888-8888-8888-8888-888888888888');
insert into public.lista_membros (lista_id, user_id, papel)
values
  ('99999999-9999-9999-9999-aaaaaaaaaaaa', '88888888-8888-8888-8888-888888888888', 'dono'),
  ('99999999-9999-9999-9999-aaaaaaaaaaaa', '77777777-7777-7777-7777-777777777777', 'editor')
on conflict (lista_id, user_id) do nothing;
insert into public.itens_lista (id, lista_id, nome)
values ('aaaaaaa2-0000-0000-0000-000000000000', '99999999-9999-9999-9999-aaaaaaaaaaaa', 'Café');

-- Rate limit da IA de E (sem FK — limpeza explícita no RPC).
insert into public.ia_rate_limit (user_id, janela, count)
values ('77777777-7777-7777-7777-777777777777', date_trunc('minute', now()), 1);

-- ===== E-01: RPC com role authenticated SEM claims → exceção =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '', true);
  perform public.excluir_conta();
  raise exception 'FALHOU E-01: RPC aceitou chamada sem usuario';
exception
  when others then
    if sqlerrm = 'autenticacao necessaria' then
      raise notice 'OK E-01: RPC rejeitou chamada sem usuario';
    else
      raise exception 'FALHOU E-01: erro inesperado: %', sqlerrm;
    end if;
end $$;

-- ===== E-02: RPC como E (autenticado) → executa sem erro =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"77777777-7777-7777-7777-777777777777","role":"authenticated"}', true);
  perform public.excluir_conta();
  raise notice 'OK E-02: RPC executou para usuario autenticado';
end $$;

-- ===== E-03: pós-exclusão — tudo do titular apagado (cascades) =====
do $$
declare c int;
begin
  perform set_config('role', 'postgres', true);

  select count(*) into c from auth.users where id = '77777777-7777-7777-7777-777777777777';
  if c > 0 then raise exception 'FALHOU E-03: auth.users ainda tem o titular'; end if;

  select count(*) into c from public.listas where dono_id = '77777777-7777-7777-7777-777777777777';
  if c > 0 then raise exception 'FALHOU E-03: listas do titular sobreviveram'; end if;

  select count(*) into c from public.lista_membros where user_id = '77777777-7777-7777-7777-777777777777';
  if c > 0 then raise exception 'FALHOU E-03: participacoes do titular sobreviveram'; end if;

  select count(*) into c from public.itens_lista where lista_id = '99999999-9999-9999-9999-999999999999';
  if c > 0 then raise exception 'FALHOU E-03: itens da lista do titular sobreviveram'; end if;

  select count(*) into c from public.ia_rate_limit where user_id = '77777777-7777-7777-7777-777777777777';
  if c > 0 then raise exception 'FALHOU E-03: ia_rate_limit do titular sobreviveu'; end if;

  raise notice 'OK E-03: todas as tabelas do titular retornam vazio';
end $$;

-- ===== E-04: dados de terceiros permanecem; participação em lista alheia some =====
do $$
declare c int;
begin
  select count(*) into c from public.listas where id = '99999999-9999-9999-9999-aaaaaaaaaaaa';
  if c <> 1 then raise exception 'FALHOU E-04: lista de terceiro foi apagada'; end if;

  select count(*) into c from public.itens_lista where id = 'aaaaaaa2-0000-0000-0000-000000000000';
  if c <> 1 then raise exception 'FALHOU E-04: item de terceiro foi apagado'; end if;

  select count(*) into c from public.lista_membros
  where lista_id = '99999999-9999-9999-9999-aaaaaaaaaaaa'
    and user_id = '77777777-7777-7777-7777-777777777777';
  if c <> 0 then raise exception 'FALHOU E-04: participacao do titular na lista alheia sobreviveu'; end if;

  select count(*) into c from public.lista_membros
  where lista_id = '99999999-9999-9999-9999-aaaaaaaaaaaa'
    and user_id = '88888888-8888-8888-8888-888888888888'
    and papel = 'dono';
  if c <> 1 then raise exception 'FALHOU E-04: dono original foi afetado'; end if;

  raise notice 'OK E-04: dados de terceiros intactos; participacao do titular removida';
end $$;

-- ===== E-05: anon não tem permissão de executar o RPC =====
do $$
begin
  perform set_config('role', 'anon', true);
  perform public.excluir_conta();
  raise exception 'FALHOU E-05: anon executou o RPC';
exception
  when insufficient_privilege then
    raise notice 'OK E-05: permissao do RPC negada a anon';
end $$;

rollback;
