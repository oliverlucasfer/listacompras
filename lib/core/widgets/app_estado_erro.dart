import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/tokens/app_spacing.dart';

/// Erro de carga com retry (doc 15 §3).
class AppEstadoErro extends StatelessWidget {
  const AppEstadoErro({super.key, required this.mensagem, this.onRetentar});

  final String mensagem;
  final VoidCallback? onRetentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(mensagem, textAlign: TextAlign.center),
            if (onRetentar != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onRetentar,
                child: const Text(AppStrings.tentarNovamente),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
