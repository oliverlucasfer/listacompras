-- 0009_rls_membros_papeis.sql — policies de UPDATE (troca de papel) e
-- DELETE da própria linha em `lista_membros` (doc 02 §4.3, F7-T07, RF-13).
-- Na 0002 UPDATE era "não permitido no MVP": `mudarPapel` e `sairDaLista`
-- chegavam ao banco como no-ops silenciosos (0 linhas) sem estas policies.
-- O trigger `sync_dono` (0001/0005) permanece intacto — ele é quem bloqueia
-- qualquer mudança na linha do dono e a remoção/downgrade do dono.

-- Dono troca o papel de outro membro (editor <-> leitor, doc 08 §5).
-- USING rejeita linhas de outros usuários (inclusive a própria — o dono
-- nunca se rebaixa por aqui); WITH CHECK rejeita papel fora do enum
-- funcional e qualquer promoção a 'dono' (transferência é processo
-- explícito, 08 §6).
create policy "membros_update_papel_dono"
  on public.lista_membros for update
  using (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
  )
  with check (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
    and papel in ('editor', 'leitor')
  );

-- Membro comum sai da lista removendo a própria linha (doc 08 §5); o dono
-- não sai (transferência de dono é Fase 6) — além desta policy, o trigger
-- sync_dono bloqueia o DELETE da linha do dono.
create policy "membros_delete_proprio"
  on public.lista_membros for delete
  using (
    user_id = auth.uid()
    and not public.is_dono_de(lista_id)
  );
