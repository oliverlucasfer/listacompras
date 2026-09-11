import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Cabeçalho de seção com contagem opcional (doc 15 §3).
class AppCabecalhoSecao extends StatelessWidget {
  const AppCabecalhoSecao(this.titulo, {super.key, this.contagem});

  final String titulo;
  final int? contagem;

  @override
  Widget build(BuildContext context) {
    final texto = contagem == null ? titulo : '$titulo ($contagem)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
