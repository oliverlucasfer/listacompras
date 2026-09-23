import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notificacoes_push.dart';
import 'push_tokens_repository.dart';

class NotificacoesService {
  NotificacoesService({
    required this._push,
    required this._repositorio,
    required this._plataforma,
  });

  static const _chaveAtivas = 'push_ativas';
  static const _chavePedido = 'push_pedido';

  final NotificacoesPush _push;
  final PushTokensRepository _repositorio;
  final String _plataforma;

  Future<bool> ativas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chaveAtivas) ?? false;
  }

  /// Pede a permissão uma única vez, no primeiro momento relevante.
  Future<bool> talvezPedirPermissao() async {
    if (!_push.suportado) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_chavePedido) ?? false) return false;
    final PermissaoPush permissao;
    try {
      permissao = await _push.pedirPermissao();
    } on Exception {
      return false; // não consome o pedido; tenta de novo depois
    }
    await prefs.setBool(_chavePedido, true);
    if (permissao != PermissaoPush.concedida) return false;
    await prefs.setBool(_chaveAtivas, true);
    await _registrarToken();
    return true;
  }

  Future<bool> definirAtivas(bool ativas) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ativas) {
      await prefs.setBool(_chaveAtivas, false);
      final token = await _obterToken();
      if (token != null) await _removerToken(token);
      await _apagarToken();
      return false;
    }
    if (await _pedirPermissao() != PermissaoPush.concedida) {
      await prefs.setBool(_chaveAtivas, false);
      return false;
    }
    await prefs.setBool(_chaveAtivas, true);
    await _registrarToken();
    return true;
  }

  /// No refresh do token do FCM: reafirma o token atual no servidor.
  Future<void> registrarToken(String token) async {
    if (!_push.suportado) return;
    try {
      await _repositorio.registrar(token: token, plataforma: _plataforma);
    } on Exception {
      // Best-effort.
    }
  }

  /// No start do app logado: reafirma o token do dispositivo (idempotente).
  Future<void> registrarSeAtivo() async {
    if (!_push.suportado) return;
    if (!await ativas()) return;
    await _registrarToken();
  }

  Future<void> aoSair() async {
    final token = await _obterToken();
    if (token != null) await _removerToken(token);
    await _apagarToken();
  }

  Future<PermissaoPush> _pedirPermissao() async {
    try {
      return await _push.pedirPermissao();
    } on Exception {
      return PermissaoPush.negada;
    }
  }

  Future<String?> _obterToken() async {
    try {
      return await _push.obterToken();
    } on Exception {
      return null;
    }
  }

  Future<void> _apagarToken() async {
    try {
      await _push.apagarToken();
    } on Exception {
      // Best-effort (offline/sem plugin): a UI nunca bloqueia por push.
    }
  }

  Future<void> _registrarToken() async {
    final token = await _obterToken();
    if (token == null) return;
    try {
      await _repositorio.registrar(token: token, plataforma: _plataforma);
    } on Exception {
      // Best-effort (offline): o próximo start/refresh reafirma.
    }
  }

  Future<void> _removerToken(String token) async {
    try {
      await _repositorio.remover(token);
    } on Exception {
      // Best-effort (offline).
    }
  }
}
