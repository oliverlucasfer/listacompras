import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:lista_compras/core/rede/erro_rede.dart';

void main() {
  test('deve_ser_sem_conexao_quando_socket_exception', () {
    expect(ehSemConexao(const SocketException('off')), isTrue);
  });

  test('deve_ser_sem_conexao_quando_client_exception', () {
    expect(ehSemConexao(ClientException('x')), isTrue);
  });

  test('deve_ser_sem_conexao_quando_timeout', () {
    expect(ehSemConexao(TimeoutException('x')), isTrue);
  });

  test('deve_nao_ser_sem_conexao_quando_outro_erro', () {
    expect(ehSemConexao(const FormatException('x')), isFalse);
  });
}
