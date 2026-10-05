import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../domain/orcamento.dart';
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
    final resumo = ref.watch(resumoCarrinhoProvider(listaId));
    if (resumo.marcados == 0) return const SizedBox.shrink();
    final semPreco = resumo.semPreco;
    final total = ref.watch(totalCarrinhoProvider(listaId));
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
            context.l10n.totalNoCarrinho(formatarReais(total), semPreco),
            style: textoEstilo,
          ),
        ),
      );
    }

    final estado = estadoOrcamento(total, orcamento);
    final esquema = Theme.of(context).colorScheme;
    final cor = switch (estado) {
      EstadoOrcamento.aviso => esquema.tertiary,
      EstadoOrcamento.acima => esquema.error,
      EstadoOrcamento.semOrcamento || EstadoOrcamento.normal => null,
    };
    final icone = switch (estado) {
      EstadoOrcamento.aviso => Icons.notification_important_outlined,
      EstadoOrcamento.acima => Icons.warning_amber_rounded,
      EstadoOrcamento.semOrcamento || EstadoOrcamento.normal => null,
    };
    final aviso = switch (estado) {
      EstadoOrcamento.aviso => context.l10n.orcamentoAtencao,
      EstadoOrcamento.acima => context.l10n.acimaDoOrcamento,
      EstadoOrcamento.semOrcamento || EstadoOrcamento.normal => null,
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: _padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icone != null) ...[
                  Icon(icone, color: cor, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    context.l10n.totalComOrcamento(
                      formatarReais(total),
                      formatarReais(orcamento),
                      semPreco,
                    ),
                    style: cor == null
                        ? textoEstilo
                        : textoEstilo?.copyWith(color: cor),
                  ),
                ),
              ],
            ),
            if (orcamento > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (total / orcamento).clamp(0.0, 1.0).toDouble(),
                color: cor,
              ),
            ],
            if (aviso != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                aviso,
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
