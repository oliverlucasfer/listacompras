import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../domain/item.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Faixa do total dos itens marcados com preço (RF-21, F25). Oculta quando
/// não há nenhum item marcado.
class TotalCarrinho extends ConsumerWidget {
  const TotalCarrinho({super.key, required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens =
        ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
    final marcados = itens.where((i) => i.concluido).toList();
    if (marcados.isEmpty) return const SizedBox.shrink();
    final semPreco = marcados.where((i) => i.precoCentavos == null).length;
    final texto = StringBuffer()
      ..write(AppStrings.noCarrinho)
      ..write(': ')
      ..write(formatarReais(totalCarrinho(itens)));
    if (semPreco > 0) {
      texto
        ..write(' · ')
        ..write(AppStrings.semPreco(semPreco));
    }
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          texto.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
