import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/convites_repository.dart';
import '../domain/convite.dart';
import '../domain/convite_pendente.dart';
import '../domain/papel.dart';

/// Repositório de convites (doc 08 §2–3, RF-13): chamadas diretas ao
/// servidor, sem fila offline (spec §4.1).
final convitesRepositoryProvider = Provider<ConvitesRepository>((ref) {
  return ConvitesRepository(Supabase.instance.client);
});

/// Meus convites por e-mail pendentes (RF-13, fluxo B, F32).
final meusConvitesPendentesProvider = FutureProvider<List<ConvitePendente>>(
  (ref) => ref.watch(convitesRepositoryProvider).meusConvitesPendentes(),
);

/// Membros da lista (doc 08 §5/§8, F7-T03, RF-13): FutureProvider.family por
/// listaId. O dono é mesclado a partir da lista local (`donoId`) quando o
/// servidor não devolve a linha — a tela nunca fica vazia para listas
/// próprias (offline ou associação pendente).
final membrosDaListaProvider = FutureProvider.family<List<MembroLista>, String>(
  (ref, listaId) async {
    final membros = await ref
        .watch(convitesRepositoryProvider)
        .membrosDaLista(listaId);
    final donoId = ref.watch(listaPorIdProvider(listaId)).value?.donoId;
    if (donoId != null &&
        donoId.isNotEmpty &&
        !membros.any((m) => m.papel == Papel.dono)) {
      return [MembroLista(userId: donoId, papel: Papel.dono), ...membros];
    }
    return membros;
  },
);
