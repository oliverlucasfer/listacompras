import '../../../drift/database.dart';
import 'categoria.dart';
import 'unidade.dart';

/// Modelo de domínio de item (doc 05 §2); `unidade` restrita ao enum
/// fechado (doc 01 §3.1) e `categoria` ao enum fechado (doc 01 §3.2,
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
    this.deletadoEm,
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
  final DateTime? deletadoEm;

  factory Item.fromLocal(ItemLocalData d) => Item(
    id: d.id,
    listaId: d.listaId,
    nome: d.nome,
    quantidade: d.quantidade,
    unidade: Unidade.fromValor(d.unidade),
    categoria: CategoriaItem.fromValor(d.categoria),
    concluido: d.concluido,
    ordem: d.ordem,
    criadoEm: d.createdAt,
    atualizadoEm: d.updatedAt,
    deletadoEm: d.deletadoEm,
  );
}
