import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

/// Classifica falhas de rede no nativo/desktop (doc 05 §2, ADR-012).
bool ehSemConexao(Object erro) =>
    erro is SocketException ||
    erro is ClientException ||
    erro is TimeoutException;
