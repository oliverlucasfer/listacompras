-- ============================================================================
-- arquivar_listas_tests.sql — coluna/trigger de arquivo (doc 01 §4.1, RF-22, F26)
-- Casos:
--   ARQ-01: dono arquiva e desarquiva → sucesso.
--   ARQ-02: editor tenta arquivar → APENAS_O_DONO_PODE_ARQUIVAR.
--   ARQ-03: editor renomeia sem tocar arquivada_em → sucesso.
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('f0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('f1000000-0000-0000-0000-000000000000', 'editor@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('f9000000-0000-0000-0000-000000000000', 'Lista Arquivo', 'f0000000-0000-0000-0000-000000000000');

insert into public.lista_membros (lista_id, user_id, papel)
values
  ('f9000000-0000-0000-0000-000000000000', 'f0000000-0000-0000-0000-000000000000', 'dono'),
  ('f9000000-0000-0000-0000-000000000000', 'f1000000-0000-0000-0000-000000000000', 'editor')
on conflict (lista_id, user_id) do nothing;

-- ===== ARQ-01: dono arquiva e desarquiva =====
do $$
declare v timestamptz;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f0000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  update public.listas set arquivada_em = now() where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  select arquivada_em into v from public.listas where id = 'f9000000-0000-0000-0000-000000000000';
  if v is null then raise exception 'FALHOU ARQ-01: dono nao arquivou'; end if;

  perform set_config('role', 'authenticated', true);
  update public.listas set arquivada_em = null where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  select arquivada_em into v from public.listas where id = 'f9000000-0000-0000-0000-000000000000';
  if v is not null then raise exception 'FALHOU ARQ-01: dono nao desarquivou'; end if;
  raise notice 'OK ARQ-01: dono arquiva/desarquiva';
end $$;

-- ===== ARQ-02: editor tenta arquivar =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  begin
    update public.listas set arquivada_em = now() where id = 'f9000000-0000-0000-0000-000000000000';
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU ARQ-02: editor arquivou';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%APENAS_O_DONO_PODE_ARQUIVAR%' then
      raise exception 'FALHOU ARQ-02: erro inesperado %', v_msg;
    end if;
    raise notice 'OK ARQ-02: editor rejeitado';
  end;
end $$;

-- ===== ARQ-03: editor renomeia sem tocar arquivada_em =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"f1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  update public.listas set titulo = 'Renomeada pelo editor'
  where id = 'f9000000-0000-0000-0000-000000000000';
  perform set_config('role', 'postgres', true);
  raise notice 'OK ARQ-03: editor renomeia sem interferencia';
end $$;

rollback;
