import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_logo.dart';
import '../providers/onboarding_provider.dart';

/// Tela de boas-vindas (RF-27), mostrada uma vez na primeira vez no app.
class BoasVindasScreen extends ConsumerWidget {
  const BoasVindasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.tela,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo()),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.boasVindasTitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.boasVindasSubtitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _Destaque(
                    icone: Icons.cloud_off_outlined,
                    titulo: AppStrings.boasVindasOffline,
                    dica: AppStrings.boasVindasOfflineDica,
                  ),
                  const _Destaque(
                    icone: Icons.group_outlined,
                    titulo: AppStrings.boasVindasCompartilhar,
                    dica: AppStrings.boasVindasCompartilharDica,
                  ),
                  const _Destaque(
                    icone: Icons.playlist_add,
                    titulo: AppStrings.boasVindasImportar,
                    dica: AppStrings.boasVindasImportarDica,
                  ),
                  const _Destaque(
                    icone: Icons.mic_none,
                    titulo: AppStrings.boasVindasDitar,
                    dica: AppStrings.boasVindasDitarDica,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppBotao(
                    rotulo: AppStrings.comecar,
                    onPressed: () async {
                      await ref
                          .read(onboardingVistoProvider.notifier)
                          .marcarVisto();
                      if (context.mounted) context.go('/listas');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque({
    required this.icone,
    required this.titulo,
    required this.dica,
  });

  final IconData icone;
  final String titulo;
  final String dica;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleSmall),
                Text(dica, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
