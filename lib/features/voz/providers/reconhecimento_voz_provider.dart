import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reconhecimento_voz_plugin.dart';
import '../domain/reconhecimento_voz.dart';

/// O microfone só aparece onde o reconhecimento on-device é suportado:
/// Android/iOS (Web/Desktop ocultam — doc 05).
bool plataformaComVoz() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final reconhecimentoVozProvider = Provider<ReconhecimentoVoz>(
  (ref) => ReconhecimentoVozPlugin(),
);
