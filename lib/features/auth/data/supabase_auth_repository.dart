import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/links.dart';
import '../domain/sessao.dart';
import 'auth_repository.dart';

/// Repositório de autenticação (doc 05 §2, RF-01). UI fala com providers,
/// providers falam com este repositório.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// URL de retorno do fluxo de auth (doc 05 §6.1, ADR-012): https no web,
  /// scheme custom no nativo.
  @override
  String get redirectUrl => redirectAuth();

  @override
  Stream<EventoSessao> get onAuthStateChange =>
      _client.auth.onAuthStateChange.map(
        (estado) => EventoSessao(
          usuario: _paraUsuario(estado.session),
          recuperacaoDeSenha: estado.event == AuthChangeEvent.passwordRecovery,
        ),
      );

  @override
  UsuarioAtual? get sessaoAtual => _paraUsuario(_client.auth.currentSession);

  UsuarioAtual? _paraUsuario(Session? s) =>
      s == null ? null : UsuarioAtual(id: s.user.id, email: s.user.email);

  @override
  Future<AuthResponse> registrar({
    required String email,
    required String senha,
  }) => _client.auth.signUp(
    email: email,
    password: senha,
    emailRedirectTo: redirectUrl,
  );

  @override
  Future<AuthResponse> entrar({required String email, required String senha}) =>
      _client.auth.signInWithPassword(email: email, password: senha);

  @override
  Future<void> sair() => _client.auth.signOut();

  @override
  Future<void> enviarRecuperacaoSenha(String email) =>
      _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);

  @override
  Future<UserResponse> atualizarSenha(String novaSenha) =>
      _client.auth.updateUser(UserAttributes(password: novaSenha));

  @override
  Future<void> reenviarVerificacao(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email);

  /// Exclusão de conta (doc 06 §3.3.1, RF-11, ADR-008): RPC security
  /// definer apaga o usuário (cascata em listas/membros/itens);
  /// encerra a sessão local em seguida.
  @override
  Future<void> excluirConta() async {
    await _client.rpc('excluir_conta');
    await sair();
  }
}
