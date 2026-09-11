import 'package:flutter/widgets.dart';

/// Escala de raios (doc 15 §1) — mais arredondada (M3 Expressive).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;

  static const BorderRadius smTodos = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdTodos = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgTodos = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlTodos = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlTodos = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullTodos = BorderRadius.all(Radius.circular(full));
}
