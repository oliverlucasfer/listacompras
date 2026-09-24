import 'dart:convert';

import '../../../drift/database.dart';

/// Fila de mutações compartilhada (doc 03 §3): monta o payload no formato que
/// o Sync Engine consome e insere em `mutacao_pendente`. A guarda de modo fica
/// num ponto só: `ativa == false` (Lite, RF-31) não alimenta a fila, que
/// cresceria para sempre sem drenar.
class OutboxMutacoes {
  OutboxMutacoes(this._db, {this.ativa = true});

  final AppDatabase _db;
  final bool ativa;

  Future<void> enfileirar({
    required String tabela,
    required String operacao,
    required String registroId,
    required String listaId,
    required DateTime tsLocal,
    required Map<String, Object?> payload,
  }) {
    if (!ativa) return Future<void>.value();
    return _db
        .into(_db.mutacaoPendente)
        .insert(
          MutacaoPendenteCompanion.insert(
            tabela: tabela,
            operacao: operacao,
            registroId: registroId,
            payload: jsonEncode(payload),
            tsLocal: tsLocal,
            listaId: listaId,
          ),
        );
  }

  Future<Map<String, Object?>> payloadLista(
    String id, {
    bool incluirArquivo = false,
  }) async {
    final l = await (_db.select(
      _db.listaLocal,
    )..where((l) => l.id.equals(id))).getSingle();
    return {
      'id': l.id,
      'titulo': l.titulo,
      'dono_id': l.donoId,
      'created_at': _iso(l.createdAt),
      'updated_at': _iso(l.updatedAt),
      'deletado_em': l.deletadoEm == null ? null : _iso(l.deletadoEm!),
      'orcamento_centavos': l.orcamentoCentavos,
      if (incluirArquivo)
        'arquivada_em': l.arquivadaEm == null ? null : _iso(l.arquivadaEm!),
    };
  }

  Future<Map<String, Object?>> payloadItem(String id) async {
    final i = await (_db.select(
      _db.itemLocal,
    )..where((i) => i.id.equals(id))).getSingle();
    return {
      'id': i.id,
      'lista_id': i.listaId,
      'nome': i.nome,
      'quantidade': i.quantidade,
      'unidade': i.unidade,
      'categoria': i.categoria,
      'concluido': i.concluido,
      'ordem': i.ordem,
      'preco_centavos': i.precoCentavos,
      'created_at': _iso(i.createdAt),
      'updated_at': _iso(i.updatedAt),
      'deletado_em': i.deletadoEm == null ? null : _iso(i.deletadoEm!),
    };
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();
}
