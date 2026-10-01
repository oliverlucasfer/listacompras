class PrecoMercado {
  const PrecoMercado({
    required this.mercado,
    required this.precoCentavos,
    required this.data,
  });
  final String mercado;
  final int precoCentavos;
  final DateTime data;
}

class GastoPorMercado {
  const GastoPorMercado({required this.mercado, required this.totalCentavos});
  final String? mercado;
  final int totalCentavos;
}
