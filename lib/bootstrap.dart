import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/web/url_strategy.dart';

/// Arranque do app local (RF-31): sem rede, conta ou sync.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  usarPathUrlStrategy();
  runApp(const ProviderScope(child: ListaComprasApp()));
}
