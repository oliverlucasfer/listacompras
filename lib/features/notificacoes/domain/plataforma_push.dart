import 'package:flutter/foundation.dart';

/// Push só onde há suporte: Android hoje (iOS entra depois; Web/Desktop não).
/// Arquivo sem dependência do plugin, para ser importado por UI/providers sem
/// tocar `firebase_messaging`.
bool plataformaComPush() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}
