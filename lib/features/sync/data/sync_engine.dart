import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../../../drift/database.dart';
import '../domain/sync_status.dart';
import 'aplicador_remoto.dart';
import 'mutacao_sync.dart';
import 'sync_remoto.dart';

/// Sync Engine (doc 03 §3–4, RF-08, F4-T03): drena a fila por lista, em
/// ordem, com coalescing (última mutação por registro), envia ao Supabase e
/// aplica retry com backoff exponencial (1s → 2s → 4s → ... → máx. 5 min).
/// Após [maxTentativas] falhas a mutação entra em estado `ErroSync` até
/// "tentar de novo" ([reiniciarTentativas]). Cair a rede no meio do flush
/// pausa sem queimar tentativas — a reconexão dispara novo flush.
class SyncEngine {
  SyncEngine({
    required this._db,
    required this._remoto,
    AplicadorRemoto? aplicador,
    this._conectividade,
    this._checarConexao,
    Future<void> Function(Duration)? esperar,
    this.maxTentativas = 10,
    this._reportar,
  }) : _esperar = esperar ?? ((espera) => Future<void>.delayed(espera)) {
    _aplicador = aplicador ?? AplicadorRemoto(_db);
  }
  static const _backoffMaximoSegundos = 300; // 5 min (doc 03 §3)

  final AppDatabase _db;
  final SyncRemoto _remoto;
  late final AplicadorRemoto _aplicador;
  final Stream<List<ConnectivityResult>>? _conectividade;
  final Future<bool> Function()? _checarConexao;
  final Future<void> Function(Duration) _esperar;

  /// Relatórios de observabilidade (doc 07 §4, RF-12): códigos e contagens
  /// apenas — nunca conteúdo de listas.
  final void Function(String codigo, Map<String, Object?> contexto)? _reportar;

  final int maxTentativas;

  bool _online = true;
  Future<void>? _flushAtual;
  bool _reagendado = false;
  bool _falhou = false;
  bool _disposed = false;
  SyncStatus _atual = const Sincronizado();
  StreamSubscription<List<MutacaoPendenteData>>? _subFila;
  StreamSubscription<List<ConnectivityResult>>? _subConectividade;

  final _statusController = StreamController<SyncStatus>.broadcast();

  SyncStatus get statusAtual => _atual;
  Stream<SyncStatus> get status => _statusController.stream;

  /// Liga os gatilhos: fila de mutações e conectividade (doc 03 §4).
  Future<void> iniciar() async {
    if (_checarConexao != null) {
      _online = await _checarConexao();
      if (!_online) _definir(const Offline());
    }
    // Cada escrita do repositório enfileira uma mutação → dispara flush.
    _subFila = _db
        .select(_db.mutacaoPendente)
        .watch()
        .listen((_) => unawaited(flush()));
    _subConectividade = _conectividade?.listen(_aoMudarConectividade);
  }

