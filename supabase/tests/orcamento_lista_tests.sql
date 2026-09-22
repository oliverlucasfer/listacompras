-- ============================================================================
-- orcamento_lista_tests.sql — coluna orcamento_centavos (doc 01 §4.1, RF-28, F36-T01)
--   ORC-01: orçamento ausente (NULL) aceito.
--   ORC-02: 0 e valor normal aceitos.
--   ORC-03: negativo rejeitado; acima do teto rejeitado.
-- Transação com ROLLBACK final.
-- ============================================================================
begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values ('f0000000-0000-0000-0000-000000000000', 'orcamento@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

-- ===== ORC-01: NULL aceito =====
do $$
declare v int;
begin
  insert into public.listas (id, titulo, dono_id)
  values ('f9000000-0000-0000-0000-000000000000', 'Lista Orcamento', 'f0000000-0000-0000-0000-000000000000')
  returning orcamento_centavos into v;
  if v is not null then raise exception 'FALHOU ORC-01: orcamento %', v; end if;
  raise notice 'OK ORC-01: NULL aceito';
end $$;

-- ===== ORC-02: zero e valor normal =====
do $$
declare v int;
begin
  update public.listas set orcamento_centavos = 0
    where id = 'f9000000-0000-0000-0000-000000000000'
    returning orcamento_centavos into v;
  if v <> 0 then raise exception 'FALHOU ORC-02: zero virou %', v; end if;

  update public.listas set orcamento_centavos = 25000
    where id = 'f9000000-0000-0000-0000-000000000000'
    returning orcamento_centavos into v;
  if v <> 25000 then raise exception 'FALHOU ORC-02: normal virou %', v; end if;
  raise notice 'OK ORC-02: zero e normal aceitos';
end $$;

-- ===== ORC-03: negativo e acima do teto rejeitados =====
do $$
begin
  begin
    update public.listas set orcamento_centavos = -1
      where id = 'f9000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU ORC-03: negativo aceito';
  exception when check_violation then
    raise notice 'OK ORC-03: negativo rejeitado';
  end;

  begin
    update public.listas set orcamento_centavos = 100000000
      where id = 'f9000000-0000-0000-0000-000000000000';
    raise exception 'FALHOU ORC-03: acima do teto aceito';
  exception when check_violation then
    raise notice 'OK ORC-03: acima do teto rejeitado';
  end;
end $$;

rollback;
