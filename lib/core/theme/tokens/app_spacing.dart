import 'package:flutter/widgets.dart';

/// Escala de espaçamento (doc 15 §1). Único lugar com valores de espaçamento.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets tela = EdgeInsets.all(lg);
  static const EdgeInsets horizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalCompacto = EdgeInsets.symmetric(
    horizontal: md,
  );
}
