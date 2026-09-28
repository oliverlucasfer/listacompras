import 'package:flutter/widgets.dart';

import '../../core/config/app_modo.dart';

enum TourPosicao { abaixo, acima, centro }

/// Um passo do tour: onde apontar e o que dizer (doc 05 / spec F46).
class TourStep {
  const TourStep({
    required this.id,
    required this.alvo,
    required this.titulo,
    required this.corpo,
    required this.elegivel,
    this.posicao = TourPosicao.abaixo,
  });

  final String id;
  final GlobalKey alvo;
  final String titulo;
  final String corpo;
  final TourPosicao posicao;
  final bool Function(AppCapacidades) elegivel;
}
