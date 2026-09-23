import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notificacoes_push_firebase.dart';
import '../domain/notificacoes_push.dart';

/// Push só onde há suporte: Android hoje (iOS entra depois; Web/Desktop não).
bool plataformaComPush() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

final notificacoesPushProvider = Provider<NotificacoesPush>(
  (ref) => NotificacoesPushFirebase(),
);
