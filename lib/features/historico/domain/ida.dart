import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';

class Ida {
  const Ida({
    required this.id,
    required this.listaId,
    required this.titulo,
    required this.finalizadaEm,
    required this.totalCentavos,
    required this.itensCount,
    this.mercado,
  });
  final String id;
  final String? listaId;
  final String titulo;
  final DateTime finalizadaEm;
  final int totalCentavos;
  final int itensCount;
  final String? mercado;
}

class ItemDaIda {
  const ItemDaIda({
    required this.id,
    required this.idaId,
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    required this.precoCentavos,
  });
  final String id;
  final String idaId;
  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
  final int? precoCentavos;
}

class ResumoHistorico {
  const ResumoHistorico({
    required this.totalGeralCentavos,
    required this.ticketMedioCentavos,
    required this.nIdas,
  });
  final int totalGeralCentavos;
  final int ticketMedioCentavos;
  final int nIdas;
}
