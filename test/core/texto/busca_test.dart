import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/texto/busca.dart';

void main() {
  test('deve_ignorar_caixa_e_acento_quando_buscar', () {
    expect(contemBusca('Café', 'cafe'), isTrue);
    expect(contemBusca('Açúcar', 'ACUCAR'), isTrue);
    expect(contemBusca('Leite', 'lei'), isTrue);
  });

  test('deve_devolver_false_quando_nao_casa', () {
    expect(contemBusca('Arroz', 'feijao'), isFalse);
  });

  test('deve_casar_com_espacos_normalizados_quando_buscar', () {
    expect(contemBusca('  Queijo   prato ', 'queijo prato'), isTrue);
  });
}
