import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_modo.dart';
import '../../listas/providers/listas_providers.dart';
import '../data/backup_repository.dart';

/// Repositório de backup local (RF-31, F41).
///
/// `donoLocal` acompanha o modo: no Lite (sem nuvem) o app é single-user, então
/// ao importar toda lista passa a pertencer ao usuário local — um backup vindo
/// do app colaborativo não pode trazer `dono_id` estrangeiro para o Lite, onde
/// os caminhos "de membro" tocariam `Supabase.instance` (não inicializado).
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(
    ref.watch(appDatabaseProvider),
    donoLocal: !ref.watch(capacidadesProvider).nuvem,
  ),
);
