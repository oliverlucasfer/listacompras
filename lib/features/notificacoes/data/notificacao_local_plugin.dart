import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notificacao_local.dart';

/// Notificação local sobre `flutter_local_notifications` (RF-36, F53-T05).
///
/// Inicializa o plugin de forma preguiçosa e pede permissão no primeiro uso
/// (Android 13+ e iOS). Usa um canal e um id fixos: uma notificação por
/// cruzamento. 100% local — sem push nem rede.
class NotificacaoLocalPlugin implements NotificacaoLocal {
  NotificacaoLocalPlugin({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _idNotificacao = 1001;
  static const _canalId = 'orcamento';
  static const _canalNome = 'Alertas de orçamento';
  static const _canalDescricao =
      'Avisa quando o total da lista cruza o orçamento.';

  Future<void>? _inicializacao;
  bool _permissaoConcedida = false;

  Future<void> _garantirInicializado() => _inicializacao ??= _iniciar();

  Future<void> _iniciar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _permissaoConcedida = await _pedirAoSistema();
  }

  Future<bool> _pedirAoSistema() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return (await android.requestNotificationsPermission()) ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          true;
    }
    return true;
  }

  @override
  Future<bool> pedirPermissao() async {
    final concedida = await _pedirAoSistema();
    _permissaoConcedida = concedida;
    return concedida;
  }

  @override
  Future<void> mostrar({required String titulo, required String corpo}) async {
    await _garantirInicializado();
    if (!_permissaoConcedida) return;
    await _plugin.show(
      id: _idNotificacao,
      title: titulo,
      body: corpo,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          _canalNome,
          channelDescription: _canalDescricao,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
