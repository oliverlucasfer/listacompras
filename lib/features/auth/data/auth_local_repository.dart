import '../domain/sessao.dart';
import 'auth_repository.dart';

/// Autenticação do modo Lite (RF-31): não há conta — a sessão é sempre o
/// usuário local e nenhuma operação toca a rede.
class AuthLocalRepository implements AuthRepository {
  static const idLocal = 'local';

  @override
  String get redirectUrl => '';

  @override
  Stream<EventoSessao> get onAuthStateChange => const Stream.empty();

  @override
  UsuarioAtual? get sessaoAtual => const UsuarioAtual(id: idLocal);

  @override
  Future<void> registrar({
    required String email,
    required String senha,
  }) async {}

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}

  @override
  Future<void> enviarRecuperacaoSenha(String email) async {}

  @override
  Future<void> atualizarSenha(String novaSenha) async {}

  @override
  Future<void> reenviarVerificacao(String email) async {}

  @override
  Future<void> excluirConta() async {}
}
