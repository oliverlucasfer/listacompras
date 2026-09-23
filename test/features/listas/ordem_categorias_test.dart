import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/features/listas/domain/ordem_categorias.dart';

void main() {
  test('deve_normalizar_quando_faltam_categorias', () {
    final ordem = normalizarOrdem([CategoriaItem.bebidas, CategoriaItem.frios]);
    expect(ordem.length, CategoriaItem.values.length);
    expect(ordem.take(2).toList(), [
      CategoriaItem.bebidas,
      CategoriaItem.frios,
    ]);
    expect(ordem.toSet(), CategoriaItem.values.toSet());
  });

  test('deve_ignorar_desconhecidas_quando_desserializar', () {
    final ordem = desserializarOrdem('bebidas,inexistente,frios');
    expect(ordem.take(2).toList(), [
      CategoriaItem.bebidas,
      CategoriaItem.frios,
    ]);
    expect(ordem.length, CategoriaItem.values.length);
  });

  test('deve_serializar_e_desserializar_round_trip_quando_ordem_valida', () {
    final ordem = normalizarOrdem([
      CategoriaItem.higiene,
      ...CategoriaItem.values.where((c) => c != CategoriaItem.higiene),
    ]);
    expect(desserializarOrdem(serializarOrdem(ordem)), ordem);
  });

  test('deve_retornar_padrao_quando_csv_nulo_ou_vazio', () {
    expect(desserializarOrdem(null), CategoriaItem.values);
    expect(desserializarOrdem(''), CategoriaItem.values);
    expect(desserializarOrdem('   '), CategoriaItem.values);
  });

  test('deve_mover_quando_moverItem', () {
    // newIndex segue o contrato do onReorder do ReorderableListView: descer o
    // item 0 para depois do item 1 chega como newIndex == 2 e é decrementado.
    expect(moverItem([1, 2, 3], 0, 2), [2, 1, 3]); // desce
    expect(moverItem([1, 2, 3], 2, 0), [3, 1, 2]); // sobe
  });

  test('deve_manter_ordem_quando_moverItem_mesmo_indice', () {
    expect(moverItem([1, 2, 3], 1, 1), [1, 2, 3]);
  });

  test('deve_mover_para_o_fim_quando_moverItem_newIndex_final', () {
    expect(moverItem([1, 2, 3], 0, 3), [2, 3, 1]);
  });

  test('deve_converter_indice_do_onReorderItem_quando_desce', () {
    // onReorderItem entrega o índice final já ajustado (0→1 = desceu 1).
    expect(indiceCruDeReordenacao(0, 1), 2);
  });

  test('deve_converter_indice_do_onReorderItem_quando_sobe', () {
    expect(indiceCruDeReordenacao(2, 0), 0);
  });

  test('deve_converter_indice_do_onReorderItem_quando_mesma_posicao', () {
    expect(indiceCruDeReordenacao(1, 1), 1);
  });
}
