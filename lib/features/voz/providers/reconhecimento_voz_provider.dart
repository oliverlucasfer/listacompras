import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/idioma/idioma_provider.dart';
import '../data/reconhecimento_voz_plugin.dart';
import '../domain/reconhecimento_voz.dart';

/// O microfone só aparece onde o reconhecimento on-device é suportado:
/// Android/iOS (Web/Desktop ocultam — doc 05).
bool plataformaComVoz() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Locale do reconhecedor por idioma do app (RF-39). `sistema` usa o idioma do
/// aparelho quando conhecido; senão pt-BR (template/fallback do app).
String localeVozDe(IdiomaApp idioma) => switch (idioma) {
  IdiomaApp.pt => 'pt_BR',
  IdiomaApp.en => 'en_US',
  IdiomaApp.es => 'es_ES',
  IdiomaApp.sistema =>
    switch (PlatformDispatcher.instance.locale.languageCode) {
      'en' => 'en_US',
      'es' => 'es_ES',
      _ => 'pt_BR',
    },
};

final reconhecimentoVozProvider = Provider<ReconhecimentoVoz>(
  (ref) => ReconhecimentoVozPlugin(
    localeId: localeVozDe(ref.watch(idiomaProvider).value ?? IdiomaApp.sistema),
  ),
);
