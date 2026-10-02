import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_logo.dart';
import '../../voz/providers/reconhecimento_voz_provider.dart';
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
                    context.l10n.boasVindasTitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.boasVindasSubtitulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Destaque(
                    icone: Icons.cloud_off_outlined,
                    titulo: context.l10n.boasVindasOffline,
                    dica: context.l10n.boasVindasOfflineDica,
                  ),
                  _Destaque(
                    icone: Icons.save_alt_outlined,
                    titulo: context.l10n.boasVindasBackup,
                    dica: context.l10n.boasVindasBackupDica,
                  ),
                  _Destaque(
                    icone: Icons.playlist_add,
                    titulo: context.l10n.boasVindasImportar,
                    dica: context.l10n.boasVindasImportarDica,
                  ),
                  if (plataformaComVoz())
                    _Destaque(
                      icone: Icons.mic_none,
                      titulo: context.l10n.boasVindasDitar,
                      dica: context.l10n.boasVindasDitarDica,
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppBotao(
                    rotulo: context.l10n.comecar,
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
