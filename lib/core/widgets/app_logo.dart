import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/identidade_visual.dart';
import '../theme/tokens/app_radius.dart';

/// Marca do app (doc 15 §6): a imagem vem da identidade visual vigente
/// (colaborativa = carrinho verde; Lite = cesta índigo). É **decorativa**
/// (doc 15 §4): o título ao lado já anuncia a tela (`ExcludeSemantics`).
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.tamanho = 28});

  final double tamanho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(identidadeVisualProvider).logoAsset;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.smTodos,
        child: Image.asset(
          asset,
          width: tamanho,
          height: tamanho,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
