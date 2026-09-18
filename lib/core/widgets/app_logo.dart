import 'package:flutter/material.dart';

import '../theme/tokens/app_radius.dart';

/// Marca do app (doc 15 §6): carrinho de compras, recortado em tile arredondado.
///
/// Usada no cabeçalho das telas de topo. O bitmap vem do master vetorial
/// `assets/branding/logo.svg` (1024px) — nítido em qualquer tamanho exibido.
/// É **decorativa** (doc 15 §4): o título ao lado já anuncia a tela, então a
/// imagem não entra na árvore semântica (`ExcludeSemantics`).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.tamanho = 28});

  final double tamanho;

  static const _asset = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.smTodos,
        child: Image.asset(
          _asset,
          width: tamanho,
          height: tamanho,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
