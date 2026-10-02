import 'package:flutter/material.dart';
import 'package:lista_compras/l10n/app_localizations.dart';

/// Locale padrão dos testes: pt-BR (idioma template/fallback do app).
const localePadraoTeste = Locale('pt', 'BR');

/// Envolve [home] num `MaterialApp` com os delegates e `supportedLocales` do
/// app, para que `context.l10n` resolva nos testes (RF-39, F56).
///
/// Roda em pt-BR por padrão; passe [locale] para validar en/es.
Widget appTeste(
  Widget home, {
  Locale locale = localePadraoTeste,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: theme,
    home: home,
  );
}
