-- ============================================================================
-- notificar_push_tests.sql — triggers de push (doc 01 §7, RF-30, F38)
-- Casos:
--   NP-01: INSERT de convite 'email' pendente enfileira 1 request no pg_net.
--   NP-02: INSERT de convite 'link' NÃO enfileira.
--   NP-03: INSERT de membro com papel <> dono enfileira 1 request.
--   NP-04: linha do dono (auto-criada ao nascer a lista, 0010) NÃO enfileira.
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

select vault.create_secret('http://127.0.0.1:54321/functions/v1/enviar-push', 'push_function_url', 'teste');
select vault.create_secret('segredo-teste', 'push_webhook_secret', 'teste');

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('d0000000-0000-0000-0000-000000000000', 'dono@np.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('d1000000-0000-0000-0000-000000000000', 'novo@np.test', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('d9000000-0000-0000-0000-000000000000', 'Lista NP', 'd0000000-0000-0000-0000-000000000000');

-- ===== NP-01: convite email pendente enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.convites (lista_id, criado_por, tipo, email, papel_oferecido)
  values ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'email', 'novo@np.test', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois - v_antes <> 1 then
    raise exception 'FALHOU NP-01: enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-01: convite email enfileira 1 request';
end $$;

-- ===== NP-02: convite link não enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.convites (lista_id, criado_por, tipo, papel_oferecido)
  values ('d9000000-0000-0000-0000-000000000000', 'd0000000-0000-0000-0000-000000000000', 'link', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois <> v_antes then
    raise exception 'FALHOU NP-02: link enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-02: convite link nao enfileira';
end $$;

-- ===== NP-03: membro (papel <> dono) enfileira =====
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('d9000000-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'editor');
  select count(*) into v_depois from net.http_request_queue;
  if v_depois - v_antes <> 1 then
    raise exception 'FALHOU NP-03: enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-03: membro enfileira 1 request';
end $$;

-- ===== NP-04: linha do dono (auto-criada, 0010) não enfileira =====
-- A migration 0010 insere a linha do dono ao criar a lista; o WHEN
-- (new.papel <> 'dono') do trigger deve ignorá-la.
do $$
declare v_antes bigint; v_depois bigint;
begin
  select count(*) into v_antes from net.http_request_queue;
  insert into public.listas (id, titulo, dono_id)
  values ('d9100000-0000-0000-0000-000000000000', 'Lista NP dono', 'd0000000-0000-0000-0000-000000000000');
  if not exists (
    select 1 from public.lista_membros
    where lista_id = 'd9100000-0000-0000-0000-000000000000'
      and user_id = 'd0000000-0000-0000-0000-000000000000'
  ) then
    raise exception 'FALHOU NP-04: linha do dono nao foi criada';
  end if;
  select count(*) into v_depois from net.http_request_queue;
  if v_depois <> v_antes then
    raise exception 'FALHOU NP-04: dono enfileirou % requests', v_depois - v_antes;
  end if;
  raise notice 'OK NP-04: linha do dono nao enfileira';
end $$;

rollback;
