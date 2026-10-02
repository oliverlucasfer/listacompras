import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_sheet.dart';

/// Canal de contato/encarregado (doc 06 §3.3.2). Preenchido pelo dono com o
/// e-mail da conta de desenvolvedor no momento do PR de publicação.
const contatoPrivacidadeEmail = 'oliverlucasfer@gmail.com';

/// Abre a Política de Privacidade in-app (doc 06 §3.3.2): texto único do app
/// local, sem versão online embutida, traduzido pelo ARB (RF-39, F56).
Future<void> abrirPoliticaPrivacidade(BuildContext context) {
  return AppSheet.mostrar<void>(
    context,
    child: SingleChildScrollView(
      child: Text(
        context.l10n.politicaPrivacidadeTexto(contatoPrivacidadeEmail),
      ),
    ),
  );
}
