import 'package:flutter/widgets.dart';

/// Chaves dos alvos do tour (doc 05 / spec F46). As telas anexam estas chaves
/// aos widgets reais; o overlay lê a posição via `currentContext`.
abstract final class TourKeys {
  static final novaLista = GlobalKey();
  static final campoAdicionar = GlobalKey();
  static final seletorUnidade = GlobalKey();
  static final botaoImportar = GlobalKey();
  static final lupa = GlobalKey();
  static final abaConfiguracoes = GlobalKey();
  static final itemLista = GlobalKey();
  static final botaoMercado = GlobalKey();
  static final menuMais = GlobalKey();
  static final acaoConvite = GlobalKey();
}
