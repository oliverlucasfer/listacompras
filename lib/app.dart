import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/identidade_visual.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_snack_bar.dart';
import 'features/notificacoes/providers/push_navegacao.dart';
import 'router.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ListaComprasApp extends ConsumerWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final identidade = ref.watch(identidadeVisualProvider);
    final modoTema = ref.watch(temaModoProvider).value ?? ThemeMode.system;
    ref.listen(notificacoesForegroundProvider, (_, proximo) {
      final data = proximo.value;
      final corpo = data?['corpo'];
      final messenger = _messengerKey.currentState;
      if (corpo is String && corpo.isNotEmpty && messenger != null) {
        mostrarSnackBar(context, corpo, messenger: messenger);
      }
    });
    return MaterialApp.router(
      title: identidade.nomeApp,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.claroDe(identidade),
      darkTheme: AppTheme.escuroDe(identidade),
      themeMode: modoTema,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
