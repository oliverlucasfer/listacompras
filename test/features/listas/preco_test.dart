import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

Item _item({
  required bool concluido,
  int? precoCentavos,
  double quantidade = 1,
}) => Item(
  id: 'i',
  listaId: 'l',
  nome: 'x',
  quantidade: quantidade,
  unidade: Unidade.un,
  categoria: CategoriaItem.outros,
  concluido: concluido,
  ordem: 0,
  criadoEm: DateTime(2026),
  atualizadoEm: DateTime(2026),
  precoCentavos: precoCentavos,
);

void main() {
  test('deve_formatar_reais_quando_centavos', () {
    expect(formatarReais(0), r'R$ 0,00');
    expect(formatarReais(549), r'R$ 5,49');
    expect(formatarReais(123456), r'R$ 1.234,56');
    expect(formatarReais(100000000), r'R$ 1.000.000,00');
  });

  test('deve_parsear_preco_quando_virgula_ponto_ou_inteiro', () {
    expect(parsePrecoParaCentavos('5,49'), 549);
    expect(parsePrecoParaCentavos('5.49'), 549);
    expect(parsePrecoParaCentavos('5'), 500);
    expect(parsePrecoParaCentavos(r'R$ 1.234,56'), 123456);
    expect(parsePrecoParaCentavos('1.234'), 123400);
    expect(parsePrecoParaCentavos('999.999'), 99999900);
    expect(parsePrecoParaCentavos('5.4'), 540);
  });

  test('deve_aceitar_teto_quando_preco_no_limite', () {
    // Teto do CHECK do Postgres (01 §4.3): R$ 999.999,99 = 99999999 centavos.
    expect(parsePrecoParaCentavos('999999,99'), 99999999);
  });

  test('deve_rejeitar_quando_preco_acima_do_teto', () {
    expect(() => parsePrecoParaCentavos('1000000'), throwsArgumentError);
  });

  test('deve_rejeitar_quando_preco_nao_numerico', () {
    expect(() => parsePrecoParaCentavos('abc'), throwsArgumentError);
  });

  test('deve_formatar_negativo_quando_centavos_negativos', () {
    expect(formatarReais(-549), r'-R$ 5,49');
  });

  test('deve_retornar_null_quando_preco_vazio', () {
    expect(parsePrecoParaCentavos(''), isNull);
    expect(parsePrecoParaCentavos('   '), isNull);
    expect(parsePrecoParaCentavos(null), isNull);
  });

  test('deve_rejeitar_quando_preco_negativo', () {
    expect(() => parsePrecoParaCentavos('-1'), throwsArgumentError);
  });

  test('deve_somar_apenas_marcados_com_preco_quando_total', () {
    final itens = [
      _item(concluido: true, precoCentavos: 500),
      _item(concluido: false, precoCentavos: 999),
      _item(concluido: true, precoCentavos: null),
      _item(concluido: true, precoCentavos: 250),
    ];
    expect(totalCarrinho(itens), 750);
  });

  test('deve_arredondar_subtotal_quando_quantidade_fracionaria', () {
    expect(
      totalCarrinho([
        _item(concluido: true, precoCentavos: 999, quantidade: 0.5),
      ]),
      500,
    );
  });
}
