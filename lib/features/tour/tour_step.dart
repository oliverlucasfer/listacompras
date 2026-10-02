import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

enum TourPosicao { abaixo, acima, centro }

/// Resolve o texto de um passo a partir da localização (RF-39, F56). O roteiro
/// guarda a chave/função — nunca o texto localizado.
typedef TourTexto = String Function(AppLocalizations l10n);

/// Um passo do tour: onde apontar e o que dizer (doc 05 / spec F46). O texto
/// vem da UI via `context.l10n` (as funções [titulo]/[corpo]).
class TourStep {
  const TourStep({
    required this.id,
    required this.alvo,
    required this.titulo,
    required this.corpo,
    this.posicao = TourPosicao.abaixo,
  });

  final String id;
  final GlobalKey alvo;
  final TourTexto titulo;
  final TourTexto corpo;
  final TourPosicao posicao;
}
