import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';

class Ida {
  const Ida({
    required this.id,
    required this.listaId,
    required this.titulo,
    required this.finalizadaEm,
    required this.totalCentavos,
    required this.itensCount,
  });
  final String id;
  final String? listaId;
  final String titulo;
  final DateTime finalizadaEm;
  final int totalCentavos;
  final int itensCount;

  factory Ida.fromLocal(IdaCompraData d) => Ida(
    id: d.id,
    listaId: d.listaId,
    titulo: d.titulo,
    finalizadaEm: d.finalizadaEm,
    totalCentavos: d.totalCentavos,
    itensCount: d.itensCount,
  );
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

  factory ItemDaIda.fromLocal(ItemIdaData d) => ItemDaIda(
    id: d.id,
    idaId: d.idaId,
    nome: d.nome,
    quantidade: d.quantidade,
    unidade: Unidade.fromValor(d.unidade),
    categoria: CategoriaItem.fromValor(d.categoria),
    precoCentavos: d.precoCentavos,
  );
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
