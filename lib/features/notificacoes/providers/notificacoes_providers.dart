import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notificacoes_push_firebase.dart';
import '../data/notificacoes_service.dart';
import '../data/push_tokens_repository.dart';
import '../domain/notificacoes_push.dart';

/// Push só onde há suporte: Android hoje (iOS entra depois; Web/Desktop não).
bool plataformaComPush() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

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
    state = AsyncData(ativas);
    await ref.read(notificacoesServiceProvider).definirAtivas(ativas);
  }
}

final notificacoesAtivasProvider =
    AsyncNotifierProvider<NotificacoesAtivas, bool>(NotificacoesAtivas.new);
