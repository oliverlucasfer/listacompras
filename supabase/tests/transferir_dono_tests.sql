-- ============================================================================
-- transferir_dono_tests.sql — RPC transferir_dono (doc 08 §6, RF-14, F24-T01)
-- Casos:
--   T-01: dono transfere para editor → papéis trocam, dono_id = novo.
--   T-02: dono transfere para leitor → leitor vira dono.
--   T-03: não-dono tenta → APENAS_O_DONO_PODE_TRANSFERIR.
--   T-04: destino sem membership → NOVO_DONO_PRECISA_SER_MEMBRO.
--   T-05: transferir para si → NAO_PODE_TRANSFERIR_PARA_SI.
--   T-06: sem a flag, rebaixar o dono direto segue bloqueado pelo trigger.
--   T-07 (R-17): excluir a conta do ex-dono com convite criado não falha e o
--                convite some (cascade).
-- Execução após `supabase db reset`; ROLLBACK final deixa o banco intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('d0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d1000000-0000-0000-0000-000000000000', 'editor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d2000000-0000-0000-0000-000000000000', 'leitor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d3000000-0000-0000-0000-000000000000', 'outsider@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- list1: dono D, editor E, leitor L. list2: dono D, leitor L.
insert into public.listas (id, titulo, dono_id)
values
  ('d9000000-0000-0000-0000-000000000000', 'Lista 1', 'd0000000-0000-0000-0000-000000000000'),
  ('d9000000-0000-0000-0000-000000000001', 'Lista 2', 'd0000000-0000-0000-0000-000000000000');

insert into public.lista_membros (lista_id, user_id, papel)
values
  ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'dono'),
  ('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'editor'),
  ('d9000000-0000-0000-0000-000000000000', 'd2000000-0000-0000-0000-000000000000', 'leitor'),
  ('d9000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000000', 'dono'),
  ('d9000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000000', 'leitor')
on conflict (lista_id, user_id) do nothing;

-- Convite criado por D (T-07: cascade).
insert into public.convites (lista_id, criado_por, token, tipo, papel_oferecido)
values ('d9000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000000',
        'e9000000-0000-0000-0000-000000000000', 'link', 'editor');

-- ===== T-01: D transfere list1 para E =====
do $$
declare
  v_papel_d text; v_papel_e text; v_dono uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000');
  perform set_config('role', 'postgres', true);

  select papel into v_papel_d from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000000' and user_id = 'd0000000-0000-0000-0000-000000000000';
  select papel into v_papel_e from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000000' and user_id = 'd1000000-0000-0000-0000-000000000000';
  select dono_id into v_dono from public.listas where id = 'd9000000-0000-0000-0000-000000000000';

  if v_papel_d <> 'editor' then raise exception 'FALHOU T-01: D ficou %', v_papel_d; end if;
  if v_papel_e <> 'dono' then raise exception 'FALHOU T-01: E ficou %', v_papel_e; end if;
  if v_dono is distinct from 'd1000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'FALHOU T-01: dono_id = %', v_dono;
  end if;
  raise notice 'OK T-01: transferencia para editor';
end $$;

-- ===== T-03: leitor L (não-dono de list1) tenta transferir =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d2000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd2000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-03: nao-dono transferiu';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%APENAS_O_DONO_PODE_TRANSFERIR%' then
      raise exception 'FALHOU T-03: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-03: %', v_msg;
  end;
end $$;

-- ===== T-04: E (dono de list1) transfere para outsider O =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd3000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-04: destino sem membership aceito';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%NOVO_DONO_PRECISA_SER_MEMBRO%' then
      raise exception 'FALHOU T-04: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-04: %', v_msg;
  end;
end $$;

-- ===== T-05: E (dono de list1) transfere para si =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    perform public.transferir_dono('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU T-05: transferiu para si';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%NAO_PODE_TRANSFERIR_PARA_SI%' then
      raise exception 'FALHOU T-05: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-05: %', v_msg;
  end;
end $$;

-- ===== T-02: D (dono de list2) transfere para L =====
do $$
declare v_papel_l text; v_papel_d text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.transferir_dono('d9000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000000');
  perform set_config('role', 'postgres', true);

  select papel into v_papel_l from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000001' and user_id = 'd2000000-0000-0000-0000-000000000000';
  select papel into v_papel_d from public.lista_membros
   where lista_id = 'd9000000-0000-0000-0000-000000000001' and user_id = 'd0000000-0000-0000-0000-000000000000';
  if v_papel_l <> 'dono' then raise exception 'FALHOU T-02: L ficou %', v_papel_l; end if;
  if v_papel_d <> 'editor' then raise exception 'FALHOU T-02: D ficou %', v_papel_d; end if;
  raise notice 'OK T-02: transferencia para leitor';
end $$;

-- ===== T-06: sem a flag, rebaixar o dono direto segue bloqueado =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'postgres', true);
  -- A flag de transferência é transaction-local e sobrevive aos DO blocks
  -- anteriores (T-01/T-02) — aqui o cenário é "sem a flag".
  perform set_config('app.transferindo_dono', '', true);
  begin
    update public.lista_membros set papel = 'editor'
    where lista_id = 'd9000000-0000-0000-0000-000000000000'
      and user_id = 'd1000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU T-06: downgrade direto aceito';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if v_msg not like '%processo expl%' then
      raise exception 'FALHOU T-06: erro inesperado %', v_msg;
    end if;
    raise notice 'OK T-06: trigger bloqueou downgrade direto';
  end;
end $$;

-- ===== T-07 (R-17): excluir D (ex-dono) some com o convite criado =====
do $$
declare v_convites int;
begin
  perform set_config('role', 'postgres', true);
  delete from auth.users where id = 'd0000000-0000-0000-0000-000000000000';
  select count(*) into v_convites from public.convites
   where criado_por = 'd0000000-0000-0000-0000-000000000000';
  if v_convites <> 0 then
    raise exception 'FALHOU T-07 (R-17): % convite(s) restantes', v_convites;
  end if;
  raise notice 'OK T-07: cascade de convites.criado_por';
end $$;

rollback;
