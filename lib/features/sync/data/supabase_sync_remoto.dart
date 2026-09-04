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

  DateTime? _parse(Object? iso) => iso is String ? DateTime.parse(iso) : null;
}
