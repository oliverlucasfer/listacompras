import 'item.dart';
import 'orcamento.dart';

/// Formata centavos em Real: 549 -> 'R$ 5,49'. Sem dependência de intl.
String formatarReais(int centavos) {
  final negativo = centavos < 0;
  final absoluto = centavos.abs();
  final reais = absoluto ~/ 100;
  final resto = absoluto % 100;
  final texto = 'R\$ ${_milhares(reais)},${resto.toString().padLeft(2, '0')}';
  return negativo ? '-$texto' : texto;
}

/// Formata centavos para campo de edição, sem símbolo de moeda: 549 -> '5,49'.
String centavosParaTexto(int centavos) =>
    (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');

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
  // `double.tryParse` aceita 'NaN'/'Infinity'/notação científica que estoura
  // ('1e400'); sem o `isFinite`, o `.round()` abaixo lançaria `UnsupportedError`
  // em vez do `ArgumentError` que todo call site captura.
  if (valor == null || !valor.isFinite) {
    throw ArgumentError('preço inválido: $texto');
  }
  if (valor < 0) throw ArgumentError('preço negativo: $texto');
  final centavos = (valor * 100).round();
  // Teto de `preco_centavos` (RF-21): R$ 999.999,99 — igual ao CHECK
  // das tabelas locais. Acima disso a escrita falharia com check_violation.
  if (centavos > 99999999) throw ArgumentError('preço acima do teto: $texto');
  return centavos;
}

/// Total dos itens **marcados** com preço; cada subtotal arredonda ao centavo.
int totalCarrinho(Iterable<Item> itens) {
  var total = 0;
  for (final item in itens) {
    if (!item.concluido) continue;
    total += subtotalMarcado(item);
  }
  return total;
}
