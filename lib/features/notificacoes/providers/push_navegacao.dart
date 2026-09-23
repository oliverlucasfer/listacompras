import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router.dart';
import '../domain/rota_notificacao.dart';
import 'notificacoes_providers.dart';

/// Ponte push → go_router (app aberto e cold start). Só no Android: em
/// Web/Desktop o FCM não existe e a ponte fica desligada.
final pushNavegacaoProvider =
    Provider<StreamSubscription<Map<String, Object?>>?>((ref) {
      if (!plataformaComPush()) return null;
      final push = ref.watch(notificacoesPushProvider);
      final router = ref.watch<GoRouter>(routerProvider);
      void ir(Map<String, Object?> data) {
        final rota = rotaDaNotificacao(data);
        if (rota != null) router.go(rota);
      }

      push.toqueInicial().then((data) {
        if (data != null) ir(data);
      });
      final sub = push.onToque.listen(ir, onError: (_) {});
      ref.onDispose(sub.cancel);
      return sub;
    });

/// Notificação recebida em primeiro plano (payload) — o app mostra um SnackBar.
final notificacoesForegroundProvider = StreamProvider<Map<String, Object?>>(
  (ref) => plataformaComPush()
      ? ref.watch(notificacoesPushProvider).onRecebida
      : const Stream<Map<String, Object?>>.empty(),
);
