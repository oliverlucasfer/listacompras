-- 0016_transferir_dono.sql — transferência de dono (doc 08 §6, RF-14, Fase 6).
-- Reaproveita o padrão da exclusão de conta (0005): o RPC security definer
-- marca a transação e o trigger sync_dono reconhece a marca. listas.dono_id
-- continua sendo ajustado SOMENTE pelo trigger (fonte única).

create or replace function public.transferir_dono(p_lista uuid, p_novo_dono uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  papel_novo text;
begin
  if auth.uid() is null then
    raise exception 'AUTENTICACAO_NECESSARIA';
  end if;

  if not exists (
    select 1 from public.listas
    where id = p_lista and dono_id = auth.uid()
  ) then
    raise exception 'APENAS_O_DONO_PODE_TRANSFERIR';
  end if;

  if p_novo_dono = auth.uid() then
    raise exception 'NAO_PODE_TRANSFERIR_PARA_SI';
  end if;

  select papel into papel_novo
  from public.lista_membros
  where lista_id = p_lista and user_id = p_novo_dono;
  if papel_novo is null then
    raise exception 'NOVO_DONO_PRECISA_SER_MEMBRO';
  end if;

  perform set_config('app.transferindo_dono', 'true', true);

  -- Ordem importa: demove o antigo ANTES de promover o novo.
  update public.lista_membros set papel = 'editor'
  where lista_id = p_lista and user_id = auth.uid();

  update public.lista_membros set papel = 'dono'
  where lista_id = p_lista and user_id = p_novo_dono;
end;
$$;

revoke execute on function public.transferir_dono(uuid, uuid) from public, anon;
grant execute on function public.transferir_dono(uuid, uuid) to authenticated;

-- sync_dono v3 (doc 01 §6): mesma regra + exceção para a transferência.
create or replace function public.sync_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  qtd_donos int;
begin
  select count(*) into qtd_donos
  from public.lista_membros
  where lista_id = coalesce(new.lista_id, old.lista_id)
    and papel = 'dono';

  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if qtd_donos > 1 then
      raise exception 'Lista já possui um dono';
    end if;

    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    if coalesce(current_setting('app.excluindo_conta', true), '') <> 'true'
       and coalesce(current_setting('app.transferindo_dono', true), '') <> 'true' then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

-- R-17: convites.criado_por ganha cascade (a transferência torna o risco real).
alter table public.convites drop constraint convites_criado_por_fkey;
alter table public.convites
  add constraint convites_criado_por_fkey
  foreign key (criado_por) references auth.users(id) on delete cascade;
