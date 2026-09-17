import 'dart:async';

import 'package:http/http.dart' show ClientException;

/// Classifica falhas de rede no web (sem `dart:io`) — doc 05 §2, ADR-012.
bool ehSemConexao(Object erro) =>
    erro is ClientException || erro is TimeoutException;
