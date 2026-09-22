-- 0019_convites_email.sql — convite por e-mail: painel e recusa (doc 08 §4,
-- RF-13, F32). O RLS de `convites` fica intacto: o convidado não é membro e
-- não pode ler `listas` nem fazer UPDATE — o caminho são RPCs security definer.

create or replace function public.meus_convites_pendentes()
returns table (
  id uuid,
  token uuid,
  lista_titulo text,
  papel_oferecido text,
  expira_em timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select c.id, c.token, l.titulo, c.papel_oferecido, c.expira_em
  from public.convites c
  join public.listas l on l.id = c.lista_id
  where c.tipo = 'email'
    and c.estado = 'pendente'
    and c.expira_em >= now()
    and lower(c.email) = lower(public.email_autenticado())
  order by c.created_at desc
$$;

create or replace function public.recusar_convite(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.convites
  set estado = 'revogado', atualizado_em = now()
  where id = p_id
    and tipo = 'email'
    and estado = 'pendente'
    and expira_em >= now()
    and lower(email) = lower(public.email_autenticado());
  if not found then
    raise exception 'CONVITE_INVALIDO';
  end if;
end;
$$;

revoke execute on function public.meus_convites_pendentes() from public, anon;
revoke execute on function public.recusar_convite(uuid) from public, anon;
grant execute on function public.meus_convites_pendentes() to authenticated;
grant execute on function public.recusar_convite(uuid) to authenticated;
