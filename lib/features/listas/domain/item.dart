import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';

/// Modelo de domínio de item (doc 05 §2); `unidade` restrita ao enum
/// fechado (doc 13 §3) e `categoria` ao enum fechado (doc 13 §3,
/// ADR-011).
class Item {
  const Item({
    required this.id,
    required this.listaId,
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    required this.concluido,
    required this.ordem,
    required this.criadoEm,
    required this.atualizadoEm,
    this.precoCentavos,
  });

  final String id;
  final String listaId;
  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
  final bool concluido;
  final int ordem;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final int? precoCentavos;
}
