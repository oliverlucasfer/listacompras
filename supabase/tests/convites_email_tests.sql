-- ============================================================================
-- convites_email_tests.sql — RPCs de convite por e-mail (doc 08 §4, RF-13, F32)
-- Casos (spec §7):
--   CE-01: meus_convites_pendentes() devolve o convite do meu e-mail (título e
--          token) e NÃO devolve o de outro e-mail.
--   CE-02: recusar_convite(id) revoga só o meu; o de outro e-mail →
--          CONVITE_INVALIDO (e o convite alheio permanece pendente).
--   CE-03: convite expirado não aparece em meus_convites_pendentes().
--   CE-04: anon não executa os RPCs (grant restrito).
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
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b2222222-2222-2222-2222-222222222222', 'email', 'convidado@test.com', 'leitor', now() - interval '1 day'),
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b3333333-3333-3333-3333-333333333333', 'email', 'outro@test.com', 'editor', now() + interval '7 days');

-- ===== CE-01: convidado vê só o próprio (título e token); não o de outro e-mail =====
do $$
declare v_qtd int; v_titulo text; v_token uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*), max(lista_titulo), (array_agg(token))[1] into v_qtd, v_titulo, v_token from public.meus_convites_pendentes();
  perform set_config('role', 'postgres', true);
  if v_qtd <> 1 then raise exception 'FALHOU CE-01: % linhas', v_qtd; end if;
  if v_titulo <> 'Compras da Semana' then raise exception 'FALHOU CE-01: titulo %', v_titulo; end if;
  if v_token is distinct from 'b1111111-1111-1111-1111-111111111111'::uuid then
    raise exception 'FALHOU CE-01: token %', v_token;
  end if;
  raise notice 'OK CE-01: convidado ve o proprio convite (com titulo e token)';
end $$;

-- ===== CE-02: revoga o meu; o de outro e-mail → CONVITE_INVALIDO =====
do $$
declare v_msg text; v_proprio uuid; v_alheio uuid;
begin
  select id into v_proprio from public.convites where token = 'b1111111-1111-1111-1111-111111111111';
  select id into v_alheio  from public.convites where token = 'b3333333-3333-3333-3333-333333333333';
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.recusar_convite(v_proprio);
  begin
    perform public.recusar_convite(v_alheio);
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU CE-02: recusou convite de outro e-mail';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%CONVITE_INVALIDO%' then
      raise exception 'FALHOU CE-02: erro inesperado %', v_msg;
    end if;
  end;
  if (select estado from public.convites where token = 'b1111111-1111-1111-1111-111111111111') is distinct from 'revogado' then
    raise exception 'FALHOU CE-02: nao revogou o proprio';
  end if;
  if (select estado from public.convites where token = 'b3333333-3333-3333-3333-333333333333') is distinct from 'pendente' then
    raise exception 'FALHOU CE-02: convite alheio foi alterado';
  end if;
  raise notice 'OK CE-02: revoga o proprio e rejeita o alheio (permanece pendente)';
end $$;

-- ===== CE-03: convite expirado não aparece =====
do $$
declare v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*) into v_qtd from public.meus_convites_pendentes() where token = 'b2222222-2222-2222-2222-222222222222';
  perform set_config('role', 'postgres', true);
  if v_qtd <> 0 then raise exception 'FALHOU CE-03: % linhas expiradas', v_qtd; end if;
  raise notice 'OK CE-03: convite expirado nao aparece';
end $$;

-- ===== CE-04: anon não executa os RPCs (grant restrito) =====
do $$
begin
  perform set_config('role', 'anon', true);
  perform public.meus_convites_pendentes();
  raise exception 'FALHOU CE-04: anon executou meus_convites_pendentes';
exception
  when insufficient_privilege then
    perform set_config('role', 'postgres', true);
    raise notice 'OK CE-04: permissao negada a anon em meus_convites_pendentes';
end $$;

do $$
begin
  perform set_config('role', 'anon', true);
  perform public.recusar_convite('b1111111-1111-1111-1111-111111111111');
  raise exception 'FALHOU CE-04: anon executou recusar_convite';
exception
  when insufficient_privilege then
    perform set_config('role', 'postgres', true);
    raise notice 'OK CE-04: permissao negada a anon em recusar_convite';
end $$;

rollback;
