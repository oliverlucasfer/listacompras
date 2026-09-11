import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/parser_lista_local.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  test('deve_extrair_quantidade_unidade_e_nome_quando_1kg_de_arroz', () {
    final r = analisarListaLocal('1kg de arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_usar_1_un_quando_sem_quantidade_e_marcar_aviso', () {
    final r = analisarListaLocal('2 leites\nbanana');
    expect(r.itens.map((i) => i.nome), ['Leites', 'Banana']);
    expect(r.itens.first.quantidade, 2);
    expect(r.itens.last.quantidade, 1);
    expect(r.itens.last.unidade, Unidade.un);
    expect(r.aviso, isNotNull);
  });

  test('deve_reconhecer_quantidade_no_fim_quando_arroz_1kg', () {
    final r = analisarListaLocal('arroz 1kg');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_segmentar_por_virgula_ponto_e_virgula_linha_e_conjuncao', () {
    final r = analisarListaLocal('arroz, leite; pão\ncafé e açúcar');
    expect(r.itens.map((i) => i.nome), [
      'Arroz',
      'Leite',
      'Pão',
      'Café',
      'Açúcar',
    ]);
  });

  test('deve_mapear_sinonimos_de_unidade', () {
    expect(
      analisarListaLocal('2 quilos de feijão').itens.single.unidade,
      Unidade.kg,
    );
    expect(
      analisarListaLocal('500 gramas queijo').itens.single.unidade,
      Unidade.g,
    );
    expect(
      analisarListaLocal('2 litros de leite').itens.single.unidade,
      Unidade.l,
    );
    expect(
      analisarListaLocal('1 cx de ovos').itens.single.unidade,
      Unidade.caixa,
    );
    expect(
      analisarListaLocal('3 pct de café').itens.single.unidade,
      Unidade.pacote,
    );
    expect(
      analisarListaLocal('1 dúzia de bananas').itens.single.unidade,
      Unidade.dz,
    );
  });

  test('deve_tolerar_acento_e_caixa', () {
    expect(
      analisarListaLocal('1 DÚZIA DE BANANAS').itens.single.unidade,
      Unidade.dz,
    );
  });

  test('deve_ignorar_texto_vazio', () {
    expect(analisarListaLocal('   ').itens, isEmpty);
  });
}
