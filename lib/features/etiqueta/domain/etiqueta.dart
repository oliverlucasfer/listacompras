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

// Contexto de preço por kg / por 100 g / por unidade (não é o preço do item).
final _contextoKg = RegExp(
  r'(r\s*\$\s*/?\s*kg|/\s*kg|por\s*kg|por\s*100\s*g|por\s*unidade)',
  caseSensitive: false,
);

final _letras = RegExp(r'[A-Za-zÀ-ÿ]');
final _simbolos = RegExp(r'[\dR$.,/\-]');

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
    final ehKg = _contextoKg.hasMatch(linha);
    for (final m in _numero.allMatches(linha)) {
      final centavos = _centavos(m.group(0)!);
      if (centavos == null) continue;
      (ehKg ? porKg : naoKg).add(centavos);
    }
    for (final m in _aposPor.allMatches(linha)) {
      final centavos = _centavos(m.group(1)!);
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

int? _maior(List<int> valores) {
  if (valores.isEmpty) return null;
  return valores.reduce((a, b) => a > b ? a : b);
}

/// Nome provável: primeira linha com ≥ 3 letras que não seja preço/promo/kg.
String? _nomeDaLinha(String linha) {
  final lower = linha.toLowerCase();
  if (lower.contains(r'r$') || lower.contains('por') || lower.contains('kg')) {
    return null;
  }
  final letras = _letras.allMatches(linha.replaceAll(_simbolos, '')).length;
  return letras >= 3 ? linha : null;
}
