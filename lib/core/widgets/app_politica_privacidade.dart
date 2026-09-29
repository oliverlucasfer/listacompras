import 'package:flutter/material.dart';

import '../l10n/politica_privacidade.dart';
import 'app_sheet.dart';

/// Abre a Política de Privacidade in-app (doc 06 §3.3.2): texto único do app
/// local, sem versão online embutida.
Future<void> abrirPoliticaPrivacidade(BuildContext context) {
  return AppSheet.mostrar<void>(
    context,
    child: const SingleChildScrollView(
      child: Text(politicaPrivacidadeTextoLite),
    ),
  );
}
