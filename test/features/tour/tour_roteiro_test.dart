import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/tour/tour_roteiro.dart';

void main() {
  test('deve_ter_quatro_passos_na_etapa1_na_ordem_da_home', () {
    expect(passosEtapa1.map((p) => p.id).toList(), <String>[
      'lista.criar',
      'lista.busca',
      'lista.historico',
      'lista.config',
    ]);
  });

  test('deve_ter_sete_passos_na_etapa2_na_ordem_da_lista', () {
    expect(passosEtapa2.map((p) => p.id).toList(), <String>[
      'recursos.nome',
      'recursos.adicionar',
      'recursos.unidade',
      'recursos.importar',
      'recursos.marcar',
      'recursos.mercado',
      'recursos.menu',
    ]);
  });

  test('deve_ter_dois_passos_na_etapa3_na_ordem_do_historico', () {
    expect(passosEtapa3.map((p) => p.id).toList(), <String>[
      'historico.resumo',
      'historico.estatisticas',
    ]);
  });
}
