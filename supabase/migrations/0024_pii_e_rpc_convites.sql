-- 0024_pii_e_rpc_convites.sql — PII de convites na exclusão, grant de
-- aceitar_convite e CHECK tipo↔email (G-04, G-22, G-24 — F43-T07).
-- Docs donos: 01 §4.2/§4.4, 02 §4.4/§4.7, 06 §3.3.1.
--
-- G-04: `excluir_conta` (versão atual em 0013) passa a apagar os convites
-- endereçados ao e-mail do titular ANTES do delete do usuário. O cascade de
-- `convites.criado_por` (0016) e o cascade de lista não cobrem convites
-- criados por terceiros para o e-mail do titular — esse dado (PII) precisa
-- ser removido explicitamente.
--
-- G-22: `aceitar_convite` deixa de ser executável por `anon` (default
-- PUBLIC). O aceite exige sessão; o grant a `authenticated` mantém o fluxo.
--
-- G-24: CHECK de coerência `tipo` ↔ `email` e comparação de e-mail explícita
-- no RPC (convite `link`, `email is null`, segue valendo para qualquer
-- autenticado).

-- ============================================================================
-- G-04 — exclusão de conta remove a PII de convites do titular
-- ============================================================================
create or replace function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  email_uid text;
begin
  if uid is null then
    raise exception 'autenticacao necessaria';
  end if;

  select u.email into email_uid from auth.users u where u.id = uid;

  perform set_config('app.excluindo_conta', 'true', true);

  if email_uid is not null then
    delete from public.convites where lower(email) = lower(email_uid);
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;

-- ============================================================================
-- G-22/G-24 — aceitar_convite: grant restrito e e-mail explícito
-- ============================================================================
create or replace function public.aceitar_convite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.convites%rowtype;
  email_uid text;
begin
  if auth.uid() is null then
    raise exception 'CONVITE_INVALIDO';
  end if;

  select * into c from public.convites
  where token = p_token for update;

  if c.id is null or c.estado not in ('pendente', 'aceito') or c.expira_em < now() then
    raise exception 'CONVITE_INVALIDO';
  end if;

  -- G-24: convite 'email' exige e-mail não nulo e igual ao do autenticado;
  -- convite 'link' (email is null) segue aceito por qualquer autenticado.
  if c.tipo = 'email' then
    select u.email into email_uid from auth.users u where u.id = auth.uid();
    if c.email is null or lower(c.email) <> lower(email_uid) then
      raise exception 'CONVITE_NAO_DIRIGIDO_A_VOCE';
    end if;
  end if;

  insert into public.lista_membros (lista_id, user_id, papel)
  values (c.lista_id, auth.uid(), c.papel_oferecido)
  on conflict (lista_id, user_id) do nothing;

  update public.convites set estado = 'aceito', atualizado_em = now()
  where id = c.id;

  return c.lista_id;
end;
$$;

revoke execute on function public.aceitar_convite(uuid) from public, anon;
grant execute on function public.aceitar_convite(uuid) to authenticated;

-- ============================================================================
-- G-24 — CHECK tipo ↔ email (aditivo; `not valid` + `validate`)
-- ============================================================================
alter table public.convites
  add constraint convites_tipo_email_check
  check (
    (tipo = 'link' and email is null)
    or (tipo = 'email' and email is not null)
  ) not valid;

alter table public.convites validate constraint convites_tipo_email_check;
