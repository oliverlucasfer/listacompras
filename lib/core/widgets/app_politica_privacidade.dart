import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_modo.dart';
import '../l10n/politica_privacidade.dart';
import 'app_sheet.dart';

/// Abre a Política de Privacidade in-app (doc 06 §3.3.2): o texto do modo
/// atual (Lite × colaborativo), sem versão online embutida.
Future<void> abrirPoliticaPrivacidade(BuildContext context) {
  final cap = ProviderScope.containerOf(context).read(capacidadesProvider);
  return AppSheet.mostrar<void>(
    context,
    child: SingleChildScrollView(child: Text(politicaPrivacidadePara(cap))),
  );
}
