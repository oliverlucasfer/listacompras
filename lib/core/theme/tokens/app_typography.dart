import 'package:flutter/material.dart';

/// Tipografia do app (doc 15 §1) — Plus Jakarta Sans bundlada.
abstract final class AppTypography {
  static const family = 'PlusJakartaSans';

  static TextTheme get textTheme =>
      Typography.material2021().black.apply(fontFamily: family);
}
