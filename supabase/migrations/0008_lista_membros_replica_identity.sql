-- 0008_lista_membros_replica_identity.sql — doc 08 §7 (F7-T06):
-- postgres_changes entrega no `old_record` de um DELETE apenas as colunas
-- de replica identity (PK por padrão). Com REPLICA IDENTITY FULL o evento
-- DELETE de lista_membros traz `user_id`, permitindo ao app detectar a
-- perda de acesso e limpar o cache local (< 5s, doc 08 §9).
alter table public.lista_membros replica identity full;
