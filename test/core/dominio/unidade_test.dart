import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

void main() {
  test('deve_mapear_pt_quando_valor_do_enum', () {
    expect(Unidade.fromValor('pt'), Unidade.pt);
    expect(Unidade.pt.valor, 'pt');
  });
}
