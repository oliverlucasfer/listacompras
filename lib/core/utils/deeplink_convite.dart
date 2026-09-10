import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lista_compras/router.dart';

/// Ponte deep links → go_router para o link de convite (doc 08 §1.1,
/// RF-13). O supabase_flutter (2.17.2) escuta o mesmo stream do app_links
/// mas só consome URLs com parâmetros de auth (`access_token`, `code`,
/// `error`) — links com host `entrar?token=` passam por ele intocados e
/// chegam aqui, que os traduz na rota `/entrar` do go_router.
/// No Android (client de convite) o link inicial de cold-start vem no
/// próprio stream do app_links; Web é tratado como URL normal do browser.
final deeplinkConviteProvider = Provider<StreamSubscription<Uri>>((ref) {
  final router = ref.watch<GoRouter>(routerProvider);
  final sub = AppLinks().uriLinkStream.listen((uri) {
    if (uri.host != 'entrar') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    router.go('/entrar?token=${Uri.encodeComponent(token)}');
  }, onError: (_) {});
  ref.onDispose(sub.cancel);
  return sub;
});
