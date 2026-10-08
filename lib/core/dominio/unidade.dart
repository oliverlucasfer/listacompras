/// Enum fechado de unidades (doc 13 §3, ADR-005).
enum Unidade {
  un('un'),
  kg('kg'),
  g('g'),
  l('l'),
  ml('ml'),
  caixa('caixa'),
  pacote('pacote'),
  pct('pct'),
  pt('pt'),
  dz('dz'),
  bandeja('bdj'),
  saco('sc'),
  fardo('fd'),
  garrafa('grf'),
  cento('ct'),
  cacho('cc'),
  mao('mh'),
  pe('pe'),
  cabeca('cb'),
  maco('mc'),
  ramo('rm'),
  lata('lt'),
  vidro('vd'),
  sache('sch'),
  rolo('rl'),
  barra('br'),
  bisnaga('bsg'),
  galao('gl');

  const Unidade(this.valor);

  final String valor;

  static Unidade fromValor(String valor) {
    for (final u in Unidade.values) {
      if (u.valor == valor) return u;
    }
    throw ArgumentError('Unidade fora do enum fechado: $valor');
  }
}
