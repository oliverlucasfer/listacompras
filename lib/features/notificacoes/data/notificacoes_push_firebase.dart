import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/notificacoes_push.dart';

class NotificacoesPushFirebase implements NotificacoesPush {
  FirebaseMessaging get _mensageria => FirebaseMessaging.instance;

  @override
  bool get suportado => true;

  @override
  Future<PermissaoPush> pedirPermissao() async {
    final ajustes = await _mensageria.requestPermission();
    return switch (ajustes.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PermissaoPush.concedida,
      AuthorizationStatus.notDetermined => PermissaoPush.indisponivel,
      _ => PermissaoPush.negada,
    };
  }

  @override
  Future<String?> obterToken() => _mensageria.getToken();

  @override
  Future<void> apagarToken() => _mensageria.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _mensageria.onTokenRefresh;

  @override
  Stream<Map<String, Object?>> get onToque =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, Object?>?> toqueInicial() async =>
      (await _mensageria.getInitialMessage())?.data;

  @override
  Stream<Map<String, Object?>> get onRecebida =>
      FirebaseMessaging.onMessage.map((m) => m.data);
}
