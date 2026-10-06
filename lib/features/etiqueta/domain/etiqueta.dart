import '../../listas/domain/preco.dart';

/// Resultado da leitura de uma etiqueta de prateleira (RF-40).
class EtiquetaLida {
  const EtiquetaLida({
    this.nome,
    required this.precoCentavos,
    this.precoPorKgCentavos,
  });

  final String? nome;
  final int precoCentavos;
  final int? precoPorKgCentavos;
}

// Um número monetário: milhar com vírgula, vírgula decimal, ponto decimal
// (até 2 casas) ou inteiro — nesta ordem de precedência.
final _numero = RegExp(
  r'\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+,\d{1,2}|\d+\.\d{1,2}|\d+',
);

// Valor imediatamente após "por" (promo "de X por Y").
final _aposPor = RegExp(
  'por\\s*r?\\\$?\\s*(${_numero.pattern})',
  caseSensitive: false,
);

// Contexto de preço por kg / por 100 g / por unidade (não é o preço do item),
// reconhecido apenas no texto imediatamente APÓS o número — por token, não por
// linha: em "R$ 39,90 R$ 79,80/kg" só o segundo valor é "por kg".
final _contextoKg = RegExp(
  r'^\s*(?:/\s*kg|por\s*kg|por\s*100\s*g|por\s*unidade)',
  caseSensitive: false,
);

// Marcador de moeda imediatamente antes do número (permite espaços).
final _moedaAntes = RegExp(r'r\$\s*$', caseSensitive: false);

// Marcador de moeda no fim do texto do nome (sobra do corte antes do preço).
final _moedaNoFim = RegExp(r'\s*r\$\s*$', caseSensitive: false);

final _letras = RegExp(r'[A-Za-zÀ-ÿ]');
final _simbolos = RegExp(r'[\dR$.,/\-]');
final _porPalavra = RegExp(
  r'(?<![a-zà-ÿ])por(?![a-zà-ÿ])',
  caseSensitive: false,
);
final _kgPalavra = RegExp(r'(?<![a-zà-ÿ])kg(?![a-zà-ÿ])', caseSensitive: false);

/// Extrai preço (preço cheio; valor por kg como fallback) e, best-effort, o
/// nome do produto a partir do texto do OCR. Determinístico e offline.
/// Devolve `null` se nenhum preço for encontrado.
EtiquetaLida? analisarEtiqueta(String texto) {
  final linhas = <String>[
    for (final l in texto.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  final naoKg = <int>[];
  final porKg = <int>[];
  final promocional = <int>[];
  String? nome;

  for (final linha in linhas) {
    for (final m in _numero.allMatches(linha)) {
      final centavos = _centavosSeMonetario(linha, m.start, m.group(0)!);
      if (centavos == null) continue;
      final ehKg = _contextoKg.hasMatch(linha.substring(m.end));
      (ehKg ? porKg : naoKg).add(centavos);
    }
    for (final m in _aposPor.allMatches(linha)) {
      final inicio = m.start + m.group(0)!.indexOf(m.group(1)!);
      final centavos = _centavosSeMonetario(linha, inicio, m.group(1)!);
      if (centavos != null) promocional.add(centavos);
    }
    nome ??= _nomeDaLinha(linha);
  }

  if (promocional.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: promocional.last,
      precoPorKgCentavos: _maior(porKg),
    );
  }
  if (naoKg.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: _maior(naoKg)!,
      precoPorKgCentavos: _maior(porKg),
    );
  }
  if (porKg.isNotEmpty) {
    final preco = _maior(porKg)!;
    return EtiquetaLida(
      nome: nome,
      precoCentavos: preco,
      precoPorKgCentavos: preco,
    );
  }
  return null;
}

int? _centavos(String bruto) {
  try {
    final c = parsePrecoParaCentavos(bruto);
    return (c == null || c <= 0) ? null : c;
  } on ArgumentError {
    return null;
  }
}

/// Só é preço o token precedido de marcador de moeda ('R$') ou com separador
/// decimal; um inteiro solto é quantidade/modelo/peso (ex.: '200g', '50', '5kg').
int? _centavosSeMonetario(String linha, int inicio, String bruto) {
  final temSeparador = bruto.contains(',') || bruto.contains('.');
  final temMoeda = _moedaAntes.hasMatch(linha.substring(0, inicio));
  if (!temSeparador && !temMoeda) return null;
  return _centavos(bruto);
}

int? _maior(List<int> valores) {
  if (valores.isEmpty) return null;
  return valores.reduce((a, b) => a > b ? a : b);
}

/// Nome provável: primeira linha com ≥ 3 letras que não seja preço/promo/kg.
/// Numa linha que mistura nome e preço (ex.: "Queijo R$ 39,90"), o nome é o
/// texto antes do primeiro valor monetário.
String? _nomeDaLinha(String linha) {
  var candidato = linha;
  for (final m in _numero.allMatches(linha)) {
    if (_centavosSeMonetario(linha, m.start, m.group(0)!) == null) continue;
    candidato = linha.substring(0, m.start);
    break;
  }
  candidato = candidato.replaceAll(_moedaNoFim, '').trim();
  if (_porPalavra.hasMatch(candidato) || _kgPalavra.hasMatch(candidato)) {
    return null;
  }
  final letras = _letras.allMatches(candidato.replaceAll(_simbolos, '')).length;
  return letras >= 3 ? candidato : null;
}
