-- 0026_add_unidade_pt.sql — nova unidade `pt` (pote) no enum fechado
-- Docs donos: 01 §3.1. Requisito: RF-03 / F45-T01.
--
-- Aditivo: acrescenta o valor 'pt' ao enum `unidade_item` (ADR-005), replicado
-- em `lib/core/dominio/unidade.dart` e no parser local (04 §2). `ADD VALUE`
-- não permite usar o novo valor na mesma transação — aqui só se adiciona.

alter type public.unidade_item add value if not exists 'pt' after 'pct';
