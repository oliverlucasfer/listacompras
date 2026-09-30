import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
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

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.finalizarConfirmarTitulo),
      content: Text(
        AppStrings.finalizarResumo(
          marcados.length,
          formatarReais(total),
          semPreco,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.cancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(AppStrings.finalizarCompra),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  await ref.read(historicoComprasRepositoryProvider).finalizar(listaId);
  if (!context.mounted) return;
  mostrarSnackBar(context, AppStrings.compraRegistrada);

  final limpar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.compraRegistrada),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.finalizarManter),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(AppStrings.finalizarLimpar),
        ),
      ],
    ),
  );
  if (limpar == true) {
    await ref.read(listasRepositoryProvider).limparConcluidos(listaId);
  }
}
