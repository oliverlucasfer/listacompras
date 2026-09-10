import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../drift/database.dart';
import '../../convites/data/papel_realtime.dart';
import '../../convites/data/papel_repository.dart';
import 'aplicador_remoto.dart';
import 'supabase_sync_remoto.dart';
import 'sync_engine.dart';

/// Bootstrap e manutenção do cache local (doc 03 §7, F4-T06):
/// - **Troca de usuário/logout:** flush final (melhor esforço) → limpa
///   cache + fila → baixa tudo do novo usuário (multi-conta isolada). O
///   último usuário fica em SharedPreferences para a fila sobreviver ao
///   restart sem limpeza indevida (checklist 03 §8);
/// - **Reconexão:** re-sync completo (download com LWW) + flush da fila;
/// - **Realtime:** eventos INSERT/UPDATE aplicados no Drift imediatamente
///   se vencerem no LWW (< 1s na UI via Streams). DELETE físico é ignorado
///   — exclusão no domínio é soft delete (tombstone chega como UPDATE).
class SupabaseBootstrap {
  SupabaseBootstrap({
    required this._db,
    required this._engine,
    required this._client,
    this._mudancasDeUsuario,
    this._conectividade,
    this._checarConexao,
    Future<String?> Function()? lerUsuarioSalvo,
    Future<void> Function(String? usuarioId)? salvarUsuario,
    Future<List<Map<String, Object?>>> Function(String tabela)? baixar,
    this._papelRepository,
    this._onPerdaAcesso,
  }) : _lerUsuarioSalvo = lerUsuarioSalvo ?? _lerSharedPreferences,
       _salvarUsuario = salvarUsuario ?? _gravarSharedPreferences {
    _baixar = baixar ?? _baixarDoSupabase;
    _aplicador = AplicadorRemoto(_db);
  }

  static const _nomeCanal = 'sync-listas';

  final AppDatabase _db;
  final SyncEngine _engine;
  final SupabaseClient _client;
  final Stream<String?>? _mudancasDeUsuario;
  final Stream<List<ConnectivityResult>>? _conectividade;
  final Future<bool> Function()? _checarConexao;
  final Future<String?> Function() _lerUsuarioSalvo;
  final Future<void> Function(String? usuarioId) _salvarUsuario;

  late final AplicadorRemoto _aplicador;
  late Future<List<Map<String, Object?>>> Function(String tabela) _baixar;
  final PapelRepository? _papelRepository;
  final void Function()? _onPerdaAcesso;

  String? _usuarioAtual;
  RealtimeChannel? _canal;
  StreamSubscription<String?>? _subUsuario;
  StreamSubscription<List<ConnectivityResult>>? _subConectividade;
  Future<void> _ultimoTrabalho = Future.value();

  Future<void> iniciar() async {
    final salvo = await _lerUsuarioSalvo();
    _usuarioAtual = (salvo == null || salvo.isEmpty) ? null : salvo;
    final eventos =
        _mudancasDeUsuario ??
        _client.auth.onAuthStateChange.map((estado) => estado.session?.user.id);
    _subUsuario = eventos.listen((id) => _encadear(() => _aoMudarUsuario(id)));
    _subConectividade = _conectividade?.listen((resultados) {
      if (resultados.any((r) => r != ConnectivityResult.none)) {
        _encadear(_reSincronizar);
      }
    });
    if (_usuarioAtual != null) {
      await _assinarRealtime();
      _encadear(_reSincronizar);
    }
  }

  /// Aplica um registro remoto no Drift somente se vencer no LWW
  /// (doc 03 §5) — usado pelo Realtime e pelo re-sync completo.
  Future<void> aplicarRemoto(
    String tabela,
    Map<String, Object?> registro,
  ) async {
    final id = registro['id'];
    final remotoTs = _parseTs(registro['updated_at']);
    if (id is! String || remotoTs == null) return;
    final localTs = await _atualizadoLocal(tabela, id);
    if (localTs == null || remotoVenceNoLww(remotoTs, localTs)) {
      await _aplicador.aplicar(tabela, registro);
    }
  }

  /// Re-sync completo (doc 03 §7): carrega os papéis do usuário, baixa as
  /// linhas visíveis (RLS), aplica as vencedoras no LWW e drena a fila.
  Future<void> sincronizarTudo() async {
    final usuario = _usuarioAtual;
    final papel = _papelRepository;
    if (papel != null && usuario != null) {
      try {
        await papel.carregar(usuario);
      } on Exception {
        // Papel é secundário (doc 03 §7): falha de rede/PostgREST não
        // pode abortar o download de listas/itens nem o flush da fila.
      }
    }
    for (final tabela in const ['listas', 'itens_lista']) {
      final registros = await _baixar(tabela);
      for (final registro in registros) {
        await aplicarRemoto(tabela, registro);
      }
    }
    await _engine.flush();
  }

