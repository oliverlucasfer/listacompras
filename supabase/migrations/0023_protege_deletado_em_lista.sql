-- 0023_protege_deletado_em_lista.sql — editor não soft-deleta/ressuscita a lista
-- Docs donos: 02 §3/§4.1, 01 §6. Requisito: RF-13 / G-03 (F43-T06).
--
-- A policy de UPDATE de `listas` (0012) libera dono/editor e só congela
-- `dono_id`; `deletado_em` (soft delete / tombstone, 01 §4.1) ficava aberto a
-- um editor. Correção em profundidade: recria a policy exigindo que apenas o
-- dono mude `deletado_em` + trigger BEFORE UPDATE como segunda barreira,
-- espelhando `protege_arquivo_dono` (0018).

drop policy "listas_update_editores" on public.listas;

create policy "listas_update_editores"
  on public.listas for update
  using (public.papel_na_lista(id) in ('dono', 'editor'))
  with check (
    public.papel_na_lista(id) in ('dono', 'editor')
    -- dono_id é imutável via UPDATE (transferência é processo explícito, 08 §6);
    -- a subquery lê a snapshot antiga da própria linha.
    and dono_id = (
      select l.dono_id from public.listas l where l.id = listas.id
    )
    -- Só o dono muda `deletado_em`; editor/leitor não. A subquery lê a snapshot
    -- antiga, então qualquer mudança por não-dono falha o WITH CHECK.
    and (
      public.papel_na_lista(id) = 'dono'
      or deletado_em is not distinct from (
        select l.deletado_em from public.listas l where l.id = listas.id
      )
    )
  );

create or replace function public.protege_deletado_em()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- `old.dono_id <> auth.uid()` trata NULL de auth.uid() (service_role ou
  -- contexto definer) como "allow" de propósito; não transforme em bloqueio.
  if new.deletado_em is distinct from old.deletado_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_EXCLUIR';
  end if;
  return new;
end;
$$;

create trigger trg_listas_deletado_em_dono
  before update on public.listas
  for each row execute function public.protege_deletado_em();
