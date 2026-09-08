import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';

/// F6-T03/F6-T02 (doc 14): enum fechado de categorias (doc 01 §3.2, ADR-011)
/// — mesma lista do Postgres (`categoria_item`) e do `responseSchema` (04).
void main() {
  test('deve_ter_11_valores_na_ordem_dos_grupos_quando_listar_categorias', () {
    final nomes = CategoriaItem.values.map((c) => c.valor).toList();
    expect(nomes, [
      'hortifruti',
      'mercearia',
      'frios',
      'laticinios',
      'congelados',
      'padaria',
      'bebidas',
      'pet',
      'limpeza',
      'higiene',
      'outros',
    ]);
  });

  test('deve_converter_valor_quando_from_valor_valido', () {
    expect(CategoriaItem.fromValor('frios'), CategoriaItem.frios);
    expect(CategoriaItem.fromValor('outros'), CategoriaItem.outros);
  });

  test('deve_rejeitar_valor_fora_do_enum_quando_from_valor', () {
    expect(() => CategoriaItem.fromValor('alimentos'), throwsArgumentError);
  });
}
