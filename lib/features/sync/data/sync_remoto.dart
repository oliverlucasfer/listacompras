import 'mutacao_sync.dart';

/// Destino das mutações no servidor (doc 03 §2/§4). A comparação LWW e a
/// aplicação do remoto vencedor entram na F4-T04.
abstract interface class SyncRemoto {
  Future<void> enviar(MutacaoSync mutacao);
}
