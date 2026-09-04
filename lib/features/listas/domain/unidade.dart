/// Enum fechado de unidades (doc 01 §3, ADR-005) — lista idêntica ao
/// Postgres (`unidade_item`) e ao `responseSchema` da IA (doc 04 §6).
enum Unidade {
  un('un'),
  kg('kg'),
  g('g'),
  l('l'),
  ml('ml'),
  caixa('caixa'),
  pacote('pacote'),
  pct('pct'),
  dz('dz');

  const Unidade(this.valor);

  final String valor;

  static Unidade fromValor(String valor) {
    for (final u in Unidade.values) {
      if (u.valor == valor) return u;
    }
    throw ArgumentError('Unidade fora do enum fechado: $valor');
  }
}
