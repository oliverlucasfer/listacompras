import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import 'tokens/app_colors.dart';

/// Identidade visual (marca) do app local "Minhas Listas" (doc 15 §6).
class IdentidadeVisual {
  const IdentidadeVisual({
    required this.seed,
    required this.nomeApp,
    required this.logoAsset,
  });

  final Color seed;
  final String nomeApp;
  final String logoAsset;

  static const lite = IdentidadeVisual(
    seed: AppColors.seedLite,
    nomeApp: AppStrings.appNome,
    logoAsset: 'assets/branding/logo_lite.png',
  );
}

final identidadeVisualProvider = Provider<IdentidadeVisual>(
  (ref) => IdentidadeVisual.lite,
);
