import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/parser_lista_local.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

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
    final kilos = analisarListaLocal('2 kilos de feijão').itens.single;
    expect(kilos.unidade, Unidade.kg);
    expect(kilos.nome, 'Feijão');
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
      Unidade.pct,
    );
    expect(
      analisarListaLocal('1 dúzia de bananas').itens.single.unidade,
      Unidade.dz,
    );
  });

  test('deve_mapear_pct_para_o_enum_pct_quando_unidade_abreviada', () {
    final r = analisarListaLocal('2 pct de ovos');
    expect(r.itens.single.quantidade, 2);
    expect(r.itens.single.unidade, Unidade.pct);
  });

  test('deve_mapear_pct_para_o_enum_pct_quando_colado_ao_numero', () {
    final r = analisarListaLocal('2pct de ovos');
    expect(r.itens.single.unidade, Unidade.pct);
  });

  test('deve_reconhecer_unidade_pt_quando_abreviacao', () {
    final r = analisarListaLocal('2 pt de café');
    expect(r.itens.single.quantidade, 2);
    expect(r.itens.single.unidade, Unidade.pt);
  });

  test('deve_reconhecer_unidade_pt_quando_palavra_e_plural', () {
    expect(
      analisarListaLocal('1 pote de sorvete').itens.single.unidade,
      Unidade.pt,
    );
    expect(
      analisarListaLocal('3 potes de iogurte').itens.single.unidade,
      Unidade.pt,
    );
  });

  test('deve_reconhecer_bandeja_saco_fardo_garrafa_quando_sigla', () {
    expect(
      analisarListaLocal('1 bdj de morango').itens.single.unidade,
      Unidade.bandeja,
    );
    expect(
      analisarListaLocal('2 sc de arroz').itens.single.unidade,
      Unidade.saco,
    );
    expect(
      analisarListaLocal('1 fd de refrigerante').itens.single.unidade,
      Unidade.fardo,
    );
    expect(
      analisarListaLocal('1 grf de vinho').itens.single.unidade,
      Unidade.garrafa,
    );
  });

  test(
    'deve_reconhecer_bandeja_saco_fardo_garrafa_quando_palavra_e_plural',
    () {
      expect(
        analisarListaLocal('1 bandeja de morango').itens.single.unidade,
        Unidade.bandeja,
      );
      expect(
        analisarListaLocal('2 bandejas de morango').itens.single.unidade,
        Unidade.bandeja,
      );
      expect(
        analisarListaLocal('1 saco de batata').itens.single.unidade,
        Unidade.saco,
      );
      expect(
        analisarListaLocal('3 sacos de laranja').itens.single.unidade,
        Unidade.saco,
      );
      expect(
        analisarListaLocal('1 fardo de cerveja').itens.single.unidade,
        Unidade.fardo,
      );
      expect(
        analisarListaLocal('2 fardos de água').itens.single.unidade,
        Unidade.fardo,
      );
      expect(
        analisarListaLocal('1 garrafa de azeite').itens.single.unidade,
        Unidade.garrafa,
      );
      expect(
        analisarListaLocal('2 garrafas de suco').itens.single.unidade,
        Unidade.garrafa,
      );
    },
  );

  test('deve_reconhecer_unidades_de_porcao_e_embalagem_quando_sigla', () {
    expect(
      analisarListaLocal('1 ct de ovos').itens.single.unidade,
      Unidade.cento,
    );
    expect(
      analisarListaLocal('1 cc de banana').itens.single.unidade,
      Unidade.cacho,
    );
    expect(
      analisarListaLocal('1 mh de banana').itens.single.unidade,
      Unidade.mao,
    );
    expect(
      analisarListaLocal('1 pe de alface').itens.single.unidade,
      Unidade.pe,
    );
    expect(
      analisarListaLocal('1 cb de repolho').itens.single.unidade,
      Unidade.cabeca,
    );
    expect(
      analisarListaLocal('1 mc de cheiro-verde').itens.single.unidade,
      Unidade.maco,
    );
    expect(
      analisarListaLocal('1 rm de salsa').itens.single.unidade,
      Unidade.ramo,
    );
    expect(
      analisarListaLocal('1 lt de atum').itens.single.unidade,
      Unidade.lata,
    );
    expect(
      analisarListaLocal('1 vd de geleia').itens.single.unidade,
      Unidade.vidro,
    );
    expect(
      analisarListaLocal('1 sch de tempero').itens.single.unidade,
      Unidade.sache,
    );
    expect(
      analisarListaLocal('1 rl de papel').itens.single.unidade,
      Unidade.rolo,
    );
    expect(
      analisarListaLocal('1 br de chocolate').itens.single.unidade,
      Unidade.barra,
    );
    expect(
      analisarListaLocal('1 bsg de maionese').itens.single.unidade,
      Unidade.bisnaga,
    );
    expect(
      analisarListaLocal('1 gl de água').itens.single.unidade,
      Unidade.galao,
    );
  });

  test(
    'deve_reconhecer_unidades_de_porcao_e_embalagem_quando_palavra_e_plural',
    () {
      expect(
        analisarListaLocal('1 cento de ovos').itens.single.unidade,
        Unidade.cento,
      );
      expect(
        analisarListaLocal('2 cachos de uva').itens.single.unidade,
        Unidade.cacho,
      );
      expect(
        analisarListaLocal('1 mão de banana').itens.single.unidade,
        Unidade.mao,
      );
      expect(
        analisarListaLocal('2 mãos de banana').itens.single.unidade,
        Unidade.mao,
      );
      expect(
        analisarListaLocal('1 pé de alface').itens.single.unidade,
        Unidade.pe,
      );
      expect(
        analisarListaLocal('2 pés de alface').itens.single.unidade,
        Unidade.pe,
      );
      expect(
        analisarListaLocal('1 cabeça de repolho').itens.single.unidade,
        Unidade.cabeca,
      );
      expect(
        analisarListaLocal('1 maço de rúcula').itens.single.unidade,
        Unidade.maco,
      );
      expect(
        analisarListaLocal('2 ramos de hortelã').itens.single.unidade,
        Unidade.ramo,
      );
      expect(
        analisarListaLocal('2 latas de atum').itens.single.unidade,
        Unidade.lata,
      );
      expect(
        analisarListaLocal('1 vidro de conserva').itens.single.unidade,
        Unidade.vidro,
      );
      expect(
        analisarListaLocal('2 sachês de molho').itens.single.unidade,
        Unidade.sache,
      );
      expect(
        analisarListaLocal('1 rolo de papel').itens.single.unidade,
        Unidade.rolo,
      );
      expect(
        analisarListaLocal('2 barras de sabão').itens.single.unidade,
        Unidade.barra,
      );
      expect(
        analisarListaLocal('1 bisnaga de creme dental').itens.single.unidade,
        Unidade.bisnaga,
      );
      expect(
        analisarListaLocal('2 galões de água').itens.single.unidade,
        Unidade.galao,
      );
    },
  );

  test('deve_tolerar_acento_e_caixa', () {
    expect(
      analisarListaLocal('1 DÚZIA DE BANANAS').itens.single.unidade,
      Unidade.dz,
    );
  });

  test('deve_ignorar_texto_vazio', () {
    expect(analisarListaLocal('   ').itens, isEmpty);
  });

  test('deve_interpretar_item_avulso_com_unidade_explicita', () {
    final item = interpretarItemAvulso('1kg de banana');
    expect(item, isNotNull);
    expect(item!.nome, 'Banana');
    expect(item.quantidade, 1);
    expect(item.unidade, Unidade.kg);
  });

  test('deve_usar_unidade_padrao_quando_texto_sem_unidade', () {
    final item = interpretarItemAvulso('banana', unidadePadrao: Unidade.dz);
    expect(item!.nome, 'Banana');
    expect(item.quantidade, 1);
    expect(item.unidade, Unidade.dz);
  });

  test('deve_priorizar_unidade_explicita_sobre_padrao', () {
    final item = interpretarItemAvulso(
      '1kg de banana',
      unidadePadrao: Unidade.dz,
    );
    expect(item!.unidade, Unidade.kg);
  });

  test('deve_aplicar_unidade_padrao_quando_ha_quantidade_sem_unidade', () {
    final item = interpretarItemAvulso('2 banana', unidadePadrao: Unidade.dz);
    expect(item!.quantidade, 2);
    expect(item.nome, 'Banana');
    expect(item.unidade, Unidade.dz);
  });

  test('deve_retornar_null_quando_item_avulso_vazio', () {
    expect(interpretarItemAvulso('   '), isNull);
  });

  test('deve_converter_virgula_decimal_quando_1_5_kg', () {
    final r = analisarListaLocal('1,5 kg de arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_segmentar_por_virgula_entre_itens_quando_arroz_leite', () {
    final r = analisarListaLocal('arroz, leite');
    expect(r.itens.map((i) => i.nome), ['Arroz', 'Leite']);
  });

  test('deve_converter_virgula_decimal_no_item_avulso_quando_2_5_leite', () {
    final item = interpretarItemAvulso('2,5 leite');
    expect(item!.quantidade, 2.5);
    expect(item.nome, 'Leite');
  });

  test('deve_usar_1_un_e_avisar_quando_quantidade_zero', () {
    final r = analisarListaLocal('0 arroz');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.un);
    expect(r.aviso, isNotNull);
  });

  test('deve_manter_unidade_explicita_quando_quantidade_zero', () {
    final r = analisarListaLocal('0 kg de arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.kg);
    expect(r.itens.single.nome, 'Arroz');
    expect(r.aviso, isNotNull);
  });

  test('deve_usar_1_un_quando_quantidade_zero_no_fim', () {
    final r = analisarListaLocal('arroz 0');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1);
    expect(r.aviso, isNotNull);
  });

  test('deve_ler_fracao_quando_glifo', () {
    final r = analisarListaLocal('½ kg de queijo');
    expect(r.itens.single.quantidade, 0.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_fracao_quando_numerica', () {
    final r = analisarListaLocal('1/2 kg de queijo');
    expect(r.itens.single.quantidade, 0.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_misto_quando_espacado', () {
    final r = analisarListaLocal('1 1/2 kg de queijo');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_misto_quando_colado', () {
    final r = analisarListaLocal('1½ kg de queijo');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_misto_quando_espacado_no_fim', () {
    final r = analisarListaLocal('arroz 1 1/2');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.un);
  });

  test('deve_ler_fracao_quando_colada_no_fim', () {
    final r = analisarListaLocal('arroz 1/2kg');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 0.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_fracao_quando_avulso', () {
    final item = interpretarItemAvulso('1/2 kg banana');
    expect(item!.quantidade, 0.5);
    expect(item.unidade, Unidade.kg);
  });

  test('nao_deve_lancar_quando_denominador_zero_no_meio', () {
    final r = analisarListaLocal('abc 1/0');
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Abc 1/0');
    expect(r.itens.single.quantidade, 1);
    expect(r.itens.single.unidade, Unidade.un);
  });

  test('nao_deve_lancar_quando_denominador_zero_no_avulso', () {
    final item = interpretarItemAvulso('1/0 kg banana');
    expect(item, isNotNull);
    expect(item!.nome, '1/0 kg banana');
    expect(item.quantidade, 1);
    expect(item.unidade, Unidade.un);
  });

  test('deve_ler_misto_colado_com_unidade_quando_1_meio_kg', () {
    final r = analisarListaLocal('1½kg de queijo');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });

  test('deve_ler_nome_quantidade_unidade_quando_separados_no_fim', () {
    final r = analisarListaLocal('leite 2 kg');
    expect(r.itens.single.nome, 'Leite');
    expect(r.itens.single.quantidade, 2);
    expect(r.itens.single.unidade, Unidade.kg);
    expect(r.aviso, isNull);
  });

  test('deve_ler_misto_separado_quando_nome_quantidade_unidade_no_fim', () {
    final r = analisarListaLocal('arroz 1 1/2 kg');
    expect(r.itens.single.nome, 'Arroz');
    expect(r.itens.single.quantidade, 1.5);
    expect(r.itens.single.unidade, Unidade.kg);
  });
}
