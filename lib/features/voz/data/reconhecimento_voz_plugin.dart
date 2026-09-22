import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/reconhecimento_voz.dart';

/// Reconhecimento **no dispositivo** (RF-26): sem rede e sem serviço externo.
/// Erros/indisponibilidade (modelo ausente, permissão negada) viram
/// [onIndisponivel] — o app nunca cai para reconhecimento por rede.
class ReconhecimentoVozPlugin implements ReconhecimentoVoz {
  final _speech = stt.SpeechToText();

  @override
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  }) async {
    onEstado(EstadoVoz.parado);
    final disponivel = await _speech.initialize(
      onError: (_) => onIndisponivel(),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') onEstado(EstadoVoz.parado);
      },
    );
    if (!disponivel) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    onEstado(EstadoVoz.ouvindo);
    try {
      await _speech.listen(
        onResult: (r) => onTexto(r.recognizedWords, r.finalResult),
        listenOptions: stt.SpeechListenOptions(
          onDevice: true,
          localeId: 'pt_BR',
          partialResults: true,
        ),
      );
    } catch (_) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    return true;
  }

  @override
  Future<void> parar() => _speech.stop();

  @override
  Future<void> cancelar() => _speech.cancel();
}
