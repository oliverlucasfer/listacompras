import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_modo.dart';
import '../l10n/app_strings.dart';
import 'tokens/app_colors.dart';

/// Identidade visual (marca) do app. Derivada de [AppCapacidades] — a UI nunca
/// decide por [AppModo] diretamente (doc 15 §6).
class IdentidadeVisual {
  const IdentidadeVisual({
    required this.seed,
    required this.nomeApp,
    required this.logoAsset,
  });

  final Color seed;
  final String nomeApp;
  final String logoAsset;

  static const colaborativo = IdentidadeVisual(
    seed: AppColors.seed,
    nomeApp: AppStrings.appNome,
    logoAsset: 'assets/branding/logo.png',
  );

  static const lite = IdentidadeVisual(
    seed: AppColors.seedLite,
    nomeApp: AppStrings.appNomeLite,
    logoAsset: 'assets/branding/logo_lite.png',
  );
}

final identidadeVisualProvider = Provider<IdentidadeVisual>(
  (ref) => ref.watch(capacidadesProvider).nuvem
      ? IdentidadeVisual.colaborativo
      : IdentidadeVisual.lite,
);
