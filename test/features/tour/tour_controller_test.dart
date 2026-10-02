import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deve_estar_falso_quando_sem_flag', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isFalse,
    );
  });

  test('deve_marcar_vista_quando_concluir', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(tourEtapaVistaProvider(TourEtapa.primeira).notifier)
        .marcarVista(TourEtapa.primeira);
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isTrue,
    );
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.recursos).future),
      isFalse,
    );
  });

  test('deve_marcar_etapa3_sem_afetar_as_outras', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(tourEtapaVistaProvider(TourEtapa.historico).notifier)
        .marcarVista(TourEtapa.historico);
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.historico).future),
      isTrue,
    );
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isFalse,
    );
  });
}
