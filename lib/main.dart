import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/deeplink_convite.dart';
import 'features/sync/providers/sync_providers.dart';
import 'router.dart';

/// DSN do Sentry build-time (doc 07 §4, RF-12). Vazio → Sentry desligado
/// (dev/testes). Nenhuma chave secreta: DSN é identificável publicamente.
const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  void app() {
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
    // Ponte deep link de convite → go_router (doc 08 §1.1, RF-13).
    container.read(deeplinkConviteProvider);
  }

  if (sentryDsn.isEmpty) {
    app();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.sendDefaultPii = false;
      // Privacidade (doc 07 §4): logs NUNCA contêm conteúdo de listas —
      // breadcrumbs podem carregar mensagens de erro com dados; removidos.
      options.beforeSend = (event, hint) {
        event.breadcrumbs?.clear();
        return event;
      };
    }, appRunner: app);
  }
}

class ListaComprasApp extends ConsumerWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppStrings.appNome,
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
