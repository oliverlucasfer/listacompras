-- 0018_arquivar_listas.sql — arquivar/desarquivar listas (doc 01 §4.1, RF-22, F26).
-- Estado global da lista; só o dono muda `arquivada_em` (a policy de UPDATE
-- permite dono/editor, então um trigger faz a defesa em profundidade).

alter table public.listas add column arquivada_em timestamptz;

create index idx_listas_dono_ativas
  on public.listas (dono_id)
  where deletado_em is null and arquivada_em is null;

create or replace function public.protege_arquivo_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.arquivada_em is distinct from old.arquivada_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_ARQUIVAR';
  end if;
  return new;
end;
$$;

create trigger trg_listas_arquivo_dono
  before update on public.listas
  for each row execute function public.protege_arquivo_dono();
