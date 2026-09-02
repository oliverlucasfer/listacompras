-- ============================================================================
-- rls_tests.sql — Testes RLS da Fase 1 (doc 02 §5)
-- Casos: N-01..N-10 (negação) e P-01..P-04 (positivos, SQL).
-- P-05 (Realtime) é validado por supabase/tests/realtime_test.mjs (F1-T07).
--
-- Execução (após `supabase db reset`):
--   Get-Content supabase/tests/rls_tests.sql -Raw | docker exec -i supabase_db_<proj> psql -U postgres -d postgres
--
-- Tudo roda em uma transação com ROLLBACK final — o banco fica intocado.
-- Cada caso define role + JWT claims via set_config (auth.uid() lê os claims).
-- ============================================================================

begin;

-- ===== setup (superuser, fora do alcance das policies) =====
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('11111111-1111-1111-1111-111111111111', 'a@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('44444444-4444-4444-4444-444444444444', 'b@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('55555555-5555-5555-5555-555555555555', 'c@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('66666666-6666-6666-6666-666666666666', 'd@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('22222222-2222-2222-2222-222222222222', 'Lista RLS', '11111111-1111-1111-1111-111111111111');

insert into public.lista_membros (lista_id, user_id, papel)
values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'dono'),
  ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 'editor'),
  ('22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'leitor');

insert into public.itens_lista (id, lista_id, nome)
values ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Leite');

-- ===== N-01: outsider (D) não lê lista alheia → 0 linhas =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);
  select count(*) into c from public.listas where id = '22222222-2222-2222-2222-222222222222';
  if c = 0 then raise notice 'OK N-01: outsider ve 0 listas';
  else raise exception 'FALHOU N-01: outsider viu % linhas', c; end if;
end $$;

-- ===== N-02: outsider (D) INSERT de item na lista alheia → policy nega =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);
  insert into public.itens_lista (lista_id, nome) values ('22222222-2222-2222-2222-222222222222', 'Intruso');
  raise exception 'FALHOU N-02: insercao de outsider aceita';
exception when insufficient_privilege then
  raise notice 'OK N-02: policy negou INSERT de outsider';
end $$;

-- ===== N-03: leitor (C) UPDATE em item → 0 linhas =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
  update public.itens_lista set concluido = true where id = '33333333-3333-3333-3333-333333333333';
  get diagnostics c = row_count;
  if c = 0 then raise notice 'OK N-03: leitor alterou 0 linhas';
  else raise exception 'FALHOU N-03: leitor alterou % linhas', c; end if;
end $$;

-- ===== N-04: leitor (C) INSERT em itens → policy nega =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
  insert into public.itens_lista (lista_id, nome) values ('22222222-2222-2222-2222-222222222222', 'Proibido');
  raise exception 'FALHOU N-04: insert de leitor aceito';
exception when insufficient_privilege then
  raise notice 'OK N-04: policy negou INSERT de leitor';
end $$;

-- ===== N-05: editor (B) DELETE físico de item → 0 linhas =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  delete from public.itens_lista where id = '33333333-3333-3333-3333-333333333333';
  get diagnostics c = row_count;
  if c = 0 then raise notice 'OK N-05: editor removeu 0 linhas (delete so dono)';
  else raise exception 'FALHOU N-05: editor removeu % linhas', c; end if;
end $$;

-- ===== N-06: editor (B) INSERT em lista_membros → policy nega =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('22222222-2222-2222-2222-222222222222', '66666666-6666-6666-6666-666666666666', 'editor');
  raise exception 'FALHOU N-06: editor inseriu membro';
exception when insufficient_privilege then
  raise notice 'OK N-06: policy negou INSERT de membro pelo editor';
end $$;

-- ===== N-07: dono (A) tenta se remover → 0 linhas =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  delete from public.lista_membros
  where lista_id = '22222222-2222-2222-2222-222222222222'
    and user_id = '11111111-1111-1111-1111-111111111111';
  get diagnostics c = row_count;
  if c = 0 then raise notice 'OK N-07: dono nao se remove (0 linhas)';
  else raise exception 'FALHOU N-07: dono se removeu (% linhas)', c; end if;
