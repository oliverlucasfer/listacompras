/// Enum fechado de categorias (doc 01 §3.2, ADR-011) — lista idêntica ao
/// Postgres (`categoria_item`) e ao `responseSchema` da IA (doc 04 §6).
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

  String get rotulo => switch (this) {
    hortifruti => 'Hortifrúti',
    mercearia => 'Mercearia',
    frios => 'Frios',
    laticinios => 'Laticínios',
    congelados => 'Congelados',
    padaria => 'Padaria',
    bebidas => 'Bebidas',
    pet => 'Pet',
    limpeza => 'Limpeza',
    higiene => 'Higiene',
    outros => 'Outros',
  };

  static CategoriaItem fromValor(String valor) {
    for (final c in CategoriaItem.values) {
      if (c.valor == valor) return c;
    }
    throw ArgumentError('Categoria fora do enum fechado: $valor');
  }
}
