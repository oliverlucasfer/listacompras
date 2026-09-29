import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/web/url_strategy.dart';

/// Arranque do app local (RF-31): sem Supabase, Firebase, push ou Sentry.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  usarPathUrlStrategy();
  runApp(const ProviderScope(child: ListaComprasApp()));
}
