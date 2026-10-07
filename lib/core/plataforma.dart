import 'package:flutter/foundation.dart';

/// Verdadeiro em Android/iOS (exclui Web e Desktop) — onde os recursos
/// on-device (voz, OCR, câmera, notificação) existem. Fonte única do gate;
/// cada feature mantém seu nome semântico para poder divergir no futuro.
bool dispositivoMovel() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Verdadeiro apenas em Android (exclui Web/Desktop/iOS) — widget de tela
/// inicial (RF-38).
bool apenasAndroid() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
