import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_modo.dart';
import 'core/config/supabase_config.dart';
import 'core/observabilidade/sentry_privacidade.dart';
import 'core/utils/deeplink_convite.dart';
import 'core/web/url_strategy.dart';
import 'features/auth/data/auth_local_repository.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/notificacoes/providers/push_navegacao.dart';
import 'features/sync/providers/sync_providers.dart';

/// DSN do Sentry build-time (doc 07 §4, RF-12). Vazio → Sentry desligado
/// (dev/testes). Nenhuma chave secreta: DSN é identificável publicamente.
const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

/// Arranque comum aos dois modos (RF-31, F41).
Future<void> bootstrap(AppModo modo) async {
  final cap = modo == AppModo.lite
      ? AppCapacidades.lite
      : AppCapacidades.colaborativo;

  WidgetsFlutterBinding.ensureInitialized();
  usarPathUrlStrategy();

  // Trava de modo (F42): o flavor sozinho **não** seleciona o modo — quem o faz
  // é o entrypoint (`-t lib/main_lite.dart`). Sem esta conferência, buildar
  // `--flavor lite` sem `-t` empacota o app **colaborativo** com o pacote
  // `.lite` (já aconteceu: a distribuição da F41 saiu errada). Em debug falha
  // na hora, em vez de passar batido num teste manual.
  if (kDebugMode) await _conferirModoDoPacote(modo);

  if (cap.nuvem) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  if (cap.notificacoes &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }

  void app() {
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(cap),
        if (!cap.nuvem)
          authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
      ],
    );
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const ListaComprasApp(),
      ),
    );
    // Liga o Sync Engine + bootstrap/realtime (doc 03 §4/§7): drena a fila a
    // cada escrita e ao reconectar, aplica remotos vencedores no LWW e
    // isola o cache por usuário.
    if (cap.nuvem) {
      container.read(syncBootstrapProvider);
      // Ponte deep link de convite → go_router (doc 08 §1.1, RF-13).
      container.read(deeplinkConviteProvider);
    }
    // Ponte push → go_router (RF-30, F38): toque abre a tela certa.
    if (cap.notificacoes) {
      container.read(pushNavegacaoProvider);
    }
  }

  if (sentryDsn.isEmpty) {
    app();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.sendDefaultPii = false;
      // Privacidade (doc 07 §4, R-13/F21-T02): logs NUNCA contêm conteúdo de
      // listas — a limpeza de breadcrumbs/extra/contexts vive em
      // `limparDadosDoSentry` (testada) e nada de item chega ao Sentry.
      options.beforeSend = limparDadosDoSentry;
    }, appRunner: app);
  }
}

/// Falha cedo quando o **pacote** e o **modo** divergem (F42): o flavor
/// `lite` empacota o app colaborativo (ou o inverso). Sem plugin (testes) a
/// conferência não se aplica e é ignorada.
Future<void> _conferirModoDoPacote(AppModo modo) async {
  try {
    final pacote = (await PackageInfo.fromPlatform()).packageName;
    final ehPacoteLite = pacote.endsWith('.lite');
    if (modo == AppModo.lite && !ehPacoteLite) {
      throw StateError(
        'Entrypoint Lite em pacote colaborativo ($pacote): '
        'use `flutter build ... --flavor lite`.',
      );
    }
    if (modo == AppModo.colaborativo && ehPacoteLite) {
      throw StateError(
        'Flavor `lite` construído com o entrypoint colaborativo: '
        'use `-t lib/main_lite.dart`.',
      );
    }
  } on MissingPluginException {
    // Sem o package_info (testes/plataformas sem registro): sem trava.
  }
}
