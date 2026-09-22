import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/voz/providers/reconhecimento_voz_provider.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('deve_retornar_true_quando_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(plataformaComVoz(), isTrue);
  });

  test('deve_retornar_true_quando_ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(plataformaComVoz(), isTrue);
  });

  test('deve_retornar_false_quando_desktop', () {
    for (final plataforma in [
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = plataforma;

      expect(plataformaComVoz(), isFalse, reason: '$plataforma');
    }
  });
}
