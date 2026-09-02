-- 0001_init.sql — enum de unidades, tabelas, índices e triggers
-- Docs donos: docs/01-banco-de-dados.md (§3–§6), docs/02-seguranca-rls.md (§1–§4)

-- ============================================================================
-- Enum de unidades (01 §3) — fonte única da verdade (ADR-005, enum fechado)
-- Replicado no Dart (05) e no responseSchema do Gemini (04). NUNCA alterar
-- sem atualizar os três.
-- ============================================================================
create type public.unidade_item as enum (
  'un', 'kg', 'g', 'l', 'ml', 'caixa', 'pacote', 'pct', 'dz'
);
