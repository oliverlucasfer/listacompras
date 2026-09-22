import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import '../domain/reconhecimento_voz.dart';

/// Reconhecimento **no dispositivo** (RF-26): exige modelo local em pt-BR e
/// nunca usa rede. No Android o plugin cai silenciosamente para o reconhecedor
/// de rede quando o modo on-device não está disponível; por isso consultamos
/// [SpeechToTextPlatform.hasOnDeviceSupport] antes de ouvir e recusamos a sessão
/// quando não há suporte local. Erros permanentes (modelo ausente, permissão
/// negada) viram [onIndisponivel]; erros transitórios apenas param o estado.
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
      onError: (e) {
        onEstado(EstadoVoz.parado);
        if (e.permanent) onIndisponivel();
      },
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') onEstado(EstadoVoz.parado);
      },
    );
    if (!disponivel) {
      onEstado(EstadoVoz.indisponivel);
      onIndisponivel();
      return false;
    }
    final onDevice = await SpeechToTextPlatform.instance.hasOnDeviceSupport(
      localeId: 'pt_BR',
    );
    if (!onDevice) {
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
