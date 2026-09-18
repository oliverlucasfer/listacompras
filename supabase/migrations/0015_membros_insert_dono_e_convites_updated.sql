-- 0015_membros_insert_dono_e_convites_updated.sql — defesa em profundidade e
-- higiene (achados R-18 e R-19 da revisão geral, F20-T11).
-- Docs donos: 02 §4.3, 01 §4.4.
--
-- R-18: a policy `membros_insert_dono` aceitava `papel='dono'` para qualquer
-- `user_id` (o comentário no 0002 dizia o contrário). O invariante "1 dono"
-- ficava só com o trigger `sync_dono`. Aqui a policy passa a exigir que
-- 'dono' só possa ser concedido ao próprio usuário autenticado.
--
-- R-19: `convites.atualizado_em` só tinha `default now()` — um UPDATE de
-- revogação não atualizava o carimbo. Padroniza com `listas`/`itens_lista`,
-- que usam `touch_updated_at` (0001).

-- ============================================================================
-- 02 §4.3 — INSERT: 'dono' apenas para si mesmo
-- ============================================================================
drop policy if exists "membros_insert_dono" on public.lista_membros;

create policy "membros_insert_dono"
  on public.lista_membros for insert
  with check (
    public.is_dono_de(lista_id)
    -- 'dono' é o próprio usuário autenticado; terceiros só como editor/leitor
    and (papel in ('editor', 'leitor') or user_id = auth.uid())
  );

-- ============================================================================
-- 01 §4.4 — `convites.atualizado_em` com trigger de updated_at
-- ============================================================================
create or replace function public.touch_convites_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

drop trigger if exists trg_convites_updated on public.convites;

create trigger trg_convites_updated
  before update on public.convites
  for each row execute function public.touch_convites_updated_at();
