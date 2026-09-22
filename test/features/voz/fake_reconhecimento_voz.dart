import 'dart:async';

import 'package:lista_compras/features/voz/domain/reconhecimento_voz.dart';

class FakeReconhecimentoVoz implements ReconhecimentoVoz {
  FakeReconhecimentoVoz({this.disponivel = true});

  bool disponivel;
  bool parou = false;
  bool cancelou = false;

  /// Quando definido, `iniciar` aguarda este completer antes de sinalizar
  /// `ouvindo` e retornar — simula a janela em que a tela é desmontada com o
  /// `iniciar` ainda no ar.
  Completer<void>? adiarInicio;

  void Function(String texto, bool finalizado)? _onTexto;
  void Function(EstadoVoz)? _onEstado;

  @override
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  }) async {
    _onTexto = onTexto;
    _onEstado = onEstado;
    if (!disponivel) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    if (adiarInicio != null) await adiarInicio!.future;
    onEstado(EstadoVoz.ouvindo);
    return true;
  }

  /// Emite texto reconhecido (chamado pelo teste).
  void emitir(String texto, {bool finalizado = false}) =>
      _onTexto?.call(texto, finalizado);

  @override
  Future<void> parar() async {
    parou = true;
    _onEstado?.call(EstadoVoz.parado);
  }

  @override
  Future<void> cancelar() async => cancelou = true;
}
