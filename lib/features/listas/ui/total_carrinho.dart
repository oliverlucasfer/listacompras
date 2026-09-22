import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../domain/item.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Faixa do total dos itens marcados com preço (RF-21, F25). Quando a lista
/// tem orçamento (RF-28, F36), mostra o progresso contra ele e alerta ao
/// ultrapassar. Oculta quando não há nenhum item marcado.
class TotalCarrinho extends ConsumerWidget {
  const TotalCarrinho({super.key, required this.listaId});

  final String listaId;

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.xs,
    AppSpacing.lg,
    AppSpacing.xs,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens =
        ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
    final marcados = itens.where((i) => i.concluido).toList();
    if (marcados.isEmpty) return const SizedBox.shrink();
    final semPreco = marcados.where((i) => i.precoCentavos == null).length;
    final total = totalCarrinho(itens);
    final orcamento = ref
        .watch(listaPorIdProvider(listaId))
        .value
        ?.orcamentoCentavos;
    final textoEstilo = Theme.of(context).textTheme.titleMedium;

    if (orcamento == null) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: _padding,
          child: Text(
            AppStrings.totalNoCarrinho(formatarReais(total), semPreco),
            style: textoEstilo,
          ),
        ),
      );
    }

    final cor = Theme.of(context).colorScheme.error;
    final acima = total > orcamento;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: _padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (acima) ...[
                  Icon(Icons.warning_amber_rounded, color: cor, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    AppStrings.totalComOrcamento(
                      formatarReais(total),
                      formatarReais(orcamento),
                      semPreco,
                    ),
                    style: acima
                        ? textoEstilo?.copyWith(color: cor)
                        : textoEstilo,
                  ),
                ),
              ],
            ),
            if (orcamento > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (total / orcamento).clamp(0.0, 1.0).toDouble(),
                color: acima ? cor : null,
              ),
            ],
            if (acima) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.acimaDoOrcamento,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
