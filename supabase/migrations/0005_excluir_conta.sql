-- 0005_excluir_conta.sql — Exclusão de conta (doc 06 §3.3.1, RF-11, ADR-008)
-- Delete físico: remove a linha do usuário em auth.users e as cascatas já
-- existentes (doc 01 §4) propagam — lista_membros (user_id), listas
-- (dono_id) e itens_lista (via lista). ia_rate_limit não tem FK → limpo
-- explicitamente (retenção até exclusão da conta, doc 06 §3.1/3.3).
-- SECURITY DEFINER: auth.users não é acessível ao role authenticated.
--
-- A cascata remove também a membership de dono das listas do titular, o que
-- o trigger sync_dono (doc 01 §6) bloquearia. O RPC marca a transação com
-- `app.excluindo_conta` e o sync_dono atualizado reconhece a marca —
-- exceção documentada no doc 01 §6.

create or replace function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'autenticacao necessaria';
  end if;

  perform set_config('app.excluindo_conta', 'true', true);

  delete from public.ia_rate_limit where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;

-- sync_dono v2 (doc 01 §6): mesmas regras + exceção para exclusão de conta.
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
    -- Impede mais de um dono
    if qtd_donos > 1 then
      raise exception 'Lista já possui um dono';
    end if;

    -- Atualiza a denormalização SOMENTE quando o registro é do dono
    -- (insert/update de editor/leitor não pode alterar dono_id).
    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  -- Impede remoção/downgrade do dono (transferência é processo explícito, Fase 6).
  -- Usa old.papel (snapshot do trigger) — consultar a tabela num trigger AFTER
  -- veria a linha já alterada/apagada e nunca bloquearia.
  -- EXCEÇÃO (doc 06 §3.3.1): exclusão de conta remove o dono em cascata —
  -- o RPC excluir_conta marca a transação com app.excluindo_conta.
  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    if coalesce(current_setting('app.excluindo_conta', true), '') <> 'true' then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;
