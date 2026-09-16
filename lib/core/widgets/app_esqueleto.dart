import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens/app_radius.dart';
import '../theme/tokens/app_spacing.dart';

/// Placeholder estático de carregamento das listas (doc 15 §3, F14-T09):
/// blocos com a cor de superfície do tema, sem animação e sem pacote novo.
class AppEsqueleto extends StatelessWidget {
  const AppEsqueleto({super.key, this.linhas = 4, this.altura = 56});

  final int linhas;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: AppStrings.carregando,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            for (var i = 0; i < linhas; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                height: altura,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: AppRadius.mdTodos,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
