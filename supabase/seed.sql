-- seed.sql — dados de apoio para o banco LOCAL (doc 09 §2.4, R-22).
-- Aplicado por `supabase db reset` (config.toml: [db.seed] sql_paths).
-- Nunca roda em produção: `supabase db push` não executa seed.
--
-- Objetivo: um conjunto mínimo e previsível para desenvolvimento manual —
-- NÃO é fixture de teste (os testes SQL criam os próprios dados e fazem
-- ROLLBACK; os testes de widget usam banco em memória).
--
-- As contas ficam sem senha utilizável de propósito: para logar no app local,
-- crie um usuário pelo próprio app ou pelo Studio (http://127.0.0.1:54323).

-- ============================================================================
-- Usuários de desenvolvimento
-- ============================================================================
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, instance_id,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current
)
values
  (
    '00000000-0000-4000-a000-000000000001', 'dev-dono@local.test', 'x',
    'authenticated', 'authenticated', now(),
    '00000000-0000-0000-0000-000000000000', '{"provider":"email","providers":["email"]}',
    '{}', now(), now(), '', '', '', '', ''
  ),
  (
    '00000000-0000-4000-a000-000000000002', 'dev-editor@local.test', 'x',
    'authenticated', 'authenticated', now(),
    '00000000-0000-0000-0000-000000000000', '{"provider":"email","providers":["email"]}',
    '{}', now(), now(), '', '', '', '', ''
  )
on conflict (id) do nothing;

-- ============================================================================
-- Lista de exemplo (o trigger `trg_listas_cria_dono` cria a linha do dono)
-- ============================================================================
insert into public.listas (id, titulo, dono_id)
values (
  '00000000-0000-4000-b000-000000000001',
  'Compras da semana (seed)',
  '00000000-0000-4000-a000-000000000001'
)
on conflict (id) do nothing;

insert into public.lista_membros (lista_id, user_id, papel)
values (
  '00000000-0000-4000-b000-000000000001',
  '00000000-0000-4000-a000-000000000002',
  'editor'
)
on conflict (lista_id, user_id) do nothing;

insert into public.itens_lista (id, lista_id, nome, quantidade, unidade, categoria)
values
  ('00000000-0000-4000-c000-000000000001', '00000000-0000-4000-b000-000000000001', 'Arroz', 1, 'kg', 'mercearia'),
  ('00000000-0000-4000-c000-000000000002', '00000000-0000-4000-b000-000000000001', 'Banana', 6, 'un', 'hortifruti'),
  ('00000000-0000-4000-c000-000000000003', '00000000-0000-4000-b000-000000000001', 'Leite', 2, 'l', 'laticinios')
on conflict (id) do nothing;
