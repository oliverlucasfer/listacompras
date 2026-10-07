/// Enum fechado de categorias (doc 13 §3, ADR-011).
/// A ordem dos valores define a ordem dos grupos na UI (doc 05 §6.3).
enum CategoriaItem {
  hortifruti('hortifruti'),
  mercearia('mercearia'),
  frios('frios'),
  laticinios('laticinios'),
  congelados('congelados'),
  padaria('padaria'),
  bebidas('bebidas'),
  pet('pet'),
  limpeza('limpeza'),
  higiene('higiene'),
  outros('outros');

  const CategoriaItem(this.valor);

  final String valor;

  static CategoriaItem fromValor(String valor) {
    for (final c in CategoriaItem.values) {
      if (c.valor == valor) return c;
    }
    throw ArgumentError('Categoria fora do enum fechado: $valor');
  }
}
