import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/domain/preco.dart';
import '../../listas/providers/listas_providers.dart';
import '../providers/historico_providers.dart';

Future<void> abrirFinalizarCompra(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final itens = await ref.read(itensDaListaProvider(listaId).future);
  if (!context.mounted) return;
  final marcados = itens.where((i) => i.concluido).toList();
  if (marcados.isEmpty) return;
  final semPreco = marcados.where((i) => i.precoCentavos == null).length;
  final total = totalCarrinho(itens);

  final resultado = await showDialog<({bool confirmar, String? mercado})>(
    context: context,
    builder: (_) => _DialogoFinalizar(
      resumo: context.l10n.finalizarResumo(
        marcados.length,
        formatarReais(total),
        semPreco,
      ),
    ),
  );
  if (resultado == null || !resultado.confirmar || !context.mounted) return;

  try {
    await ref
        .read(historicoComprasRepositoryProvider)
        .finalizar(listaId, mercado: resultado.mercado);
  } catch (_) {
    if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
    return;
  }
  if (!context.mounted) return;
  mostrarSnackBar(context, context.l10n.compraRegistrada);

  final limpar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.compraRegistrada),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.finalizarManter),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.finalizarLimpar),
        ),
      ],
    ),
  );
  if (limpar == true) {
    try {
      await ref.read(itensRepositoryProvider).limparConcluidos(listaId);
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, context.l10n.erroGenerico);
      }
    }
  }
}

/// Diálogo de confirmação do finalizar (RF-34/RF-35): o resumo atual + o
/// campo opcional de mercado, com chips dos mercados já usados (RF-35, F52).
class _DialogoFinalizar extends ConsumerStatefulWidget {
  const _DialogoFinalizar({required this.resumo});

  final String resumo;

  @override
  ConsumerState<_DialogoFinalizar> createState() => _DialogoFinalizarState();
}

class _DialogoFinalizarState extends ConsumerState<_DialogoFinalizar> {
  final _mercado = TextEditingController();

  @override
  void dispose() {
    _mercado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes =
        ref.watch(mercadosUsadosProvider).value ?? const <String>[];
    return AlertDialog(
      title: Text(context.l10n.finalizarConfirmarTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.resumo),
            const SizedBox(height: AppSpacing.md),
            AppCampoTexto(
              controller: _mercado,
              label: context.l10n.mercadoOpcional,
            ),
            if (sugestoes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: context.l10n.mercadosSugeridos,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final mercado in sugestoes)
                      ActionChip(
                        label: Text(mercado),
                        onPressed: () =>
                            setState(() => _mercado.text = mercado),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (confirmar: false, mercado: null)),
          child: Text(context.l10n.cancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            confirmar: true,
            mercado: _mercado.text.trim(),
          )),
          child: Text(context.l10n.finalizarCompra),
        ),
      ],
    );
  }
}
