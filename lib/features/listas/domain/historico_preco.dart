import '../../../drift/database.dart';

/// Último preço pago por item (histórico local, RF-29).
class HistoricoPreco {
  const HistoricoPreco({
    required this.nomeNormalizado,
    required this.precoCentavos,
    required this.unidade,
    required this.registradoEm,
  });

  final String nomeNormalizado;
  final int precoCentavos;
  final String unidade;
  final DateTime registradoEm;

  factory HistoricoPreco.fromLocal(HistoricoPrecoLocalData d) => HistoricoPreco(
    nomeNormalizado: d.nomeNormalizado,
    precoCentavos: d.precoCentavos,
    unidade: d.unidade,
    registradoEm: d.registradoEm,
  );
}
