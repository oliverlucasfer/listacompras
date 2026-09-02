import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_placeholder.dart';

/// Rotas declarativas (doc 05 §4). Guards de auth entram na F3-T03.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePlaceholder()),
    ],
  );
});
