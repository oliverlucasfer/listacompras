import 'package:flutter/material.dart';

/// Tema do app (doc 05 §7): Material 3 + ColorScheme.fromSeed,
/// claro e escuro automáticos (seguem o sistema).
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2E7D32); // verde: compras/mercado

  static ThemeData get light => _base(Brightness.light);

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
