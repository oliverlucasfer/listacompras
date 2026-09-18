/// Sugestão de item frequente (RF-19): nome de exibição + peso do ranking
/// derivado do histórico local (lista aberta pesa 2, demais listas pesam 1).
class SugestaoItem {
  const SugestaoItem({required this.nome, required this.peso});

  final String nome;
  final int peso;
}
