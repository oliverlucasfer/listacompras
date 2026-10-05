part of 'tela_lista_screen.dart';

/// Aviso de categorias que estouraram o limite (RF-36, F53-T04), abaixo do
/// `TotalCarrinho`. Considera só itens marcados com preço; oculto quando não
/// há limite definido nem categoria estourada.
class _AlertaOrcamentoCategorias extends ConsumerWidget {
  const _AlertaOrcamentoCategorias({required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limites =
        ref.watch(limitesCategoriaProvider).value ??
        const <CategoriaItem, int>{};
    if (limites.isEmpty) return const SizedBox.shrink();
    final subtotais = ref.watch(subtotaisPorCategoriaProvider(listaId));
    final acima = categoriasAcimaDoLimite(
      subtotais: subtotais,
      limites: limites,
    );
    if (acima.isEmpty) return const SizedBox.shrink();
    final nomes = CategoriaItem.values
        .where(acima.contains)
        .map((c) => c.rotulo(context))
        .join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: AppBanner(
        tipo: AppBannerTipo.aviso,
        mensagem: '${context.l10n.acimaDoLimiteDaCategoria}: $nomes',
      ),
    );
  }
}
