enum PermissaoPush { concedida, negada, indisponivel }

abstract interface class NotificacoesPush {
  bool get suportado;
  Future<PermissaoPush> pedirPermissao();
  Future<String?> obterToken();
  Future<void> apagarToken();
  Stream<String> get onTokenRefresh;
  Stream<Map<String, Object?>> get onToque;
  Future<Map<String, Object?>?> toqueInicial();
  Stream<Map<String, Object?>> get onRecebida;
}
