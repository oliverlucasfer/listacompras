import 'package:flutter/material.dart';

import '../l10n/politica_privacidade.dart';
import 'app_sheet.dart';

/// Abre a Política de Privacidade in-app (doc 06 §3.3.2, F21-T04): o texto
/// único de `politicaPrivacidadeTexto`, sem versão online. Usado no cadastro
/// e em Configurações.
Future<void> abrirPoliticaPrivacidade(BuildContext context) {
  return AppSheet.mostrar<void>(
    context,
    child: SingleChildScrollView(child: Text(politicaPrivacidadeTexto)),
  );
}
