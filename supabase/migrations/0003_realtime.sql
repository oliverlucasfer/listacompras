-- 0003_realtime.sql — publication do Realtime (doc 01 §7)
-- lista_membros fora do publication por enquanto (raramente muda; reavaliar Fase 6).
-- O Realtime respeita as policies RLS de 0002 — usuários só recebem eventos
-- de listas de que participam.

alter publication supabase_realtime add table public.listas;
alter publication supabase_realtime add table public.itens_lista;
