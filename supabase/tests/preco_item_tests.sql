-- ============================================================================
-- preco_item_tests.sql — coluna preco_centavos (doc 01 §4.3, RF-21, F25-T01)
-- Casos:
--   PC-01: item sem preço (NULL) aceito.
--   PC-02: preço 0 aceito; preço normal aceito.
--   PC-03: preço negativo rejeitado; acima do teto rejeitado.
-- Transação com ROLLBACK final — o banco fica intocado.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values ('e0000000-0000-0000-0000-000000000000', 'preco@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('e9000000-0000-0000-0000-000000000000', 'Lista Preço', 'e0000000-0000-0000-0000-000000000000');

-- ===== PC-01: sem preço (NULL) =====
do $$
declare v int;
begin
  insert into public.itens_lista (lista_id, nome)
  values ('e9000000-0000-0000-0000-000000000000', 'Sem preco')
  returning preco_centavos into v;
  if v is not null then raise exception 'FALHOU PC-01: preco %', v; end if;
  raise notice 'OK PC-01: NULL aceito';
end $$;

-- ===== PC-02: zero e valor normal =====
do $$
declare v int;
begin
  insert into public.itens_lista (lista_id, nome, preco_centavos)
  values ('e9000000-0000-0000-0000-000000000000', 'Zero', 0)
  returning preco_centavos into v;
  if v <> 0 then raise exception 'FALHOU PC-02: zero virou %', v; end if;

  insert into public.itens_lista (lista_id, nome, preco_centavos)
  values ('e9000000-0000-0000-0000-000000000000', 'Normal', 549)
  returning preco_centavos into v;
  if v <> 549 then raise exception 'FALHOU PC-02: normal virou %', v; end if;
  raise notice 'OK PC-02: zero e normal aceitos';
end $$;

-- ===== PC-03: negativo e acima do teto rejeitados =====
do $$
begin
  begin
    insert into public.itens_lista (lista_id, nome, preco_centavos)
    values ('e9000000-0000-0000-0000-000000000000', 'Negativo', -1);
    raise exception 'FALHOU PC-03: negativo aceito';
  exception when check_violation then
    raise notice 'OK PC-03: negativo rejeitado';
  end;

  begin
    insert into public.itens_lista (lista_id, nome, preco_centavos)
    values ('e9000000-0000-0000-0000-000000000000', 'Acima', 100000000);
    raise exception 'FALHOU PC-03: acima do teto aceito';
  exception when check_violation then
    raise notice 'OK PC-03: acima do teto rejeitado';
  end;
end $$;

rollback;
