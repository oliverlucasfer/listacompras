import '../domain/notificacoes_push.dart';

/// Push desligado (modo Lite, RF-31): nenhuma operação toca o Firebase/FCM.
/// Usado por [notificacoesPushProvider] quando a capacidade `notificacoes`
/// está desligada, de modo que qualquer consumidor em Lite permaneça inerte.
class NotificacoesPushNulo implements NotificacoesPush {
  const NotificacoesPushNulo();

  @override
  bool get suportado => false;

  @override
  Future<PermissaoPush> pedirPermissao() async => PermissaoPush.indisponivel;

  @override
  Future<String?> obterToken() async => null;

  @override
  Future<void> apagarToken() async {}

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<Map<String, Object?>> get onToque => const Stream.empty();

  @override
  Future<Map<String, Object?>?> toqueInicial() async => null;

  @override
  Stream<Map<String, Object?>> get onRecebida => const Stream.empty();
}
