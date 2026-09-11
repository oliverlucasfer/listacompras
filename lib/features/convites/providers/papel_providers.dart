import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../../listas/providers/listas_providers.dart';
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

/// Papel **efetivo** na lista (correção): o dono é derivado da própria lista
/// local (`lista.donoId == usuário`) antes de qualquer papel do servidor.
/// Assim listas próprias continuam editáveis offline e após reiniciar o app,
/// mesmo sem a linha de `lista_membros` carregada.
final papelEfetivoProvider = Provider.family<Papel, String>((ref, listaId) {
  final usuario = ref.watch(donoAtualIdProvider);
  final lista = ref.watch(listaPorIdProvider(listaId)).value;
  if (lista != null && lista.donoId == usuario) return Papel.dono;
  return ref.watch(papelNaListaStreamProvider(listaId)).value ??
      ref.watch(papelRepositoryProvider).papelDe(listaId) ??
      Papel.leitor;
});
