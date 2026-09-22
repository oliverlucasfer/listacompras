/// Estado do reconhecimento de voz para a UI.
enum EstadoVoz { parado, ouvindo, indisponivel }

/// Contrato do reconhecimento de voz **on-device** (RF-26). A UI depende desta
/// interface; a implementação real usa `speech_to_text` e os testes usam um fake.
abstract interface class ReconhecimentoVoz {
  /// Inicializa e começa a ouvir (on-device, pt-BR). Devolve `false` quando o
  /// reconhecimento não está disponível (sem modelo/permissão negada) — nesse
  /// caso chama [onIndisponivel]. [onTexto] recebe o texto parcial/final.
  Future<bool> iniciar({
    required void Function(String texto, bool finalizado) onTexto,
    required void Function() onIndisponivel,
    required void Function(EstadoVoz) onEstado,
  });

  Future<void> parar();

  Future<void> cancelar();
}
