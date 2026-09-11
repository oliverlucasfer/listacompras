-- 0011_dono_repair.sql — reparo idempotente da associação do dono
-- Docs donos: 01 §6, 02 §1/§4.3.
--
-- Contexto: após a 0010, listas cujo INSERT em `listas` ocorreu por um caminho
-- que não disparou o trigger (ex.: upsert que virou UPDATE, ou lista criada
-- antes da 0010) podem ter ficado sem a linha do dono em `lista_membros`.
-- Sem ela, `is_member` é falso (membros vazios) e `papel_na_lista` é null
-- (papel volta a 'leitor' após reiniciar). Este reparo recria o trigger de
-- forma defensiva e reexecuta o backfill (idempotente).

create or replace function public.criar_membro_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.lista_membros (lista_id, user_id, papel)
  values (new.id, new.dono_id, 'dono')
  on conflict (lista_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_listas_cria_dono on public.listas;

create trigger trg_listas_cria_dono
  after insert on public.listas
  for each row execute function public.criar_membro_dono();

-- Backfill idempotente: toda lista sem nenhum `papel = 'dono'` ganha a linha
-- do dono. A condição usa ausência de QUALQUER dono (não de um user_id) para
-- nunca criar um 2º dono, o que o trigger `sync_dono` recusaria.
insert into public.lista_membros (lista_id, user_id, papel)
select l.id, l.dono_id, 'dono'
from public.listas l
where not exists (
  select 1
  from public.lista_membros lm
  where lm.lista_id = l.id
    and lm.papel = 'dono'
);
