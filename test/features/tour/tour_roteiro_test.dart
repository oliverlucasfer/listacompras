import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/tour/tour_roteiro.dart';

void main() {
  test('deve_pular_convite_quando_modo_lite', () {
    final elegiveis = passosEtapa2
        .where((p) => p.elegivel(AppCapacidades.lite))
        .map((p) => p.id)
        .toList();
    expect(elegiveis.contains('recursos.convite'), isFalse);
    expect(elegiveis.contains('recursos.mercado'), isTrue);
  });

  test('deve_incluir_convite_quando_colaborativo', () {
    final elegiveis = passosEtapa2
        .where((p) => p.elegivel(AppCapacidades.colaborativo))
        .map((p) => p.id)
        .toList();
    expect(elegiveis.contains('recursos.convite'), isTrue);
  });
}
