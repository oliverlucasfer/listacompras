import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/reconhecimento_voz.dart';

/// Reconhecimento de voz (RF-26). O app **pede** reconhecimento **no
/// dispositivo** (`onDevice: true`, pt-BR) e nunca inicia uma chamada de rede
/// por conta própria. Limitação do plugin/OS: no Android, quando não há modelo
/// on-device para o idioma, o próprio sistema pode cair para o reconhecedor de
/// rede — o `speech_to_text` não expõe forma de verificar/forçar on-device, e
/// `SpeechToTextPlatform.hasOnDeviceSupport` não tem handler nativo em 7.5.0
/// (lança `MissingPluginException`), então esse fallback não pode ser impedido.
/// Erros permanentes (modelo ausente, permissão negada) viram [onIndisponivel];
/// erros transitórios apenas param o estado.
class ReconhecimentoVozPlugin implements ReconhecimentoVoz {
  final _speech = stt.SpeechToText();

  @override
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  }) async {
    onEstado(EstadoVoz.parado);

    void aoErro(SpeechRecognitionError e) {
      onEstado(EstadoVoz.parado);
      if (e.permanent) onIndisponivel();
    }

    void aoStatus(String s) {
      if (s == 'done' || s == 'notListening') onEstado(EstadoVoz.parado);
    }

    // Invariante: `_speech` é um singleton que vive por todo o app e
    // `initialize` retorna cedo (`_initWorked`) sem reatribuir os listeners a
    // partir da segunda chamada. Reafixamos os campos públicos a cada
    // `iniciar` para que erros permanentes e mudanças de status cheguem à tela
    // atual — e não à primeira (já desmontada), que só faria no-ops.
    _speech
      ..errorListener = aoErro
      ..statusListener = aoStatus;
    final disponivel = await _speech.initialize(
      onError: aoErro,
      onStatus: aoStatus,
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
