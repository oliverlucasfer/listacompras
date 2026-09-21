import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/categoria.dart';
import '../domain/ordem_categorias.dart';
import '../providers/ordem_categorias_provider.dart';

/// Tela "Ordenar categorias" (RF-24): arrastar-e-soltar a ordem dos grupos.
class TelaOrdenarCategorias extends ConsumerWidget {
  const TelaOrdenarCategorias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordem =
        ref.watch(ordemCategoriasProvider).value ?? CategoriaItem.values;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.ordenarCategorias,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(AppStrings.ordenarCategoriasDica),
          ),
          // Fora da AppBar: título + ação não cabem na mesma linha em escala
          // de texto 2.0 (a Row de actions transbordava).
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextButton(
                onPressed: () => _confirmarRestaurar(context, ref),
                child: const Text(AppStrings.restaurarPadrao),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              children: [
                for (var i = 0; i < ordem.length; i++)
                  ListTile(
                    key: ValueKey(ordem[i].valor),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(ordem[i].rotulo),
                  ),
              ],
              onReorderItem: (oldIndex, newIndex) {
                ref
                    .read(ordemCategoriasProvider.notifier)
                    .definir(
                      moverItem(
                        ordem,
                        oldIndex,
                        indiceCruDeReordenacao(oldIndex, newIndex),
                      ),
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarRestaurar(BuildContext context, WidgetRef ref) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.restaurarPadraoTitulo,
      mensagem: AppStrings.restaurarPadraoMensagem,
      confirmar: AppStrings.restaurarPadrao,
    );
    if (confirmou && context.mounted) {
      await ref.read(ordemCategoriasProvider.notifier).restaurarPadrao();
    }
  }
}
