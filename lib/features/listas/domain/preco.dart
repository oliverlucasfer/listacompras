import 'item.dart';

/// Formata centavos em Real: 549 -> 'R$ 5,49'. Sem dependência de intl.
String formatarReais(int centavos) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final reais = absoluto ~/ 100;
  final resto = absoluto % 100;
  final texto = 'R\$ ${_milhares(reais)},${resto.toString().padLeft(2, '0')}';
  return negativo ? '-$texto' : texto;
}

String _milhares(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Aceita '5,49', '5.49', '5', 'R$ 1.234,56' e '1.234' (ponto de milhar).
/// Vazio/nulo -> null.
/// Valor não numérico ou negativo -> ArgumentError (a UI mostra erro inline).
int? parsePrecoParaCentavos(String? texto) {
  final bruto = (texto ?? '').replaceAll(RegExp(r'[R$\s]'), '').trim();
  if (bruto.isEmpty) return null;
  final String normalizado;
  if (bruto.contains(',')) {
    normalizado = bruto.replaceAll('.', '').replaceAll(',', '.');
  } else if (bruto.contains('.')) {
    final grupos = bruto.split('.');
    final ultimo = grupos.last;
    normalizado = ultimo.length == 3
        ? grupos.join()
        : '${grupos.sublist(0, grupos.length - 1).join()}.$ultimo';
  } else {
    normalizado = bruto;
  }
  final valor = double.tryParse(normalizado);
  if (valor == null) throw ArgumentError('preço inválido: $texto');
  if (valor < 0) throw ArgumentError('preço negativo: $texto');
  final centavos = (valor * 100).round();
  // Teto do CHECK de `preco_centavos` no Postgres (doc 01 §4.3, RF-21):
  // R$ 999.999,99. Acima disso o flush falharia com check_violation.
  if (centavos > 99999999) throw ArgumentError('preço acima do teto: $texto');
  return centavos;
}

/// Total dos itens **marcados** com preço; cada subtotal arredonda ao centavo.
int totalCarrinho(Iterable<Item> itens) {
  var total = 0;
  for (final item in itens) {
    final preco = item.precoCentavos;
    if (!item.concluido || preco == null) continue;
    total += (item.quantidade * preco).round();
  }
  return total;
}
