/// Último preço pago por item (histórico local, RF-29).
class HistoricoPreco {
  const HistoricoPreco({
    required this.precoCentavos,
    required this.unidade,
    required this.registradoEm,
  });

  final int precoCentavos;
  final String unidade;
  final DateTime registradoEm;
}
