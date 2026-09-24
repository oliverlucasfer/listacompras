import '../domain/sessao.dart';

/// Contrato de autenticação (doc 05 §2, RF-01). O modo colaborativo usa
/// [SupabaseAuthRepository]; o modo Lite usa [AuthLocalRepository] (RF-31).
abstract class AuthRepository {
  String get redirectUrl;
  Stream<EventoSessao> get onAuthStateChange;
  UsuarioAtual? get sessaoAtual;

  Future<void> registrar({required String email, required String senha});
  Future<void> entrar({required String email, required String senha});
  Future<void> sair();
  Future<void> enviarRecuperacaoSenha(String email);
  Future<void> atualizarSenha(String novaSenha);
  Future<void> reenviarVerificacao(String email);
  Future<void> excluirConta();
}
