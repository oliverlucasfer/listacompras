import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../../convites/providers/papel_providers.dart';
import '../../listas/providers/listas_providers.dart';
import '../../notificacoes/providers/notificacoes_providers.dart';
import '../data/supabase_bootstrap.dart';
import '../data/supabase_sync_remoto.dart';
import '../data/sync_engine.dart';
import '../domain/sync_status.dart';

/// Sync Engine com remoto real (doc 03 §2). Ligado no arranque do app
/// (main.dart) junto com o bootstrap.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final remoto = SupabaseSyncRemoto(Supabase.instance.client);
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    remoto: remoto,
    // Observabilidade de relógio (doc 03 §5, R-06): o remoto também responde
    // pelo `now()` do servidor.
    fonteTempo: remoto,
    conectividade: Connectivity().onConnectivityChanged,
    checarConexao: () async => (await Connectivity().checkConnectivity()).any(
      (r) => r != ConnectivityResult.none,
    ),
    // Observabilidade (doc 07 §4, RF-12): códigos + contagens apenas —
    // nunca conteúdo de listas.
    reportar: (codigo, contexto) => Sentry.captureMessage(
      codigo,
      withScope: (scope) {
        for (final entrada in contexto.entries) {
          scope.setTag(entrada.key, entrada.value.toString());
        }
      },
    ),
  );
  ref.onDispose(engine.dispose);
  unawaited(engine.iniciar());
  return engine;
});

/// Bootstrap + Realtime (doc 03 §7, F4-T06): troca de usuário, re-sync na
/// reconexão e aplicação de eventos remotos no LWW.
final syncBootstrapProvider = Provider<SupabaseBootstrap>((ref) {
  final bootstrap = SupabaseBootstrap(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(syncEngineProvider),
    client: Supabase.instance.client,
    papelRepository: ref.watch(papelRepositoryProvider),
  );
  ref.onDispose(bootstrap.dispose);
  unawaited(bootstrap.iniciar());
  // Reafirma o token no start logado (best-effort, uma vez por transição).
  ref.listen(autenticadoProvider, (_, autenticado) {
    if (autenticado) {
      unawaited(ref.read(notificacoesServiceProvider).registrarSeAtivo());
    }
  }, fireImmediately: true);
  return bootstrap;
});

/// Estado de sync para a UI (doc 03 §6, wireframe 10 §3.2 — UI na F4-T07).
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncEngineProvider).status,
);

/// Flush best-effort da fila antes de operações online-only que dependem de
/// dados já no servidor (ex.: gerar link de convite — F12-T02). Injetável
/// para os testes de widget não tocarem o engine/Drift.
final sincronizarAntesDeOperacaoProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(syncEngineProvider).flush(),
);