  Future<void> dispose() async {
    await _subUsuario?.cancel();
    await _subConectividade?.cancel();
    await _desassinarRealtime();
  }

  // ---- Internos ----

  /// Perda de acesso (doc 08 §9): limpa o cache da conta (o papel do
  /// usuário some com o repositorio) e re-baixa as listas visíveis —
  /// com o RLS já sem acesso, a lista removida desaparece (< 5s).
  void _perderAcessoPadrao() {
    _encadear(() async {
      await _limparCache();
      await sincronizarTudo();
    });
  }

  /// Serializa trabalhos (troca de usuário, re-sync, realtime) para evitar
  /// corridas entre download e aplicação de eventos.
  void _encadear(Future<void> Function() trabalho) {
    _ultimoTrabalho = _ultimoTrabalho.then((_) => trabalho());
  }

  Future<void> _reSincronizar() async {
    if (_usuarioAtual == null) return;
    final checar = _checarConexao;
    if (checar != null && !await checar()) return;
    await sincronizarTudo();
  }

  Future<void> _aoMudarUsuario(String? novoId) async {
    if (novoId == _usuarioAtual) return;
    if (_usuarioAtual != null) {
      await _desassinarRealtime();
      try {
        await _engine.flush(); // flush final antes de limpar (doc 03 §7)
      } on Exception {
        // Offline: a fila é descartada junto com o cache da conta antiga.
      }
    }
    await _limparCache();
    _usuarioAtual = novoId;
    await _salvarUsuario(novoId);
    if (novoId != null) {
      await _assinarRealtime();
      await _reSincronizar();
    }
  }

  Future<void> _limparCache() async {
    await _db.delete(_db.itemLocal).go();
    await _db.delete(_db.listaLocal).go();
    await _db.delete(_db.mutacaoPendente).go();
    _papelRepository?.limpar();
  }

  Future<void> _assinarRealtime() async {
    await _desassinarRealtime();
    _canal = _client.channel(_nomeCanal)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: (payload) {
          if (payload.table == 'lista_membros') {
            // Eventos de membros não passam por aplicarRemoto (sem
            // updated_at): handler dedicado (doc 08 §7, F7-T06).
            final perdaAcesso = _onPerdaAcesso ?? _perderAcessoPadrao;
            _encadear(
              () async => aplicarEventoMembro(
                usuarioAtual: _usuarioAtual,
                payload: payload,
                papelRepository: _papelRepository,
                onPerdaAcesso: perdaAcesso,
              ),
            );
            return;
          }
          final registro = payload.newRecord;
          if (registro.isEmpty) return;
          _encadear(() => aplicarRemoto(payload.table, registro));
        },
      )
      ..subscribe();
  }

  Future<void> _desassinarRealtime() async {
    final canal = _canal;
    if (canal == null) return;
    _canal = null;
    try {
      await _client.removeChannel(canal);
    } on Exception {
      // Canal pode já estar fechado (logout, socket encerrado).
    }
  }

  Future<DateTime?> _atualizadoLocal(String tabela, String id) async {
    return switch (tabela) {
      'listas' => (await (_db.select(
        _db.listaLocal,
      )..where((l) => l.id.equals(id))).getSingleOrNull())?.updatedAt,
      'itens_lista' => (await (_db.select(
        _db.itemLocal,
      )..where((i) => i.id.equals(id))).getSingleOrNull())?.updatedAt,
      _ => null,
    };
  }

  Future<List<Map<String, Object?>>> _baixarDoSupabase(String tabela) async {
    final linhas = await _client.from(tabela).select();
    return [
      for (final linha in linhas as List)
        Map<String, Object?>.from(linha as Map),
    ];
  }

  static DateTime? _parseTs(Object? iso) =>
      iso is String ? DateTime.tryParse(iso) : null;

  static Future<String?> _lerSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sync.usuario_id');
  }

  static Future<void> _gravarSharedPreferences(String? usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    if (usuarioId == null || usuarioId.isEmpty) {
      await prefs.remove('sync.usuario_id');
    } else {
      await prefs.setString('sync.usuario_id', usuarioId);
    }
  }
}
