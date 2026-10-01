import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('deve_ser_verdadeiro_no_android_e_ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(plataformaComOcr(), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(plataformaComOcr(), isTrue);
  });

  test('deve_ser_falso_no_desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(plataformaComOcr(), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(plataformaComOcr(), isFalse);
  });
}
