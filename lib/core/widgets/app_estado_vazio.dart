import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Estado vazio padronizado (doc 15 §3).
class AppEstadoVazio extends StatelessWidget {
  const AppEstadoVazio({
    super.key,
    required this.titulo,
    this.descricao,
    this.icone = Icons.inbox_outlined,
    this.acao,
  });

  final String titulo;
  final String? descricao;
  final IconData icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 72, color: scheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (descricao != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                descricao!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (acao != null) ...[const SizedBox(height: AppSpacing.xl), acao!],
          ],
        ),
      ),
    );
  }
}
