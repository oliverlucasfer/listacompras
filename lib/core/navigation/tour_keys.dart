import 'package:flutter/widgets.dart';

/// Chaves dos alvos do tour (doc 05 / spec F46) e de âncoras de teste do
/// shell. As telas anexam estas chaves aos widgets reais; o overlay lê a
/// posição via `currentContext`. Vivem em `core` porque são um contrato
/// compartilhado entre `core/navigation`, várias features e o tour.
abstract final class TourKeys {
  static final novaLista = GlobalKey();
  static final nomeLista = GlobalKey();
  static final campoAdicionar = GlobalKey();
  static final seletorUnidade = GlobalKey();
  static final botaoImportar = GlobalKey();
  static final lupa = GlobalKey();
  static final abaConfiguracoes = GlobalKey();
  static final itemLista = GlobalKey();
  static final botaoMercado = GlobalKey();
  static final menuMais = GlobalKey();
  static final abaHistorico = GlobalKey();
  static final resumoHistorico = GlobalKey();
  static final abaEstatisticas = GlobalKey();
}
