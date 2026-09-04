import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/parse_lista_client.dart';

/// Cliente da IA com JWT da sessão atual (doc 04 §2) — injetável para
/// testes (F4-T01).
final parseListaClientProvider = Provider<ParseListaClient>((ref) {
  return ParseListaClient(
    obterToken: () => ref.read(authRepositoryProvider).sessaoAtual?.accessToken,
    obterUri: () => Uri.parse('$supabaseUrl/functions/v1/parse-lista'),
  );
});
