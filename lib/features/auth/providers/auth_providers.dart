import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<SupabaseAuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

/// Sessão atual (login/logout/refresh) — doc 05 §3.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// true quando há usuário autenticado.
final autenticadoProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value?.session != null ||
      ref.watch(authRepositoryProvider).sessaoAtual != null;
});
