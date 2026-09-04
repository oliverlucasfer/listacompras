import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/providers/sync_providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ListaComprasApp(),
    ),
  );
  // Liga o Sync Engine + bootstrap/realtime (doc 03 §4/§7): drena a fila a
  // cada escrita e ao reconectar, aplica remotos vencedores no LWW e
  // isola o cache por usuário.
  container.read(syncBootstrapProvider);
}

class ListaComprasApp extends ConsumerWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppStrings.appNome,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
