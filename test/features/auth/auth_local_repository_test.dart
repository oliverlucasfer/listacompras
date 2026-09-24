import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';

void main() {
  test('deve_ter_sessao_local_fixa_quando_sem_conta', () {
    final repo = AuthLocalRepository();
    expect(repo.sessaoAtual?.id, AuthLocalRepository.idLocal);
    expect(repo.sessaoAtual?.email, isNull);
  });

  test('deve_nunca_emitir_evento_de_sessao', () async {
    final repo = AuthLocalRepository();
    expect(await repo.onAuthStateChange.isEmpty, isTrue);
  });

  test('deve_ignorar_entrar_e_sair', () async {
    final repo = AuthLocalRepository();
    await repo.entrar(email: 'x@y.com', senha: 'z');
    await repo.sair();
    expect(repo.sessaoAtual?.id, AuthLocalRepository.idLocal);
  });
}
