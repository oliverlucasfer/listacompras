import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacoes_providers.dart';

void main() {
  test('deve_indicar_push_quando_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(plataformaComPush(), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  test('deve_negar_push_quando_web_ou_desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(plataformaComPush(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
