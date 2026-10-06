import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/etiqueta/domain/etiqueta.dart';

void main() {
  test('deve_extrair_preco_cheio_quando_etiqueta_simples', () {
    final e = analisarEtiqueta('Arroz Tio Joao\nR\$ 5,49');
    expect(e, isNotNull);
    expect(e!.nome, 'Arroz Tio Joao');
    expect(e.precoCentavos, 549);
    expect(e.precoPorKgCentavos, isNull);
  });

  test('deve_preferir_preco_do_por_quando_promocao', () {
    final e = analisarEtiqueta('de R\$ 9,99 por R\$ 6,99');
    expect(e!.precoCentavos, 699);
  });

  test('deve_usar_valor_por_kg_como_fallback_quando_unico', () {
    final e = analisarEtiqueta('R\$ 12,90/kg');
    expect(e!.precoCentavos, 1290);
    expect(e.precoPorKgCentavos, 1290);
  });

  test('deve_ignorar_valor_por_kg_quando_ha_preco_cheio', () {
    final e = analisarEtiqueta('Queijo\nR\$ 39,90\nR\$ 79,80/kg');
    expect(e!.precoCentavos, 3990);
    expect(e.precoPorKgCentavos, 7980);
  });

  test('deve_aceitar_milhar_quando_preco_grande', () {
    final e = analisarEtiqueta('TV 50 polegadas\nR\$ 1.234,56');
    expect(e!.precoCentavos, 123456);
  });

  test('deve_retornar_null_quando_sem_preco', () {
    expect(analisarEtiqueta('Oferta da semana'), isNull);
  });

  test('deve_omitir_nome_quando_etiqueta_so_preco', () {
    final e = analisarEtiqueta(r'R$ 5,49');
    expect(e!.nome, isNull);
    expect(e.precoCentavos, 549);
  });

  test('deve_ignorar_inteiro_solto_quando_ha_preco_com_moeda', () {
    final e = analisarEtiqueta(
      'QUEIJO MUSSARELA\nPESO LIQUIDO 200g\nR\$ 15,90\nR\$ 79,80/kg',
    );
    expect(e!.nome, 'QUEIJO MUSSARELA');
    expect(e.precoCentavos, 1590);
    expect(e.precoPorKgCentavos, 7980);
  });

  test('deve_ignorar_modelo_quando_ha_preco_com_moeda', () {
    final e = analisarEtiqueta('TV 50 polegadas\nR\$ 1.234,56');
    expect(e!.precoCentavos, 123456);
  });

  test('deve_preservar_nome_com_por_e_kg_em_substring', () {
    final e = analisarEtiqueta('Porco\nR\$ 24,90');
    expect(e!.nome, 'Porco');
    expect(e.precoCentavos, 2490);
  });

  test('deve_ignorar_peso_isolado_quando_nao_ha_preco_por_kg', () {
    final e = analisarEtiqueta('Presunto\nR\$ 24,90\n5kg');
    expect(e!.precoCentavos, 2490);
    expect(e.precoPorKgCentavos, isNull);
  });
}
