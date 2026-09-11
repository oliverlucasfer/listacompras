import 'package:flutter/animation.dart';

/// Durações e curvas de movimento (doc 15 §1).
abstract final class AppMotion {
  static const Duration rapida = Duration(milliseconds: 150);
  static const Duration media = Duration(milliseconds: 250);
  static const Duration longa = Duration(milliseconds: 400);

  static const Curve padrao = Curves.easeInOutCubicEmphasized;
  static const Curve entrada = Curves.easeOutCubic;
  static const Curve saida = Curves.easeInCubic;
}
