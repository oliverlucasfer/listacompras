import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/papel.dart';
import 'papel_repository.dart';

/// Realtime de `lista_membros` (doc 08 §7, F7-T06): função pura delegada
/// pelo bootstrap — eventos desta tabela NUNCA passam por `aplicarRemoto`
/// (`lista_membros` não tem `updated_at`). O DELETE precisa de
/// REPLICA IDENTITY FULL no banco para trazer `user_id` no `old_record`.
void aplicarEventoMembro({
  required String? usuarioAtual,
  required PostgresChangePayload payload,
  required void Function() onPerdaAcesso,
  PapelRepository? papelRepository,
}) {
  if (usuarioAtual == null || payload.table != 'lista_membros') return;
  final evento = payload.eventType;
  final userId = evento == PostgresChangeEvent.delete
      ? payload.oldRecord['user_id']
      : (payload.newRecord['user_id'] ?? payload.oldRecord['user_id']);
  if (userId is! String) return;

  if (evento == PostgresChangeEvent.insert && userId != usuarioAtual) {
    // Outro usuário entrou na lista (doc 08 §7, F7-T07): sinaliza para a
    // UI — sem nome, o RLS não expõe o perfil de outros membros.
    final listaId = payload.newRecord['lista_id'];
    if (listaId is String) papelRepository?.notificarEntrada(listaId);
    return;
  }
  if (userId != usuarioAtual) return;

  switch (evento) {
    case PostgresChangeEvent.delete:
      onPerdaAcesso();
    case PostgresChangeEvent.insert || PostgresChangeEvent.update:
      final listaId =
          payload.newRecord['lista_id'] ?? payload.oldRecord['lista_id'];
      final valor = payload.newRecord['papel'] ?? payload.oldRecord['papel'];
      if (listaId is! String || valor is! String) return;
      try {
        papelRepository?.atualizar(listaId, Papel.fromValor(valor));
      } on ArgumentError {
        // Papel fora do enum fechado (servidor divergiu): linha ignorada.
      }
    case _:
      break;
  }
}
