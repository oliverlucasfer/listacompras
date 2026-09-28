import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/tour/tour_roteiro.dart';

void main() {
  test('deve_ter_tres_passos_na_etapa1_na_ordem_da_home', () {
    expect(passosEtapa1.map((p) => p.id).toList(), <String>[
      'lista.criar',
      'lista.busca',
      'lista.config',
    ]);
  });

  test('deve_ter_oito_passos_na_etapa2_na_ordem_da_lista', () {
    expect(passosEtapa2.map((p) => p.id).toList(), <String>[
      'recursos.nome',
      'recursos.adicionar',
      'recursos.unidade',
      'recursos.importar',
      'recursos.marcar',
      'recursos.mercado',
      'recursos.orcamento',
      'recursos.convite',
    ]);
  });

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
