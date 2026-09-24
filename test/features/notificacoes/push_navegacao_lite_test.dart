import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacoes_providers.dart';
import 'package:lista_compras/features/notificacoes/providers/push_navegacao.dart';

import 'fake_notificacoes_push.dart';

/// Prova que a ponte de notificação em primeiro plano respeita a capacidade
/// `notificacoes` (RF-31): no Lite, mesmo em Android, ela não lê o
/// `notificacoesPushProvider` — logo, não constrói `NotificacoesPushFirebase`
/// nem toca o FCM.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('deve_nao_ler_push_quando_modo_lite_no_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var leuPush = false;
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        notificacoesPushProvider.overrideWith((ref) {
          leuPush = true;
          return NotificacoesPushFake();
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificacoesForegroundProvider);

    expect(leuPush, isFalse);
  });

  test('deve_ler_push_quando_modo_colaborativo_no_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var leuPush = false;
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.colaborativo),
        notificacoesPushProvider.overrideWith((ref) {
          leuPush = true;
          return NotificacoesPushFake();
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificacoesForegroundProvider);

    expect(leuPush, isTrue);
  });
}
