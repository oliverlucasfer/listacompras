import '../../../core/dominio/categoria.dart';
import 'item.dart';

enum EstadoOrcamento { semOrcamento, normal, aviso, acima }

/// Fração do orçamento a partir da qual o estado vira "aviso" (RF-36).
const double limiarAvisoOrcamento = 0.8;

EstadoOrcamento estadoOrcamento(int total, int? orcamento) {
  if (orcamento == null) return EstadoOrcamento.semOrcamento;
  if (total > orcamento) return EstadoOrcamento.acima;
  if (orcamento > 0 && total >= (orcamento * limiarAvisoOrcamento).ceil()) {
    return EstadoOrcamento.aviso;
  }
  return EstadoOrcamento.normal;
}

/// Verdadeiro quando o total passa de ≤ orçamento para > orçamento.
bool cruzouLimite({
  required int antes,
  required int depois,
  required int? orcamento,
}) {
  if (orcamento == null) return false;
  return antes <= orcamento && depois > orcamento;
}

/// Subtotal de um item para um preço dado (0 se sem preço).
int subtotalComPreco(Item item, int? precoCentavos) {
  return precoCentavos == null ? 0 : (item.quantidade * precoCentavos).round();
}

/// Subtotal de um item marcado com preço (0 se sem preço).
int subtotalMarcado(Item item) => subtotalComPreco(item, item.precoCentavos);

/// Categorias cujo subtotal marcado excede o limite definido (RF-36, F53-T04).
/// Categorias sem limite em [limites] são ignoradas; categoria com limite e
/// sem subtotal conta como 0.
Set<CategoriaItem> categoriasAcimaDoLimite({
  required Map<CategoriaItem, int> subtotais,
  required Map<CategoriaItem, int> limites,
}) {
  final acima = <CategoriaItem>{};
  for (final entrada in limites.entries) {
    final subtotal = subtotais[entrada.key] ?? 0;
    if (subtotal > entrada.value) acima.add(entrada.key);
  }
  return acima;
}
