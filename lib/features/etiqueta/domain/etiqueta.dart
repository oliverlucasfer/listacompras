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

// Unidade de massa/volume **colada** logo após o número (ex.: "1,5kg", "0,5 l"):
// é peso/quantidade, não preço. Diferente de "/kg"/"por kg" (preço por unidade).
// O `\d*` cobre pesos com 3 casas ("0,750kg"), cujo excesso de casas escapa do
// padrão de preço (2 casas) e sobra como dígitos antes da unidade.
final _pesoApos = RegExp(r'^\s*\d*\s*(?:kg|g|ml|l)\b', caseSensitive: false);

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

  final naoKg = <_Candidato>[];
  final porKg = <_Candidato>[];
  final promocional = <_Candidato>[];
  String? nome;

  for (var i = 0; i < linhas.length; i++) {
    final linha = linhas[i];
    for (final m in _numero.allMatches(linha)) {
      final bruto = m.group(0)!;
      final centavos = _centavosSeMonetario(linha, m.start, bruto);
      if (centavos == null) continue;
      // O marcador "/kg" pode cair na **linha seguinte**: a etiqueta quebra
      // "R$ 55,63" e "/kg" em linhas separadas.
      final depois = linha.substring(m.end);
      final contexto = depois.trim().isEmpty && i + 1 < linhas.length
          ? ' ${linhas[i + 1]}'
          : depois;
      // Peso/volume colado (ex.: "1,5kg") não é preço nem preço por unidade.
      // Só vale na **mesma linha**: um "5kg" solto na linha de baixo é o peso
      // do produto, não o sufixo do valor acima.
      if (_pesoApos.hasMatch(depois)) continue;
      final cand = _Candidato(centavos, _pesoDoValor(linha, m.start, bruto));
      (_contextoKg.hasMatch(contexto) ? porKg : naoKg).add(cand);
    }
    for (final m in _aposPor.allMatches(linha)) {
      final inicio = m.start + m.group(0)!.indexOf(m.group(1)!);
      final bruto = m.group(1)!;
      final centavos = _centavosSeMonetario(linha, inicio, bruto);
      if (centavos != null) {
        promocional.add(
          _Candidato(centavos, _pesoDoValor(linha, inicio, bruto)),
        );
      }
    }
    nome ??= _nomeDaLinha(linha);
  }

  // Só os candidatos mais fortes de cada grupo contam como preço. Assim um
  // código de produto lido como `111.26` (só ponto) não vence um `R$ 2,79`.
  final naoKgCentavos = _maisFortes(naoKg);
  final porKgCentavos = _maisFortes(porKg);
  final promocionalCentavos = _maisFortes(promocional);

  if (promocionalCentavos.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: promocionalCentavos.last,
      precoPorKgCentavos: _maior(porKgCentavos),
    );
  }
  if (naoKgCentavos.isNotEmpty) {
    return EtiquetaLida(
      nome: nome,
      precoCentavos: _maior(naoKgCentavos)!,
      precoPorKgCentavos: _maior(porKgCentavos),
    );
  }
  if (porKgCentavos.isNotEmpty) {
    final preco = _maior(porKgCentavos)!;
    return EtiquetaLida(
      nome: nome,
      precoCentavos: preco,
      precoPorKgCentavos: preco,
    );
  }
  return null;
}

/// Um valor monetário candidato e sua "força" como preço (ver [_pesoDoValor]).
class _Candidato {
  const _Candidato(this.centavos, this.peso);
  final int centavos;
  final int peso;
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

/// Força do valor como preço do item: `3` = precedido de `R$`; `2` = decimal
/// com vírgula (padrão pt-BR); `1` = decimal só com ponto — ambíguo, pode ser
/// um código de produto (ex.: `111.26`). Candidatos mais fortes têm prioridade.
int _pesoDoValor(String linha, int inicio, String bruto) {
  if (_moedaAntes.hasMatch(linha.substring(0, inicio))) return 3;
  if (bruto.contains(',')) return 2;
  return 1;
}

/// Mantém apenas os candidatos de maior força, preservando a ordem original.
List<int> _maisFortes(List<_Candidato> candidatos) {
  if (candidatos.isEmpty) return const [];
  final maxPeso = candidatos.map((c) => c.peso).reduce((a, b) => a > b ? a : b);
  return [
    for (final c in candidatos)
      if (c.peso == maxPeso) c.centavos,
  ];
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
  // Linha com peso/volume colado (ex.: "1,5kg") não é nome de produto.
  for (final m in _numero.allMatches(linha)) {
    if (_pesoApos.hasMatch(linha.substring(m.end))) return null;
  }
  if (_porPalavra.hasMatch(candidato) || _kgPalavra.hasMatch(candidato)) {
    return null;
  }
  final letras = _letras.allMatches(candidato.replaceAll(_simbolos, '')).length;
  return letras >= 3 ? candidato : null;
}
