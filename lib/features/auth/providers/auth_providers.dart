import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/sessao.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

/// Sessão atual (login/logout/refresh) — doc 05 §3.
final authStateProvider = StreamProvider<EventoSessao>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// true quando há usuário autenticado.
final autenticadoProvider = Provider<bool>((ref) {
  final evento = ref.watch(authStateProvider).value;
  return evento?.usuario != null ||
      ref.watch(authRepositoryProvider).sessaoAtual != null;
});

/// ID do usuário autenticado — dono de listas criadas no cliente (ADR-006).
final donoAtualIdProvider = Provider<String>((ref) {
  return ref.watch(authRepositoryProvider).sessaoAtual?.id ?? '';
});

/// E-mail da conta autenticada (null sem sessão) — usado nas Configurações.
final emailUsuarioProvider = Provider<String?>((ref) {
  return ref.watch(authRepositoryProvider).sessaoAtual?.email;
});

/// true enquanto o app estiver no fluxo do link de recuperação de senha
/// (`passwordRecovery`): o redirect leva a `/redefinir-senha` até a senha
/// ser redefinida (F14-T03, doc 05 §4/§6.1).
final redefinindoSenhaProvider = NotifierProvider<RedefinindoSenha, bool>(
  RedefinindoSenha.new,
);

class RedefinindoSenha extends Notifier<bool> {
  @override
  bool build() {
    final sub = ref.watch(authRepositoryProvider).onAuthStateChange.listen((
      estado,
    ) {
      if (estado.recuperacaoDeSenha) state = true;
    });
    ref.onDispose(sub.cancel);
    return false;
  }

  /// Encerra o fluxo (após redefinir ou desistir) e libera o redirect.
  void concluir() => state = false;
}