end $$;

-- ===== N-08: anônimo (sem JWT) não lê nada → 0 linhas =====
do $$
declare c int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{}', true);
  select count(*) into c from public.listas;
  if c <> 0 then raise exception 'FALHOU N-08: anon viu % listas', c; end if;
  select count(*) into c from public.itens_lista;
  if c <> 0 then raise exception 'FALHOU N-08: anon viu % itens', c; end if;
  raise notice 'OK N-08: anon ve 0 linhas em tudo';
end $$;

-- ===== N-09: editor (B) tenta trocar dono_id para si → bloqueado =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  update public.listas
  set dono_id = '44444444-4444-4444-4444-444444444444'
  where id = '22222222-2222-2222-2222-222222222222';
  raise exception 'FALHOU N-09: editor alterou dono_id';
exception when insufficient_privilege then
  raise notice 'OK N-09: troca de dono_id bloqueada';
end $$;

-- ===== N-10: dono (A) insere 2º membro 'dono' (D, não-membro) → trigger nega =====
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('22222222-2222-2222-2222-222222222222', '66666666-6666-6666-6666-666666666666', 'dono');
  raise exception 'FALHOU N-10: 2o dono aceito';
exception when raise_exception then
  if sqlerrm like '%possui um dono%' then raise notice 'OK N-10: trigger negou 2o dono';
  else raise exception 'FALHOU N-10: erro inesperado: %', sqlerrm; end if;
end $$;

-- ===== P-01: dono cria lista + insere a si como dono =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  insert into public.listas (id, titulo, dono_id)
  values ('77777777-7777-7777-7777-777777777777', 'P-01', '11111111-1111-1111-1111-111111111111');
  insert into public.lista_membros (lista_id, user_id, papel)
  values ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'dono');
  select count(*) into c from public.listas where id = '77777777-7777-7777-7777-777777777777';
  if c = 1 then raise notice 'OK P-01: dono criou lista e se inseriu';
  else raise exception 'FALHOU P-01'; end if;
end $$;

-- ===== P-02: dono convida editor e leitor na lista nova =====
do $$
declare c int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
  insert into public.lista_membros (lista_id, user_id, papel)
  values
    ('77777777-7777-7777-7777-777777777777', '44444444-4444-4444-4444-444444444444', 'editor'),
    ('77777777-7777-7777-7777-777777777777', '55555555-5555-5555-5555-555555555555', 'leitor');
  select count(*) into c from public.lista_membros where lista_id = '77777777-7777-7777-7777-777777777777';
  if c = 3 then raise notice 'OK P-02: dono convidou editor e leitor';
  else raise exception 'FALHOU P-02: % membros', c; end if;
end $$;

-- ===== P-03: editor cria/edita/soft-deleta item =====
do $$
declare c int; ts timestamptz;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
  insert into public.itens_lista (id, lista_id, nome)
  values ('88888888-8888-8888-8888-888888888888', '22222222-2222-2222-2222-222222222222', 'Arroz');
  update public.itens_lista set concluido = true where id = '88888888-8888-8888-8888-888888888888';
  update public.itens_lista set deletado_em = now() where id = '88888888-8888-8888-8888-888888888888'
    returning deletado_em into ts;
  if ts is not null then raise notice 'OK P-03: editor criou, editou e soft-deletou';
  else raise exception 'FALHOU P-03: soft delete falhou'; end if;
end $$;

-- ===== P-04: leitor lê lista e itens =====
do $$
declare cl int; ci int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
  select count(*) into cl from public.listas where id = '22222222-2222-2222-2222-222222222222';
  select count(*) into ci from public.itens_lista
  where lista_id = '22222222-2222-2222-2222-222222222222' and deletado_em is null;
  if cl = 1 and ci = 1 then raise notice 'OK P-04: leitor le lista e itens';
  else raise exception 'FALHOU P-04: leitor veu % listas e % itens', cl, ci; end if;
end $$;

rollback;
