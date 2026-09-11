import '../../features/listas/domain/categoria.dart';
import '../../features/listas/domain/unidade.dart';

/// Limite do modo local (sem IA) — spec RF-16.
const int maxCaracteresImportLocal = 10000;

/// Item importado (local ou IA): quantidade > 0, unidade e categoria nos
/// enums fechados ([01 §3](docs/01-banco-de-dados.md), ADR-005/ADR-011).
class ItemExtraido {
  const ItemExtraido({
    required this.nome,
    required this.quantidade,
    required this.unidade,
    this.categoria = CategoriaItem.outros,
  });

  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
}

/// Resultado da extração: itens + aviso opcional (ex.: quantidade padrão).
class RespostaParse {
  const RespostaParse({required this.itens, required this.aviso});

  final List<ItemExtraido> itens;
  final String? aviso;
}
