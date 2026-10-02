import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tokens/app_colors.dart';

/// Nome de marca do app (branding/nativo), independente da UI localizada
/// (RF-39, F56). Alimenta o `title` do `MaterialApp`; a chave ARB `appNome`
/// existe mas não é usada pela UI.
const _nomeAppMarca = 'Minhas Listas';

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
    nomeApp: _nomeAppMarca,
    logoAsset: 'assets/branding/logo_lite.png',
  );
}

final identidadeVisualProvider = Provider<IdentidadeVisual>(
  (ref) => IdentidadeVisual.lite,
);
