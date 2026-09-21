-- 0017_preco_item.sql — preço unitário do item (doc 01 §4.3, RF-21, F25).
-- Centavos inteiros (sem float); NULL = sem preço; 0 é válido; negativo rejeitado.
alter table public.itens_lista
  add column preco_centavos integer
  check (preco_centavos is null or (preco_centavos >= 0 and preco_centavos <= 99999999));
