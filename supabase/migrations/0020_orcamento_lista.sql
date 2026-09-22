-- 0020_orcamento_lista.sql — orçamento por lista (doc 01 §4.1, RF-28, F36).
-- Centavos inteiros (sem float); NULL = sem orçamento; 0 é válido; negativo
-- rejeitado. Sem policy nova: herda o UPDATE de `listas` (dono/editor).
alter table public.listas
  add column orcamento_centavos integer
  check (orcamento_centavos is null
         or (orcamento_centavos >= 0 and orcamento_centavos <= 99999999));
