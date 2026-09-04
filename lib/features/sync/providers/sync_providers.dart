import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/supabase_sync_remoto.dart';
import '../data/sync_engine.dart';
import '../domain/sync_status.dart';

/// Sync Engine com remoto real (doc 03 §2). Ligado no arranque do app
/// (main.dart); bootstrap por usuário e multi-conta entram na F4-T06.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    remoto: SupabaseSyncRemoto(Supabase.instance.client),
    conectividade: Connectivity().onConnectivityChanged,
    checarConexao: () async => (await Connectivity().checkConnectivity()).any(
      (r) => r != ConnectivityResult.none,
    ),
  );
  ref.onDispose(engine.dispose);
  unawaited(engine.iniciar());
  return engine;
});

/// Estado de sync para a UI (doc 03 §6, wireframe 10 §3.2 — UI na F4-T07).
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncEngineProvider).status,
);