  /// Drena a fila inteira (pseudo-código do doc 03 §4). Cada chamada é
  /// encadeada atrás da anterior: chamadas concorrentes não drenam duas
  /// vezes, quem chama espera o estado real da fila e mutações chegadas
  /// durante o flush são capturadas. Fila vazia não emite estado (evita
  /// flapping do indicador).
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    final anterior = _flushAtual ?? Future<void>.value();
    final trabalho = () async {
      try {
        await anterior;
      } on Exception {
        // O erro já foi entregue a quem aguardou o trabalho anterior.
      }
      if (_disposed || !_online || !await _temEnviaveis()) return;
      _falhou = false;
      await _drenar();
      if (!_falhou && !_disposed && _online && await _temEnviaveis()) {
        await flush();
      }
    }();
    _flushAtual = trabalho;
    return trabalho;
  }

  Future<void> _drenar() async {
    _definir(const Sincronizando());
    SyncStatus resultado = const Sincronizado();
    while (_online) {
      final lote = await _proximoLote();
      if (lote == null) {
        resultado = (await _contarFila()) == 0
            ? const Sincronizado()
            : const ErroSync();
        break;
      }
      try {
        for (final mutacao in lote) {
          _reportarSeRelogioAdiantado(mutacao);
          final resultado = await _remoto.enviar(mutacao);
          switch (resultado) {
            case Enviado():
              await _removerRegistro(mutacao.tabela, mutacao.registroId);
            case RemotoVenceu(:final registro):
              // Remoto venceu no LWW: sobrescreve o Drift (inclusive
              // tombstones) e descarta as mutações do registro — doc 03 §5.
              await _aplicador.aplicar(mutacao.tabela, registro);
              await _removerRegistro(mutacao.tabela, mutacao.registroId);
            case Duplicado(:final registro):
              // Deduplicação (doc 03 §5, RF-10): a linha local vira
              // tombstone e o item remoto absorve a quantidade — nunca
              // há duplicado ativo.
              await _tumbarLocal(mutacao.tabela, mutacao.registroId);
              await _aplicador.aplicar(mutacao.tabela, registro);
              await _removerRegistro(mutacao.tabela, mutacao.registroId);
          }
        }
      } on Exception {
        _falhou = true;
        if (!_online) {
          // Rede caiu no meio do flush: pausa sem queimar tentativas
          // (doc 03 §6 — reconexão dispara novo flush).
          resultado = const Offline();
        } else {
          await _registrarFalha(lote);
          resultado = await _statusAposFalha();
          await _reportarFalha(lote);
          _agendarRetry();
        }
        break;
      }
    }
    if (!_online) resultado = const Offline();
    if (resultado is ErroSync) {
      // doc 07 §4: syncStatus = Erro persistente é evento monitorado.
      _reportar?.call('sync_erro_persistente', {'fila': await _contarFila()});
    }
    _definir(resultado);
  }

  /// Ação "tentar de novo" do estado Erro (doc 03 §3, UI em F4-T07).
  Future<void> reiniciarTentativas() async {
    await (_db.update(_db.mutacaoPendente)
          ..where((m) => m.tentativas.isBiggerThanValue(0)))
        .write(const MutacaoPendenteCompanion(tentativas: Value(0)));
    await flush();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subFila?.cancel();
    await _subConectividade?.cancel();
    await _statusController.close();
  }

  // ---- Internos ----

  void _aoMudarConectividade(List<ConnectivityResult> resultados) {
    _online = resultados.any((r) => r != ConnectivityResult.none);
    if (_online) {
      unawaited(flush());
    } else {
      _definir(const Offline());
    }
  }

  void _definir(SyncStatus status) {
    if (_disposed || _statusController.isClosed) return;
    _atual = status;
    _statusController.add(status);
  }

  /// Próximo grupo a drenar: da lista mais antiga, com coalescing por
  /// registro (mantém a última mutação — maior id; doc 03 §3). Null quando
  /// a fila não tem mutações enviáveis.
  Future<List<MutacaoSync>?> _proximoLote() async {
    final linhas =
        await (_db.select(_db.mutacaoPendente)
              ..where((m) => m.tentativas.isSmallerThanValue(maxTentativas))
              ..orderBy([(m) => OrderingTerm.asc(m.id)]))
            .get();
    if (linhas.isEmpty) return null;
    final listaId = linhas.first.listaId;
    final doGrupo = linhas.where((m) => m.listaId == listaId);
    final porRegistro = <String, MutacaoPendenteData>{};
    for (final linha in doGrupo) {
      porRegistro[linha.registroId] = linha;
    }
    return [for (final linha in porRegistro.values) _paraSync(linha)];
  }

  MutacaoSync _paraSync(MutacaoPendenteData linha) => MutacaoSync(
    tabela: linha.tabela,
    operacao: linha.operacao,
    registroId: linha.registroId,
    listaId: linha.listaId,
    tsLocal: linha.tsLocal,
    payload: jsonDecode(linha.payload) as Map<String, Object?>,
    tentativas: linha.tentativas,
  );

  /// Relatório de relógio adiantado (doc 07 §4 evento 2, 03 §5): ts do
  /// cliente mais de 24h no futuro em relação ao dispositivo.
  void _reportarSeRelogioAdiantado(MutacaoSync mutacao) {
    if (_reportar == null) return;
    final ts = DateTime.tryParse(
      mutacao.payload['updated_at'] as String? ?? '',
    );
    if (ts == null) return;
    final atraso = ts.difference(DateTime.now().toUtc());
    if (atraso > const Duration(hours: 24)) {
      _reportar('sync_relogio_adiantado', {'atraso_horas': atraso.inHours});
    }
  }

  /// Relatórios de falha (doc 07 §4 evento 1): fila > 10 mutações ou
  /// mutação com > 5 tentativas.
  Future<void> _reportarFalha(List<MutacaoSync> lote) async {
    if (_reportar == null) return;
    final fila = await _contarFila();
    final maiorTentativas = lote.fold<int>(
      0,
      (maior, m) => m.tentativas > maior ? m.tentativas : maior,
    );
    if (fila > 10) {
      _reportar('sync_falha_fila_grande', {'fila': fila});
    }
    if (maiorTentativas > 5) {
      _reportar('sync_falha_tentativas_altas', {'tentativas': maiorTentativas});
    }
  }

  /// Sucesso apaga todas as linhas do registro (as sombreadas pelo
  /// coalescing incluem).
  Future<void> _removerRegistro(String tabela, String registroId) {
    return (_db.delete(_db.mutacaoPendente)..where(
          (m) => m.tabela.equals(tabela) & m.registroId.equals(registroId),
        ))
        .go();
  }

  /// Marca a linha local como removida (tombstone) — usada na deduplicação
  /// (doc 03 §5), quando o registro local é absorvido pelo remoto.
  Future<void> _tumbarLocal(String tabela, String registroId) async {
    final agora = DateTime.now().toUtc();
    switch (tabela) {
      case 'listas':
        await (_db.update(
          _db.listaLocal,
        )..where((l) => l.id.equals(registroId))).write(
          ListaLocalCompanion(
            deletadoEm: Value(agora),
            updatedAt: Value(agora),
          ),
        );
      case 'itens_lista':
        await (_db.update(
          _db.itemLocal,
        )..where((i) => i.id.equals(registroId))).write(
          ItemLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
        );
    }
  }

  Future<void> _registrarFalha(List<MutacaoSync> lote) async {
    for (final mutacao in lote) {
      // Sem `updates:` — incrementar tentativas não é mudança de fila e não
      // deve disparar novo flush (o retry agendado cuida da fila).
      await _db.customUpdate(
        'UPDATE mutacao_pendente SET tentativas = tentativas + 1 '
        'WHERE tabela = ? AND registro_id = ?',
        variables: [Variable(mutacao.tabela), Variable(mutacao.registroId)],
      );
    }
  }

  Future<SyncStatus> _statusAposFalha() async {
    if (!await _temEnviaveis()) return const ErroSync();
    return Pendente(await _contarFila());
  }

  void _agendarRetry() {
    if (_reagendado || _disposed) return;
    _reagendado = true;
    unawaited(() async {
      final maior = await _maiorTentativasEnviavel();
      if (maior == null) {
        _reagendado = false;
        return;
      }
      await _esperar(_backoff(maior));
      _reagendado = false;
      if (!_disposed) await flush();
    }());
  }

  /// 1s → 2s → 4s → ... → máx. 5 min (doc 03 §3).
  Duration _backoff(int tentativas) {
    final segundos = min(1 << (tentativas - 1), _backoffMaximoSegundos);
    return Duration(seconds: segundos);
  }

  Future<int> _contarFila() async {
    final contagem = _db.mutacaoPendente.id.count();
    final query = _db.selectOnly(_db.mutacaoPendente)..addColumns([contagem]);
    final linha = await query.getSingle();
    return linha.read(contagem) ?? 0;
  }

  Future<bool> _temEnviaveis() async {
    final contagem = _db.mutacaoPendente.id.count();
    final query = _db.selectOnly(_db.mutacaoPendente)
      ..addColumns([contagem])
      ..where(_db.mutacaoPendente.tentativas.isSmallerThanValue(maxTentativas));
    final linha = await query.getSingle();
    return (linha.read(contagem) ?? 0) > 0;
  }

  Future<int?> _maiorTentativasEnviavel() async {
    final maximo = _db.mutacaoPendente.tentativas.max();
    final query = _db.selectOnly(_db.mutacaoPendente)
      ..addColumns([maximo])
      ..where(_db.mutacaoPendente.tentativas.isSmallerThanValue(maxTentativas));
    final linha = await query.getSingle();
    return linha.read(maximo);
  }
}
