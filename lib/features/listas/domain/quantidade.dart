/// Glifos de fração aceitos/exibidos (½ ¼ ¾ ⅓ ⅔).
const glifosFracao = '½¼¾⅓⅔';

final Map<double, String> _glifos = {
  0.25: '¼',
  0.5: '½',
  0.75: '¾',
  1 / 3: '⅓',
  2 / 3: '⅔',
};

/// Interpreta uma quantidade: decimal pt-BR (`2`, `1,5`, `1.5`), fração
/// simples (`1/2`), glifo (`½`) ou mista colada (`1½`). Processa **um token**
/// (o misto espaçado, `1 1/2`, é combinado pelo parser). `null` se não for
/// quantidade ou for inválida (negativa, não finita, denominador 0).
double? parseQuantidade(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return null;

  for (final e in _glifos.entries) {
    final i = t.indexOf(e.value);
    if (i < 0) continue;
    if (t.indexOf(e.value, i + e.value.length) >= 0) return null; // >1 glifo
    final prefixo = t.substring(0, i).trim();
    final sufixo = t.substring(i + e.value.length).trim();
    if (sufixo.isNotEmpty) return null;
    final inteiro = prefixo.isEmpty
        ? 0.0
        : double.tryParse(prefixo.replaceAll(',', '.'));
    if (inteiro == null || !inteiro.isFinite || inteiro < 0) return null;
    return inteiro + e.key;
  }

  final fracao = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(t);
  if (fracao != null) {
    final numerador = int.tryParse(fracao.group(1)!);
    final denominador = int.tryParse(fracao.group(2)!);
    if (numerador == null || denominador == null || denominador == 0) {
      return null;
    }
    return numerador / denominador;
  }

  final valor = double.tryParse(t.replaceAll(',', '.'));
  if (valor == null || !valor.isFinite || valor < 0) return null;
  return valor;
}

/// Formata para exibição: inteiro → `2`; parte fracionária que casa um glifo
/// comum (½ ¼ ¾ ⅓ ⅔, com tolerância) → misto (`1½`, `1¼`, `2⅓`); senão
/// arredonda para ≤ 3 casas e corta zeros (`1.2`, `0.143`).
String formatarQuantidade(double q) {
  if (!q.isFinite) return q.toString();
  if (q == q.roundToDouble()) return q.toInt().toString();
  final inteiro = q.truncate();
  final fracao = q - inteiro;
  for (final e in _glifos.entries) {
    if ((fracao - e.key).abs() < 0.001) {
      return inteiro == 0 ? e.value : '$inteiro${e.value}';
    }
  }
  var texto = q.toStringAsFixed(3);
  texto = texto.replaceFirst(RegExp(r'0+$'), '');
  texto = texto.replaceFirst(RegExp(r'\.$'), '');
  return texto;
}
