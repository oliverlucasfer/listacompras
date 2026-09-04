import 'dart:async';

import 'package:flutter/foundation.dart';

/// Ponte entre um Stream e o Listenable do go_router: reavalia os redirects
/// quando o estado de auth muda.
class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
