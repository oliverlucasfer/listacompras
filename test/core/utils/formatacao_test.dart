import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/core/utils/formatacao.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';

void main() {
  test('deve_formatar_data_quando_dd_MM_aaaa', () {
    expect(formatarData(DateTime.utc(2026, 1, 9)), '09/01/2026');
  });

  test('deve_formatar_quantidade_com_unidade', () {
    expect(formatarQuantidadeComUnidade(1.5, Unidade.kg), '1½ kg');
    expect(formatarQuantidadeComUnidade(2, Unidade.un), '2 un');
  });

  test('deve_formatar_reais_sem_simbolo_quando_centavos', () {
    expect(formatarReaisSemSimbolo(549), '5,49');
    expect(formatarReaisSemSimbolo(123456), '1.234,56');
  });
}
