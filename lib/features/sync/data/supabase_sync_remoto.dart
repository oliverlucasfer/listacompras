import 'package:supabase_flutter/supabase_flutter.dart';

import 'mutacao_sync.dart';
import 'sync_remoto.dart';

/// Regra LWW (doc 03 §5): remoto vence quando seu `updated_at` é maior que
/// o local — ou em caso de empate, o timestamp do servidor desempata.
/// Null significa que não há registro remoto → local vence.
bool remotoVenceNoLww(DateTime? atualizadoRemoto, DateTime atualizadoLocal) {
  if (atualizadoRemoto == null) return false;
  return !atualizadoRemoto.isBefore(atualizadoLocal);
}

/// Mescla um INSERT duplicado (doc 03 §5, RF-10): soma a quantidade no
/// registro remoto quando as unidades coincidem; null quando divergem
/// (o remoto vence e o item local é descartado). O `updated_at` mesclado
/// é o mais recente dos dois.
Map<String, Object?>? mesclarDuplicado(
  Map<String, Object?> remoto,
  Map<String, Object?> local,
) {
  if (remoto['unidade'] != local['unidade']) return null;
  final quantidade =
      ((remoto['quantidade'] as num?)?.toDouble() ?? 1) +
      ((local['quantidade'] as num?)?.toDouble() ?? 1);
  final tsRemoto = DateTime.tryParse(remoto['updated_at'] as String? ?? '');
  final tsLocal = DateTime.tryParse(local['updated_at'] as String? ?? '');
  final ts = switch ((tsRemoto, tsLocal)) {
    (DateTime a, DateTime b) => a.isAfter(b) ? a : b,
    (DateTime a, null) => a,
    (null, DateTime b) => b,
    _ => null,
  };
  return {
    ...remoto,
    'quantidade': quantidade,
    if (ts != null) 'updated_at': ts.toUtc().toIso8601String(),
  };
}

/// SyncRemoto real (doc 03 §4–5): consulta o registro remoto, decide no LWW
/// e envia `INSERT ... on conflict do nothing` ou upsert — o trigger
/// `touch_updated_at_lww` (doc 01 §5) preserva o timestamp do cliente.
/// Autenticação e RLS do Supabase valem aqui (doc 02).
class SupabaseSyncRemoto implements SyncRemoto {
  SupabaseSyncRemoto(this._client);

  final SupabaseClient _client;

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    final tabela = _client.from(mutacao.tabela);
    final registro = await tabela
        .select()
        .eq('id', mutacao.registroId)
        .maybeSingle();
    final atualizadoLocal = DateTime.parse(
      mutacao.payload['updated_at'] as String,
    );
    if (registro != null &&
        remotoVenceNoLww(_parse(registro['updated_at']), atualizadoLocal)) {
      return RemotoVenceu(registro);
    }
    if (mutacao.operacao == 'INSERT') {
      // Deduplicação (doc 03 §5): unique (lista_id, lower(nome)) ativa.
      final duplicado = await _buscarDuplicado(mutacao);
      if (duplicado != null) {
        final mesclado = mesclarDuplicado(duplicado, mutacao.payload);
        if (mesclado != null) {
          await tabela.upsert(mesclado, onConflict: 'id');
          return Duplicado(mesclado);
        }
        return Duplicado(duplicado);
      }
      // ID client-side pode já existir (outro dispositivo) — doc 03 §4.2.
      await tabela.upsert(
        mutacao.payload,
        onConflict: 'id',
        ignoreDuplicates: true,
      );
    } else {
      await tabela.upsert(mutacao.payload, onConflict: 'id');
    }
    return const Enviado();
  }

  /// Item ativo da mesma lista com o mesmo nome (case-insensitive) e id
  /// diferente do que está sendo inserido.
  Future<Map<String, Object?>?> _buscarDuplicado(MutacaoSync mutacao) async {
    if (mutacao.tabela != 'itens_lista') return null;
    final nomeLocal = (mutacao.payload['nome'] as String).toLowerCase();
    final linhas = await _client
        .from('itens_lista')
        .select()
        .eq('lista_id', mutacao.listaId)
        .isFilter('deletado_em', null)
        .neq('id', mutacao.registroId);
    for (final linha in linhas as List) {
      final mapa = Map<String, Object?>.from(linha as Map);
      if ((mapa['nome'] as String?)?.toLowerCase() == nomeLocal) {
        return mapa;
      }
    }
    return null;
  }

  DateTime? _parse(Object? iso) => iso is String ? DateTime.parse(iso) : null;
}
