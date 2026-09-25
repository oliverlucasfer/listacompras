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

/// INSERT duplicado (doc 03 §5, RF-10): já existe item ativo com o mesmo
/// nome na lista — [registro] é a linha remota (com quantidade somada
/// quando as unidades coincidem); o Sync Engine tombstone a linha local,
/// aplica o registro e descarta as mutações do registro local.
class Duplicado extends ResultadoEnvio {
  const Duplicado(this.registro);

  final Map<String, Object?> registro;
}

/// Destino das mutações no servidor (doc 03 §2/§4) com comparação LWW
/// (doc 03 §5): consulte o registro remoto antes de decidir.
abstract interface class SyncRemoto {
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao);
}

/// Relógio do servidor (doc 03 §5, R-06): a divergência grosseira de relógio
/// do dispositivo só é detectável comparando o `updated_at` do payload (o
/// carimbo do LWW) com o `now()` do banco — nunca com o relógio local, que
/// gerou esse carimbo. O `ts_local` da fila é só a hora do enfileiramento
/// (ordem/coalescing).
abstract interface class FonteTempoServidor {
  /// `null` quando indisponível (sem rede, sem sessão): o chamador não
  /// reporta divergência em cima de incerteza.
  Future<DateTime?> agoraDoServidor();
}
