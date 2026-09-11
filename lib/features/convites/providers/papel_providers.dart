import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/papel_repository.dart';
import '../domain/papel.dart';

/// Repositório de papéis do usuário corrente (doc 08 §4, F7-T02).
final papelRepositoryProvider = Provider<PapelRepository>((ref) {
  return PapelRepository(Supabase.instance.client);
});

/// Papel reativo (F7-T03): stream do [PapelRepository] — a UI acompanha
/// mudanças em memória (bootstrap, ações locais, realtime da F7-T06).
final papelNaListaStreamProvider = StreamProvider.family<Papel?, String>((
  ref,
  listaId,
) {
  return ref
      .watch(papelRepositoryProvider)
      .watch()
      .map((papeis) => papeis[listaId]);
});
