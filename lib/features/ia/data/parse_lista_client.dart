import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/supabase_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../listas/domain/categoria.dart';
import '../../listas/domain/unidade.dart';
import '../domain/resposta_parse.dart';

/// Cliente HTTP do Edge Function `parse-lista` (doc 04 §2, RF-06): POST com
/// JWT do usuário; erros do contrato viram `ErroIa` com mensagem amigável —
/// a UI nunca bloqueia e nunca vê JSON bruto.
class ParseListaClient {
  ParseListaClient({
    required this.obterToken,
    required this.obterUri,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client();

  /// JWT atual da sessão; null/ vazio → erro `unauthorized` sem chamada.
  final String? Function() obterToken;

  final Uri Function() obterUri;

  final http.Client _httpClient;

  /// Segurança de rede: o servidor mapeia > 15s para `timeout_ia`
  /// (doc 04 §3); aqui cortamos requisições que nunca respondem.
  final Duration timeout;

  Future<RespostaParse> parse(String texto) async {
    final token = obterToken();
    if (token == null || token.isEmpty) {
      throw const ErroIa('unauthorized', AppStrings.iaSessaoExpirada);
    }
    final http.Response resposta;
    try {
      resposta = await _httpClient
          .post(
            obterUri(),
            headers: {
              'Authorization': 'Bearer $token',
              'apikey': supabaseAnonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'texto': texto}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ErroIa('timeout_ia', AppStrings.iaTimeoutIa);
    } catch (_) {
      // Offline/DNS/servidor inalcançável — fora do contrato HTTP (doc 04 §2).
      throw const ErroIa('sem_conexao', AppStrings.iaSemConexao);
    }

    final corpo = _decodificar(resposta.body);

    if (resposta.statusCode == 200) {
      return _interpretarSucesso(corpo);
    }
    if (corpo is Map && corpo['code'] is String) {
      final code = corpo['code'] as String;
      final message = corpo['message'];
      throw ErroIa(
        code,
        message is String && message.isNotEmpty
            ? message
            : mensagemContratoIa(code),
      );
    }
    // Corpo fora do contrato (ex.: 401 do gateway) — mapeia pelo status.
    throw switch (resposta.statusCode) {
      401 => const ErroIa('unauthorized', AppStrings.iaSessaoExpirada),
      504 => const ErroIa('timeout_ia', AppStrings.iaTimeoutIa),
      _ => const ErroIa('erro_interno', AppStrings.iaErroInterno),
    };
  }

  dynamic _decodificar(String corpo) {
    try {
      return jsonDecode(corpo);
    } catch (_) {
      return null;
    }
  }

  /// Interpretar 200 fora do schema (unidade fora do enum, tipos errados)
  /// vira `resposta_invalida` — nunca vaza JSON bruto (doc 04 §9).
  RespostaParse _interpretarSucesso(dynamic corpo) {
    if (corpo is! Map || corpo['itens'] is! List) {
      throw const ErroIa('resposta_invalida', AppStrings.iaRespostaInvalida);
    }
    try {
      final itens = [
        for (final e in corpo['itens'] as List)
          ItemExtraido(
            nome: (e as Map)['nome'] as String,
            quantidade: _quantidadeValida(e['quantidade']),
            unidade: Unidade.fromValor(e['unidade'] as String),
            // Tolerância (spec F6 §7): function antiga sem categoria →
            // outros; campo extra é ignorado implicitamente.
            categoria: e['categoria'] == null
                ? CategoriaItem.outros
                : CategoriaItem.fromValor(e['categoria'] as String),
          ),
      ];
      final aviso = corpo['aviso'];
      return RespostaParse(
        itens: itens,
        aviso: aviso is String && aviso.isNotEmpty ? aviso : null,
      );
    } catch (_) {
      throw const ErroIa('resposta_invalida', AppStrings.iaRespostaInvalida);
    }
  }

  double _quantidadeValida(Object? valor) {
    final quantidade = (valor as num).toDouble();
    if (quantidade <= 0) {
      throw ArgumentError('quantidade deve ser maior que zero');
    }
    return quantidade;
  }
}
