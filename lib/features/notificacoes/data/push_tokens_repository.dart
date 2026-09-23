import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokensRepository {
  PushTokensRepository(this._client);

  final SupabaseClient _client;

  Future<void> registrar({
    required String token,
    required String plataforma,
  }) async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc(
      'registrar_push_token',
      params: {'p_token': token, 'p_plataforma': plataforma},
    );
  }

  Future<void> remover(String token) async {
    await _client.from('push_tokens').delete().eq('token', token);
  }
}
