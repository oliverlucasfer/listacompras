import 'dart:convert';

import '../../../core/dominio/quantidade.dart';
import 'lista_compartilhada.dart';

String codificarLista(ListaCompartilhada lista) {
  final json = jsonEncode(lista.toJson());
  return ListaCompartilhada.prefixo + base64Url.encode(utf8.encode(json));
}

ListaCompartilhada decodificarLista(String codigo) {
  final texto = codigo.trim();
  if (!texto.startsWith(ListaCompartilhada.prefixo)) {
    throw const CompartilhamentoInvalidoException('Código inválido.');
  }
  final corpo = texto.substring(ListaCompartilhada.prefixo.length);
  try {
    final mapa = jsonDecode(utf8.decode(base64Url.decode(corpo)));
    return ListaCompartilhada.fromJson((mapa as Map).cast<String, dynamic>());
  } on CompartilhamentoInvalidoException {
    rethrow;
  } catch (_) {
    throw const CompartilhamentoInvalidoException('Código inválido.');
  }
}

String gerarTextoLista(ListaCompartilhada lista) => [
  for (final i in lista.itens)
    '${formatarQuantidade(i.quantidade)} ${i.unidade.valor} ${i.nome}',
].join('\n');
