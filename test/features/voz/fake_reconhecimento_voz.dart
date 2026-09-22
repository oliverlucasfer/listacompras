import 'package:lista_compras/features/voz/domain/reconhecimento_voz.dart';

class FakeReconhecimentoVoz implements ReconhecimentoVoz {
  FakeReconhecimentoVoz({this.disponivel = true});

  bool disponivel;
  bool parou = false;
  bool cancelou = false;

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
