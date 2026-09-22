-- ============================================================================
-- convites_email_tests.sql — RPCs de convite por e-mail (doc 08 §4, RF-13, F32)
-- Casos:
--   CE-01: meus_convites_pendentes() devolve só o convite do meu e-mail.
--   CE-02: recusar_convite(id) revoga só o meu; o alheio → CONVITE_INVALIDO.
--   CE-03: convite expirado não aparece.
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('a0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('a1000000-0000-0000-0000-000000000000', 'convidado@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('a2000000-0000-0000-0000-000000000000', 'outro@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('a9000000-0000-0000-0000-000000000000', 'Compras da Semana', 'a0000000-0000-0000-0000-000000000000');

insert into public.convites (lista_id, criado_por, token, tipo, email, papel_oferecido, expira_em)
values
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b1111111-1111-1111-1111-111111111111', 'email', 'convidado@test.com', 'editor', now() + interval '7 days'),
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b2222222-2222-2222-2222-222222222222', 'email', 'convidado@test.com', 'leitor', now() - interval '1 day');

-- ===== CE-01: convidado vê só o pendente não expirado =====
do $$
declare v_qtd int; v_titulo text; v_token uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*), max(lista_titulo), (array_agg(token))[1] into v_qtd, v_titulo, v_token from public.meus_convites_pendentes();
  perform set_config('role', 'postgres', true);
  if v_qtd <> 1 then raise exception 'FALHOU CE-01: % linhas', v_qtd; end if;
  if v_titulo <> 'Compras da Semana' then raise exception 'FALHOU CE-01: titulo %', v_titulo; end if;
  if v_token is null then raise exception 'FALHOU CE-01: token nulo'; end if;
  raise notice 'OK CE-01: convidado ve o proprio convite (com titulo e token)';
end $$;

-- ===== CE-03: outro e-mail não vê nada =====
do $$
declare v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a2000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*) into v_qtd from public.meus_convites_pendentes();
  perform set_config('role', 'postgres', true);
  if v_qtd <> 0 then raise exception 'FALHOU CE-03: % linhas alheias', v_qtd; end if;
  raise notice 'OK CE-03: outro e-mail nao ve convites';
end $$;

-- ===== CE-02: recusar o próprio; recusar alheio/expirado falha =====
do $$
declare v_msg text; v_proprio uuid; v_expirado uuid;
begin
  select id into v_proprio from public.convites where token = 'b1111111-1111-1111-1111-111111111111';
  select id into v_expirado from public.convites where token = 'b2222222-2222-2222-2222-222222222222';
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.recusar_convite(v_proprio);
  begin
    perform public.recusar_convite(v_expirado);
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU CE-02: recusou convite expirado/alheio';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%CONVITE_INVALIDO%' then
      raise exception 'FALHOU CE-02: erro inesperado %', v_msg;
    end if;
  end;
  if (select estado from public.convites where token = 'b1111111-1111-1111-1111-111111111111') <> 'revogado' then
    raise exception 'FALHOU CE-02: nao revogou o proprio';
  end if;
  raise notice 'OK CE-02: recusa o proprio e rejeita o alheio/expirado';
end $$;

rollback;
