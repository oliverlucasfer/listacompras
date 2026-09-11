import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';
import '../theme/tokens/app_radius.dart';
import '../theme/tokens/app_spacing.dart';

/// Banners transversais (doc 15 §3) com contraste correto (`on*Container`).
enum AppBannerTipo { info, aviso, erro, offline, leitura }

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.tipo,
    required this.mensagem,
    this.acao,
  });

  final AppBannerTipo tipo;
  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semanticas =
        Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.claro;

    final (fundo, frente, icone) = switch (tipo) {
      AppBannerTipo.info => (
        semanticas.infoContainer,
        semanticas.onInfoContainer,
        Icons.info_outline,
      ),
      AppBannerTipo.aviso => (
        semanticas.warningContainer,
        semanticas.onWarningContainer,
        Icons.warning_amber_outlined,
      ),
      AppBannerTipo.erro => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      AppBannerTipo.offline => (
        semanticas.warningContainer,
        semanticas.onWarningContainer,
        Icons.cloud_off_outlined,
      ),
      AppBannerTipo.leitura => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.visibility_outlined,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(color: fundo, borderRadius: AppRadius.mdTodos),
      child: Row(
        children: [
          Icon(icone, color: frente, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(mensagem, style: TextStyle(color: frente)),
          ),
          ?acao,
        ],
      ),
    );
  }
}
