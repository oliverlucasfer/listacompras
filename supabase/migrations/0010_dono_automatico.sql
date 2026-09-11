-- 0010_dono_automatico.sql — garante a associação do dono em lista_membros
-- Docs donos: 01 §6, 02 §1/§4.3.
--
-- Contexto (bug): a criação de lista só inseria em `listas` (cliente) e confiava
-- que a linha do dono em `lista_membros` fosse criada em algum lugar — mas ela
-- nunca era criada. Resultado: `papel_na_lista()` retornava null (UI tratava o
-- dono como leitor) e o RLS negava INSERT/UPDATE de itens para o próprio dono.
-- O servidor passa a manter o invariante: toda lista nasce com seu dono membro.

-- 01 §6 — associação automática do dono
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

create trigger trg_listas_cria_dono
  after insert on public.listas
  for each row execute function public.criar_membro_dono();

-- Backfill — conserta as listas existentes sem nenhum dono membro. A condição
-- usa ausência de qualquer `papel = 'dono'` (e não de um user_id específico)
-- para nunca criar um 2º dono, o que o trigger `sync_dono` recusaria.
insert into public.lista_membros (lista_id, user_id, papel)
select l.id, l.dono_id, 'dono'
from public.listas l
where not exists (
  select 1
  from public.lista_membros lm
  where lm.lista_id = l.id
    and lm.papel = 'dono'
);
