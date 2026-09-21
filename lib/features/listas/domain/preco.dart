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

/// Aceita '5,49', '5.49', '5', 'R$ 1.234,56'. Vazio/nulo -> null.
/// Valor não numérico ou negativo -> ArgumentError (a UI mostra erro inline).
int? parsePrecoParaCentavos(String? texto) {
  final bruto = (texto ?? '').replaceAll(RegExp(r'[R$\s]'), '').trim();
  if (bruto.isEmpty) return null;
  final normalizado = bruto.contains(',')
      ? bruto.replaceAll('.', '').replaceAll(',', '.')
      : bruto;
  final valor = double.tryParse(normalizado);
  if (valor == null) throw ArgumentError('preço inválido: $texto');
  if (valor < 0) throw ArgumentError('preço negativo: $texto');
  return (valor * 100).round();
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
