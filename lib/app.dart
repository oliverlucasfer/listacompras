import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/notificacoes/providers/push_navegacao.dart';
import 'router.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ListaComprasApp extends ConsumerWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final modoTema = ref.watch(temaModoProvider).value ?? ThemeMode.system;
    ref.listen(notificacoesForegroundProvider, (_, proximo) {
      final data = proximo.value;
      final corpo = data?['corpo'];
      if (corpo is String && corpo.isNotEmpty) {
        _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(corpo)));
      }
    });
    return MaterialApp.router(
      title: AppStrings.appNome,
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: modoTema,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
