import 'package:flutter/material.dart';

/// Tipografia do app (doc 15 §1) — Plus Jakarta Sans bundlada.
///
/// As cores derivam do [ColorScheme] e do brilho (doc 15 §2/§4): no escuro o
/// tema usa as cores claras (`onSurface`) e no claro as escuras. Sem isso o
/// `TextTheme` fixo em `.black` sobrepõe o default do `ThemeData` e deixa o
/// texto preto sobre fundo escuro.
abstract final class AppTypography {
  static const family = 'PlusJakartaSans';

  /// Título de tela nas AppBars (doc 15 §1/§3, F13-T03): 24sp bold.
  ///
  /// Precisa ser explícito: o `appBarTheme.titleTextStyle` não passa pela
  /// localização de tipografia do `Theme`, então um estilo só de cor deixaria
  /// o título cair no tamanho default.
  static const tituloTelaTamanho = 24.0;
  static const tituloTelaPeso = FontWeight.bold;

  static TextTheme textTheme(Brightness brightness, ColorScheme scheme) {
    final tipografia = Typography.material2021(colorScheme: scheme);
    final base = brightness == Brightness.dark
        ? tipografia.white
        : tipografia.black;
    return base.apply(fontFamily: family);
  }
}
