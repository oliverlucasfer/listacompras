-- ============================================================================
-- push_tokens_tests.sql — RLS de tokens de push (doc 02 §5, RF-30, F38)
-- Casos:
--   N-19: A não lê token de B.
--   N-20: A não insere token para B (with check).
--   N-21: A não apaga token de B.
--   N-22: anon não executa registrar_push_token (grant restrito).
--   P-12: A lê/insere/apaga o próprio; o RPC reatribui o token a outro dono.
--   N-24..N-26 (G-30, F43-T08): anon não lê/insere/apaga push_tokens.
--   G-29 (F43-T08): CHECK de tamanho de `token` (1..4096).
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('c0000000-0000-0000-0000-000000000000', 'a@push.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('c1000000-0000-0000-0000-000000000000', 'b@push.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.push_tokens (user_id, token, plataforma)
values ('c1000000-0000-0000-0000-000000000000', 'token-do-b', 'android');

-- ===== N-19: A não lê o token de B =====
do $$
declare v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*) into v_qtd from public.push_tokens where token = 'token-do-b';
  perform set_config('role', 'postgres', true);
  if v_qtd <> 0 then raise exception 'FALHOU N-19: A viu % tokens de B', v_qtd; end if;
  raise notice 'OK N-19: A nao le o token de B';
end $$;

-- ===== N-20: A não insere token para B =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    insert into public.push_tokens (user_id, token) values ('c1000000-0000-0000-0000-000000000000', 'token-falso');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU N-20: A inseriu token para B';
  exception when insufficient_privilege then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    raise notice 'OK N-20: with check barrou token para B (%)', v_msg;
  end;
end $$;

-- ===== N-21: A não apaga o token de B =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  delete from public.push_tokens where token = 'token-do-b';
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.push_tokens where token = 'token-do-b') <> 1 then
    raise exception 'FALHOU N-21: A apagou o token de B';
  end if;
  raise notice 'OK N-21: A nao apaga o token de B';
end $$;

-- ===== P-12: A gerencia o próprio; o RPC reatribui o token a B =====
do $$
declare v_dono uuid; v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  insert into public.push_tokens (user_id, token) values ('c0000000-0000-0000-0000-000000000000', 'token-do-a');
  if (select count(*) from public.push_tokens) <> 1 then
    raise exception 'FALHOU P-12: A nao ve apenas o proprio token';
  end if;

  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.registrar_push_token('token-do-a', 'android');
  if (select count(*) from public.push_tokens where token = 'token-do-a') <> 1 then
    raise exception 'FALHOU P-12: B nao ve o token reatribuido';
  end if;

  perform set_config('role', 'postgres', true);
  select count(*), (array_agg(user_id))[1] into v_qtd, v_dono
    from public.push_tokens where token = 'token-do-a';
  if v_qtd <> 1 then raise exception 'FALHOU P-12: % linhas para o token', v_qtd; end if;
  if v_dono <> 'c1000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU P-12: token ainda pertence a %', v_dono;
  end if;
  raise notice 'OK P-12: A gerencia o proprio e o RPC reatribui o token a B';
end $$;

-- ===== N-22: anon não executa registrar_push_token =====
do $$
begin
  perform set_config('role', 'anon', true);
  perform public.registrar_push_token('token-anon', 'android');
  raise exception 'FALHOU N-22: anon executou registrar_push_token';
exception
  when insufficient_privilege then
    perform set_config('role', 'postgres', true);
    raise notice 'OK N-22: permissao negada a anon em registrar_push_token';
end $$;

-- ===== N-24: anon não lê push_tokens =====
do $$
declare c int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{}', true);
  select count(*) into c from public.push_tokens;
  perform set_config('role', 'postgres', true);
  if c <> 0 then raise exception 'FALHOU N-24: anon viu % tokens', c; end if;
  raise notice 'OK N-24: anon nao le push_tokens';
end $$;

-- ===== N-25: anon não insere push_token =====
do $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{}', true);
  begin
    insert into public.push_tokens (user_id, token)
    values ('c1000000-0000-0000-0000-000000000000', 'token-anon');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU N-25: anon inseriu push_token';
  exception when insufficient_privilege then
    perform set_config('role', 'postgres', true);
    raise notice 'OK N-25: with check negou insert de anon';
  end;
end $$;

-- ===== N-26: anon não apaga push_token =====
do $$
declare c int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{}', true);
  delete from public.push_tokens where token = 'token-do-b';
  get diagnostics c = row_count;
  perform set_config('role', 'postgres', true);
  if c <> 0 then raise exception 'FALHOU N-26: anon apagou % tokens', c; end if;
  if (select count(*) from public.push_tokens where token = 'token-do-b') <> 1 then
    raise exception 'FALHOU N-26: token de B sumiu';
  end if;
  raise notice 'OK N-26: anon nao apaga push_tokens';
end $$;

-- ===== G-29: CHECK de tamanho de `token` (1..4096) =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    insert into public.push_tokens (user_id, token)
    values ('c0000000-0000-0000-0000-000000000000', repeat('x', 4097));
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU G-29 (token): token acima de 4096 aceito';
  exception when check_violation then
    perform set_config('role', 'postgres', true);
    raise notice 'OK G-29 (token): CHECK de tamanho rejeitou';
  end;
end $$;

rollback;
