import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/orcamento.dart';

Item _item({double qtd = 1, int? preco, bool concluido = true}) => Item(
  id: 'i',
  listaId: 'l',
  nome: 'x',
  quantidade: qtd,
  unidade: Unidade.un,
  categoria: CategoriaItem.outros,
  concluido: concluido,
  ordem: 0,
  criadoEm: DateTime.utc(2026),
  atualizadoEm: DateTime.utc(2026),
  precoCentavos: preco,
);

void main() {
  test('deve_ser_sem_orcamento_quando_nao_ha_limite', () {
    expect(estadoOrcamento(5000, null), EstadoOrcamento.semOrcamento);
  });

  test('deve_ser_normal_quando_abaixo_do_limiar', () {
    expect(estadoOrcamento(7000, 10000), EstadoOrcamento.normal); // 70%
  });

  test('deve_ser_aviso_quando_atinge_80_por_cento', () {
    expect(estadoOrcamento(8000, 10000), EstadoOrcamento.aviso);
    expect(estadoOrcamento(9999, 10000), EstadoOrcamento.aviso);
  });

  test('deve_ser_acima_quando_excede_o_orcamento', () {
    expect(estadoOrcamento(10001, 10000), EstadoOrcamento.acima);
  });

  test('deve_ser_acima_quando_orcamento_zero_e_total_positivo', () {
    expect(estadoOrcamento(1, 0), EstadoOrcamento.acima);
    expect(estadoOrcamento(0, 0), EstadoOrcamento.normal);
  });

  test('deve_detectar_cruzamento_apenas_ao_passar_o_limite', () {
    expect(cruzouLimite(antes: 9000, depois: 11000, orcamento: 10000), isTrue);
    expect(
      cruzouLimite(antes: 11000, depois: 12000, orcamento: 10000),
      isFalse,
    );
    expect(cruzouLimite(antes: 9000, depois: 9500, orcamento: 10000), isFalse);
    expect(cruzouLimite(antes: 9000, depois: 11000, orcamento: null), isFalse);
  });

  test('deve_calcular_subtotal_apenas_com_preco', () {
    expect(subtotalMarcado(_item(qtd: 2, preco: 500)), 1000);
    expect(subtotalMarcado(_item(qtd: 2, preco: null)), 0);
  });
}
