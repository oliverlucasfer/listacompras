import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notificacao_local_plugin.dart';
import '../domain/notificacao_local.dart';

/// Notificação do SO só existe onde é suportada: Android/iOS. Web/Desktop
/// seguem apenas com os alertas in-app (espelha `plataformaComVoz`).
bool plataformaComNotificacao() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final notificacaoLocalProvider = Provider<NotificacaoLocal>(
  (ref) => NotificacaoLocalPlugin(),
);
