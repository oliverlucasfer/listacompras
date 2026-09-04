import 'mutacao_sync.dart';

/// Resultado do envio de uma mutação — decisão LWW (doc 03 §5).
sealed class ResultadoEnvio {
  const ResultadoEnvio();
}

/// Local venceu no LWW (ou não havia registro remoto): payload enviado.
class Enviado extends ResultadoEnvio {
  const Enviado();
}

/// Remoto venceu no LWW: payload do registro remoto vencedor — o Sync
/// Engine aplica no Drift e descarta as mutações pendentes do registro.
class RemotoVenceu extends ResultadoEnvio {
  const RemotoVenceu(this.registro);

  final Map<String, Object?> registro;
}

/// Destino das mutações no servidor (doc 03 §2/§4) com comparação LWW
/// (doc 03 §5): consulte o registro remoto antes de decidir.
abstract interface class SyncRemoto {
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao);
}
