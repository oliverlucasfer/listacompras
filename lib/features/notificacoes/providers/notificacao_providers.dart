import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plataforma.dart';
import '../data/notificacao_local_plugin.dart';
import '../domain/notificacao_local.dart';

/// Notificação do SO só existe onde é suportada: Android/iOS. Web/Desktop
/// seguem apenas com os alertas in-app.
bool plataformaComNotificacao() => dispositivoMovel();

final notificacaoLocalProvider = Provider<NotificacaoLocal>(
  (ref) => NotificacaoLocalPlugin(),
);
