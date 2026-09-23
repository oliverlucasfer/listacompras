import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notificacoes_push_firebase.dart';
import '../data/notificacoes_service.dart';
import '../data/push_tokens_repository.dart';
import '../domain/notificacoes_push.dart';

export '../domain/plataforma_push.dart';

final notificacoesPushProvider = Provider<NotificacoesPush>(
  (ref) => NotificacoesPushFirebase(),
);

final pushTokensRepositoryProvider = Provider<PushTokensRepository>(
  (ref) => PushTokensRepository(Supabase.instance.client),
);

final notificacoesServiceProvider = Provider<NotificacoesService>(
  (ref) => NotificacoesService(
    push: ref.watch(notificacoesPushProvider),
    repositorio: ref.watch(pushTokensRepositoryProvider),
    plataforma: 'android',
  ),
);

class NotificacoesAtivas extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(notificacoesServiceProvider).ativas();

  Future<void> definir(bool ativas) async {
    final resultado = await ref
        .read(notificacoesServiceProvider)
        .definirAtivas(ativas);
    state = AsyncData(resultado);
  }
}

final notificacoesAtivasProvider =
    AsyncNotifierProvider<NotificacoesAtivas, bool>(NotificacoesAtivas.new);
