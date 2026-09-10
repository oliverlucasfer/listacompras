-- 0007_convites.sql — tabela de convites, RLS, RPC aceitar_convite e publication
-- Docs donos: docs/08-compartilhamento-colaborativo.md (§2, §3.1, §7) · RF-13 · F7-T01
-- Policies detalhadas pertencem ao doc 02 §4.4; testes em supabase/tests/.
-- Estado 'expirado' nunca é gravado (spec F7 §3): expiração é 'pendente'
-- com expira_em < now(), avaliada no RPC aceitar_convite.

-- ============================================================================
-- 08 §2 — Tabela e índices
-- ============================================================================
create table public.convites (
  id              uuid primary key default gen_random_uuid(),
  lista_id        uuid not null references public.listas(id) on delete cascade,
  criado_por      uuid not null references auth.users(id),
  token           uuid not null default gen_random_uuid() unique,
  tipo            text not null check (tipo in ('link', 'email')),
  email           text, -- preenchido quando tipo = 'email'
  papel_oferecido text not null check (papel_oferecido in ('editor', 'leitor')),
  estado          text not null default 'pendente'
                    check (estado in ('pendente', 'aceito', 'expirado', 'revogado')),
  expira_em       timestamptz not null default now() + interval '7 days',
  created_at      timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

create index idx_convites_lista on public.convites (lista_id) where estado = 'pendente';
create index idx_convites_email on public.convites (lower(email)) where estado = 'pendente';

-- ============================================================================
-- 08 §2 — RLS (policies detalhadas: doc 02 §4.4)
-- ============================================================================
alter table public.convites enable row level security;
alter table public.convites force row level security;

-- Auxiliar para a policy de e-mail (padrão do doc 02 §1): auth.users não é
-- legível pelo role authenticated dentro de policies — SECURITY DEFINER.
create or replace function public.email_autenticado()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select u.email from auth.users u where u.id = auth.uid()
$$;

create policy "convites_select_email_proprio"
  on public.convites for select
  using (
    tipo = 'email'
    and estado = 'pendente'
    and lower(email) = lower(public.email_autenticado())
  );

-- Dono da lista vê todos os convites dela (08 §2).
create policy "convites_select_dono"
  on public.convites for select
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_insert_dono"
  on public.convites for insert
  with check (
    criado_por = auth.uid()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_update_dono"
  on public.convites for update
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  )
  with check (
    criado_por = auth.uid()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

create policy "convites_delete_dono"
  on public.convites for delete
  using (
    exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

-- ============================================================================
-- 08 §3.1 — RPC aceitar_convite
-- SECURITY DEFINER por design: insere membro e marca o convite para quem
-- não é dono (o dono revoga com UPDATE direto — RLS, policy de update).
-- Dois desvios do snippet original do doc 08, replicados no doc (§3.1):
-- 1) Guarda de anonimato (validado em A-05): a função é executável por
--    anon; sem auth.uid() o insert de membro falharia com violação NOT
--    NULL — o contrato devolve CONVITE_INVALIDO logo no início.
-- 2) Estado 'aceito' segue aceitável (validado em A-02): o doc 08 exige
--    idempotência ("2º uso apenas navega", §9) e link compartilhável
--    ("quem acessar o token válido entra", §2) — só 'revogado' e a
--    expiração (expira_em < now()) bloqueiam.
-- ============================================================================
create or replace function public.aceitar_convite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.convites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'CONVITE_INVALIDO';
  end if;

  select * into c from public.convites
  where token = p_token for update;

  if c.id is null or c.estado not in ('pendente', 'aceito') or c.expira_em < now() then
    raise exception 'CONVITE_INVALIDO';
  end if;

  if c.tipo = 'email' and lower(c.email) <> lower(
      (select email from auth.users where id = auth.uid())) then
    raise exception 'CONVITE_NAO_DIRIGIDO_A_VOCE';
  end if;

  -- idempotente: já sendo membro, apenas marca o convite
  insert into public.lista_membros (lista_id, user_id, papel)
  values (c.lista_id, auth.uid(), c.papel_oferecido)
  on conflict (lista_id, user_id) do nothing;

  update public.convites set estado = 'aceito', atualizado_em = now()
  where id = c.id;

  return c.lista_id;
end;
$$;

-- ============================================================================
-- 08 §7 — Realtime: lista_membros e convites passam ao publication
-- ============================================================================
alter publication supabase_realtime add table public.lista_membros;
alter publication supabase_realtime add table public.convites;
