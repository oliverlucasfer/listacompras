import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP fake que responde como um PostgREST/GoTrue local
/// (padrão dos testes de sync): registra cada requisição e usa um
/// `responder` configurável por teste.
class ServidorFake implements http.Client {
  ServidorFake(this.responder);

  final (int status, Object corpo) Function(http.BaseRequest requisicao)
  responder;

  final pedidos = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    final resultado = responder(request);
    // PostgREST/GoTrue devolvem sempre JSON — strings são codificadas como
    // JSON string (ex.: RPC que retorna uuid chega entre aspas).
    final bytes = utf8.encode(jsonEncode(resultado.$2));
    return http.StreamedResponse(
      Stream.value(bytes),
      resultado.$1,
      request: request,
      headers: {'content-type': 'application/json'},
      contentLength: bytes.length,
    );
  }

  @override
  void close() {}

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _simples(http.Request('GET', url)..headers.addAll(headers ?? const {}));

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _simples(
    http.Request('POST', url)
      ..headers.addAll(headers ?? const {})
      ..body = '$body',
  );

  Future<http.Response> _simples(http.Request pedido) async {
    final resposta = await send(pedido);
    final bytes = await resposta.stream.toBytes();
    return http.Response.bytes(
      bytes,
      resposta.statusCode,
      request: pedido,
      headers: resposta.headers,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  String corpoDe(int indice) {
    final pedido = pedidos[indice];
    if (pedido is http.Request) return pedido.body;
    return '';
  }
}

http.BaseRequest comMetodo(
  int indice,
  String metodo,
  List<http.BaseRequest> pedidos,
) {
  final pedido = pedidos[indice];
  if (pedido.method != metodo) {
    throw StateError('esperava $metodo, veio ${pedido.method}');
  }
  return pedido;
}
