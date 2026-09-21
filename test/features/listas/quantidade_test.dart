import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/quantidade.dart';

void main() {
  test('deve_formatar_sem_decimal_quando_inteiro', () {
    expect(formatarQuantidade(2), '2');
    expect(formatarQuantidade(2.0), '2');
    expect(formatarQuantidade(0), '0');
    expect(formatarQuantidade(10.0), '10');
  });

  test('deve_manter_decimal_quando_fracionado', () {
    expect(formatarQuantidade(1.5), '1.5');
    expect(formatarQuantidade(0.25), '0.25');
  });
}
