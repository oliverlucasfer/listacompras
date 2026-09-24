import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';

void main() {
  test('deve_ligar_nuvem_colaboracao_e_notificacoes_no_modo_colaborativo', () {
    const c = AppCapacidades.colaborativo;
    expect(c.nuvem, isTrue);
    expect(c.colaboracao, isTrue);
    expect(c.notificacoes, isTrue);
    expect(c.backup, isTrue);
  });

  test('deve_desligar_nuvem_colaboracao_e_notificacoes_no_modo_lite', () {
    const c = AppCapacidades.lite;
    expect(c.nuvem, isFalse);
    expect(c.colaboracao, isFalse);
    expect(c.notificacoes, isFalse);
    expect(c.backup, isTrue);
  });
}
