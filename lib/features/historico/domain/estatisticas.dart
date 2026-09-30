import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';

class GastoPorMes {
  const GastoPorMes({required this.mes, required this.totalCentavos});
  final DateTime mes; // primeiro dia do mês (UTC)
  final int totalCentavos;
}

class GastoPorCategoria {
  const GastoPorCategoria({
    required this.categoria,
    required this.totalCentavos,
  });
  final CategoriaItem categoria;
  final int totalCentavos;
}

class ItemFrequente {
  const ItemFrequente({
    required this.nome,
    required this.vezes,
    required this.totalCentavos,
  });
  final String nome;
  final int vezes;
  final int totalCentavos;
}

class PontoPreco {
  const PontoPreco({
    required this.data,
    required this.precoCentavos,
    required this.unidade,
  });
  final DateTime data;
  final int precoCentavos;
  final Unidade unidade;
}
