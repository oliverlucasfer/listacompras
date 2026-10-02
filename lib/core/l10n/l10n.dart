import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Acesso às traduções via `context.l10n` (RF-39, F56), substituindo o uso
/// direto de `AppStrings` na UI.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
