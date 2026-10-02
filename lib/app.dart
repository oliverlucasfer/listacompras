import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/idioma/idioma_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/identidade_visual.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/tour/ui/tour_overlay.dart';
import 'features/widget/ui/widget_atualizador.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ListaComprasApp extends ConsumerWidget {
  const ListaComprasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final identidade = ref.watch(identidadeVisualProvider);
    final modoTema = ref.watch(temaModoProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: identidade.nomeApp,
      locale: ref.watch(idiomaProvider).value?.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
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
      // O tour é ancorado na raiz, com constraints cheias: o `Spotlight` lê
      // posições globais (`localToGlobal`), então um overlay dentro do
      // `Scaffold.body` desalinharia o recorte (contrato da F46-T03).
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          if (child != null) child else const SizedBox.shrink(),
          const TourOverlay(),
          const WidgetAtualizador(),
        ],
      ),
    );
  }
}
