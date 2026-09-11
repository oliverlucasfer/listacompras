-- ============================================================================
-- aceitar_convite_tests.sql — RPC aceitar_convite (doc 08 §3.1, RF-13, F7-T01)
-- Casos:
--   A-01: link pendente válido → convidado entra; membro criado; convite 'aceito'.
--   A-02: 2º aceite (mesma pessoa ou outra, mesmo link) → idempotente, sem duplicar membro.
--   A-03: convite expirado (expira_em no passado) → CONVITE_INVALIDO.
--   A-04: convite revogado → CONVITE_INVALIDO.
--   A-05: anônimo → CONVITE_INVALIDO (guarda de auth.uid() — sem sessão não aceita).
--   A-06: convite por e-mail dirigido a outra pessoa → CONVITE_NAO_DIRIGIDO_A_VOCE.
--   A-07: convite por e-mail dirigido ao próprio → entra (caminho do e-mail).
--
-- Execução (após `supabase db reset`):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/aceitar_convite_tests.sql
--
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

-- ===== setup (superuser, fora do alcance das policies) =====
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('c0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('c1000000-0000-0000-0000-000000000000', 'b@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('c2000000-0000-0000-0000-000000000000', 'c@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('c3000000-0000-0000-0000-000000000000', 'e@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- Lista do dono (D).
insert into public.listas (id, titulo, dono_id)
values ('c9000000-0000-0000-0000-000000000000', 'Lista Convites', 'c0000000-0000-0000-0000-000000000000');
insert into public.lista_membros (lista_id, user_id, papel)
values ('c9000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-000000000000', 'dono')
on conflict (lista_id, user_id) do nothing;

-- Convites do dono: link pendente (A-01/A-02/A-05), link a expirar (A-03),
-- link a revogar (A-04) e e-mail dirigido a E (A-06/A-07).
insert into public.convites (lista_id, criado_por, token, tipo, papel_oferecido)
values
  ('c9000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'link', 'editor'),
  ('c9000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'link', 'editor'),
  ('c9000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'link', 'editor');

insert into public.convites (lista_id, criado_por, token, tipo, email, papel_oferecido)
values ('c9000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444', 'email', 'e@test.com', 'leitor');

-- ===== A-01: link pendente válido → B entra =====
do $$
declare
  v_lista uuid;
  v_membros int;
  v_estado text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select public.aceitar_convite('11111111-1111-1111-1111-111111111111') into v_lista;
  perform set_config('role', 'postgres', true);

  if v_lista is distinct from 'c9000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU A-01: retorno %', v_lista;
  end if;

  select count(*) into v_membros from public.lista_membros
  where lista_id = 'c9000000-0000-0000-0000-000000000000'
    and user_id = 'c1000000-0000-0000-0000-000000000000'
    and papel = 'editor';
  if v_membros <> 1 then
    raise exception 'FALHOU A-01: % linha(s) de membro para B', v_membros;
  end if;

  select estado into v_estado from public.convites
  where token = '11111111-1111-1111-1111-111111111111';
  if v_estado <> 'aceito' then
    raise exception 'FALHOU A-01: convite ficou com estado %', v_estado;
  end if;

  raise notice 'OK A-01: link pendente aceito; membro criado (editor); convite marcado';
end $$;

-- ===== A-02: 2º aceite idempotente (B de novo; depois C pelo mesmo link) =====
do $$
declare
  v_lista uuid;
  v_b int;
  v_c int;
  v_total int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select public.aceitar_convite('11111111-1111-1111-1111-111111111111') into v_lista;
  perform set_config('role', 'postgres', true);
  if v_lista is distinct from 'c9000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU A-02: 2o aceite de B retornou %', v_lista;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c2000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select public.aceitar_convite('11111111-1111-1111-1111-111111111111') into v_lista;
  perform set_config('role', 'postgres', true);
  if v_lista is distinct from 'c9000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU A-02: aceite de C retornou %', v_lista;
  end if;

  select count(*) into v_b from public.lista_membros
  where lista_id = 'c9000000-0000-0000-0000-000000000000'
    and user_id = 'c1000000-0000-0000-0000-000000000000';
  select count(*) into v_c from public.lista_membros
  where lista_id = 'c9000000-0000-0000-0000-000000000000'
    and user_id = 'c2000000-0000-0000-0000-000000000000'
    and papel = 'editor';
  select count(*) into v_total from public.lista_membros
  where lista_id = 'c9000000-0000-0000-0000-000000000000';
  if v_b <> 1 or v_c <> 1 or v_total <> 3 then
    raise exception 'FALHOU A-02: membros B=% C=% total=%', v_b, v_c, v_total;
  end if;

  raise notice 'OK A-02: 2o aceite idempotente (B sem duplicar; C entrou pelo mesmo link)';
end $$;

-- ===== A-03: convite expirado → CONVITE_INVALIDO =====
do $$
begin
  perform set_config('role', 'postgres', true);
  update public.convites
  set expira_em = now() - interval '1 day'
  where token = '22222222-2222-2222-2222-222222222222';

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.aceitar_convite('22222222-2222-2222-2222-222222222222');
  raise exception 'FALHOU A-03: convite expirado foi aceito';
exception
  when raise_exception then
    if sqlerrm = 'CONVITE_INVALIDO' then
      raise notice 'OK A-03: convite expirado rejeitado (CONVITE_INVALIDO)';
    else
      raise exception 'FALHOU A-03: erro inesperado: %', sqlerrm;
    end if;
end $$;

-- ===== A-04: convite revogado → CONVITE_INVALIDO =====
do $$
begin
  perform set_config('role', 'postgres', true);
  update public.convites
  set estado = 'revogado'
  where token = '33333333-3333-3333-3333-333333333333';

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.aceitar_convite('33333333-3333-3333-3333-333333333333');
  raise exception 'FALHOU A-04: convite revogado foi aceito';
exception
  when raise_exception then
    if sqlerrm = 'CONVITE_INVALIDO' then
      raise notice 'OK A-04: convite revogado rejeitado (CONVITE_INVALIDO)';
    else
      raise exception 'FALHOU A-04: erro inesperado: %', sqlerrm;
    end if;
end $$;

-- ===== A-05: anônimo não aceita → CONVITE_INVALIDO (guarda de auth.uid()) =====
do $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{}', true);
  perform public.aceitar_convite('11111111-1111-1111-1111-111111111111');
  raise exception 'FALHOU A-05: anon aceitou convite';
exception
  when raise_exception then
    if sqlerrm = 'CONVITE_INVALIDO' then
      raise notice 'OK A-05: anon rejeitado (CONVITE_INVALIDO)';
    else
      raise exception 'FALHOU A-05: erro inesperado: %', sqlerrm;
    end if;
end $$;

-- ===== A-06: convite por e-mail dirigido a outra pessoa =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.aceitar_convite('44444444-4444-4444-4444-444444444444');
  raise exception 'FALHOU A-06: convite dirigido a outra pessoa foi aceito';
exception
  when raise_exception then
    if sqlerrm = 'CONVITE_NAO_DIRIGIDO_A_VOCE' then
      raise notice 'OK A-06: convite de e-mail de outro usuario rejeitado';
    else
      raise exception 'FALHOU A-06: erro inesperado: %', sqlerrm;
    end if;
end $$;

-- ===== A-07: convite por e-mail dirigido ao próprio → entra como leitor =====
do $$
declare
  v_lista uuid;
  v_estado text;
  v_papel text;
begin
  perform set_config('role', 'postgres', true);
  select estado into v_estado from public.convites
  where token = '44444444-4444-4444-4444-444444444444';
  if v_estado <> 'pendente' then
    raise exception 'FALHOU A-07: convite deveria seguir pendente apos A-06 (estado %)', v_estado;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"c3000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select public.aceitar_convite('44444444-4444-4444-4444-444444444444') into v_lista;
  perform set_config('role', 'postgres', true);

  if v_lista is distinct from 'c9000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU A-07: retorno %', v_lista;
  end if;

  select papel into v_papel from public.lista_membros
  where lista_id = 'c9000000-0000-0000-0000-000000000000'
    and user_id = 'c3000000-0000-0000-0000-000000000000';
  if v_papel is distinct from 'leitor' then
    raise exception 'FALHOU A-07: E entrou com papel %', v_papel;
  end if;

  raise notice 'OK A-07: convite por e-mail aceito pelo proprio destinatario (leitor)';
end $$;

rollback;
