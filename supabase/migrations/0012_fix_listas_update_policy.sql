-- 0012_fix_listas_update_policy.sql — corrige o WITH CHECK de listas_update_editores
-- Docs donos: 02 §4.1, 01 §4.1.
--
-- Bug: o subselect usava `where l.id = id`; `id` não qualificado resolve para
-- o `l.id` do próprio subselect, tornando a condição sempre verdadeira. Com 0
-- linhas o subselect retorna NULL (nega o UPDATE) e com >1 linha retorna mais
-- de uma linha (erro). Como o upsert do PostgREST avalia a policy de UPDATE,
-- o INSERT de uma lista nova via sync era negado (42501) e nada sincronizava.
-- Correção: referenciar explicitamente a linha externa (`listas.id`).

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
  );
