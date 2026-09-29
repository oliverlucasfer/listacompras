import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/observabilidade/sentry_config.dart';

void main() {
  test('deve_iniciar_sentry_quando_colaborativo_com_dsn', () {
    expect(
      sentryDeveIniciar(AppCapacidades.colaborativo, 'https://dsn'),
      isTrue,
    );
  });

  test('nao_deve_iniciar_sentry_quando_lite_mesmo_com_dsn', () {
    expect(sentryDeveIniciar(AppCapacidades.lite, 'https://dsn'), isFalse);
  });

  test('nao_deve_iniciar_sentry_quando_sem_dsn', () {
    expect(sentryDeveIniciar(AppCapacidades.colaborativo, ''), isFalse);
  });
}
