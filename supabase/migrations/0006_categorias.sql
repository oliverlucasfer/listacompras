-- 0006_categorias.sql — enum de categorias + coluna em itens_lista (F6-T01)
-- Docs donos: docs/01-banco-de-dados.md (§3, §4.3), docs/14-tarefas.md (F6-T01)
-- Spec: docs/superpowers/specs/2026-09-08-agrupamento-categorias-design.md (§3)
-- Fonte única da verdade (ADR-011, enum fechado): replicado no Dart
-- (lib/features/listas/domain/categoria.dart) e no responseSchema do Gemini
-- (docs/04). NUNCA alterar sem atualizar os três. A ordem do enum define a
-- ordem dos grupos na UI.

create type public.categoria_item as enum (
  'hortifruti', 'mercearia', 'frios', 'laticinios', 'congelados',
  'padaria', 'bebidas', 'pet', 'limpeza', 'higiene', 'outros'
);

-- Migration aditiva (spec §7): itens existentes passam a 'outros';
-- INSERT do app antigo (1.0.0+2) sem a coluna também recebe o default —
-- e o upsert LWW do sync não sobrescreve categoria fora do payload.
alter table public.itens_lista
  add column categoria public.categoria_item not null default 'outros';
