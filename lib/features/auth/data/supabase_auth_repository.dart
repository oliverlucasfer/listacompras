import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositório de autenticação (doc 05 §2, RF-01). UI fala com providers,
/// providers falam com este repositório.
class SupabaseAuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Deep link do callback de auth (verificação e recuperação de senha).
  /// Registrado em AndroidManifest/iOS Info.plist e nas redirect urls do
  /// Supabase (doc 05 §6.1).
  static const deepLink = 'br.com.oliverlucas.listacompras://login-callback';

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get sessaoAtual => _client.auth.currentSession;

  Future<AuthResponse> registrar({
    required String email,
    required String senha,
  }) => _client.auth.signUp(
    email: email,
    password: senha,
    emailRedirectTo: deepLink,
  );

  Future<AuthResponse> entrar({required String email, required String senha}) =>
      _client.auth.signInWithPassword(email: email, password: senha);

  Future<void> sair() => _client.auth.signOut();

  Future<void> enviarRecuperacaoSenha(String email) =>
      _client.auth.resetPasswordForEmail(email, redirectTo: deepLink);

  Future<UserResponse> atualizarSenha(String novaSenha) =>
      _client.auth.updateUser(UserAttributes(password: novaSenha));

  Future<void> reenviarVerificacao(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  /// Exclusão de conta (doc 06 §3.3.1, RF-11, ADR-008): RPC security
  /// definer apaga o usuário (cascata em listas/membros/itens e
  /// ia_rate_limit); encerra a sessão local em seguida.
  Future<void> excluirConta() async {
    await _client.rpc('excluir_conta');
    await sair();
  }
}
