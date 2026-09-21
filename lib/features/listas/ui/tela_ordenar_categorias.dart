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
        title: const Text(AppStrings.ordenarCategorias),
        actions: [
          TextButton(
            onPressed: () => _confirmarRestaurar(context, ref),
            child: const Text(AppStrings.restaurarPadrao),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(AppStrings.ordenarCategoriasDica),
          ),
          Expanded(
            child: ReorderableListView(
              children: [
                for (final c in ordem)
                  ListTile(
                    key: ValueKey(c.valor),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(c.rotulo),
                  ),
              ],
              // `onReorderItem` já entrega o índice final (ajustado); o
              // `moverItem` espera o índice do `onReorder` (pré-remoção).
              onReorderItem: (oldIndex, newIndex) {
                ref
                    .read(ordemCategoriasProvider.notifier)
                    .definir(
                      moverItem(
                        ordem,
                        oldIndex,
                        newIndex >= oldIndex ? newIndex + 1 : newIndex,
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
    if (confirmou) {
      await ref.read(ordemCategoriasProvider.notifier).restaurarPadrao();
    }
  }
}
