import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/quantidade.dart';

void main() {
  test('deve_parsear_quantidade_quando_numerico', () {
    expect(parseQuantidade('2'), 2);
    expect(parseQuantidade('1,5'), 1.5);
    expect(parseQuantidade('1.5'), 1.5);
  });

  test('deve_parsear_quantidade_quando_fracao_numerica', () {
    expect(parseQuantidade('1/2'), 0.5);
    expect(parseQuantidade('3/4'), 0.75);
  });

  test('deve_parsear_quantidade_quando_glifo', () {
    expect(parseQuantidade('½'), 0.5);
    expect(parseQuantidade('1½'), 1.5);
    expect(parseQuantidade('2⅓'), closeTo(2.3333, 0.001));
  });

  test('deve_retornar_null_quando_invalido', () {
    expect(parseQuantidade('abc'), isNull);
    expect(parseQuantidade('1/0'), isNull);
    expect(parseQuantidade(''), isNull);
    expect(parseQuantidade('-2'), isNull);
    expect(
      parseQuantidade('1 1/2'),
      isNull,
    ); // misto espaçado é do parser (Task 2)
    expect(parseQuantidade('99999999999999999999/2'), isNull);
    expect(parseQuantidade('1e400'), isNull);
  });

  test('deve_ter_glifos_fracao_quando_constante', () {
    expect(glifosFracao, '½¼¾⅓⅔');
  });

  test('deve_formatar_quando_inteiro', () {
    expect(formatarQuantidade(2), '2');
    expect(formatarQuantidade(2.0), '2');
    expect(formatarQuantidade(0), '0');
    expect(formatarQuantidade(10.0), '10');
  });

  test('deve_formatar_quando_glifo_comum', () {
    expect(formatarQuantidade(0.5), '½');
    expect(formatarQuantidade(1.5), '1½');
    expect(formatarQuantidade(0.25), '¼');
    expect(formatarQuantidade(2 + 1 / 3), '2⅓');
    expect(formatarQuantidade(1.25), '1¼');
  });

  test('deve_cortar_decimais_quando_nao_e_glifo_comum', () {
    expect(formatarQuantidade(1.2), '1.2');
    expect(formatarQuantidade(1 / 7), '0.143');
    expect(formatarQuantidade(0.3333), '⅓'); // tolerância casa 1/3
  });

  test('deve_nao_quebrar_quando_nao_finito', () {
    expect(formatarQuantidade(double.nan), 'NaN');
    expect(formatarQuantidade(double.infinity), 'Infinity');
  });
}
