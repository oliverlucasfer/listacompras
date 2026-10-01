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

/// Subtotal de um item marcado com preço (0 se sem preço).
int subtotalMarcado(Item item) {
  final preco = item.precoCentavos;
  return preco == null ? 0 : (item.quantidade * preco).round();
}
