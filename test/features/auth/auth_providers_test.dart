import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/auth/domain/sessao.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';

import 'fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  test('deve_derivar_id_e_email_da_sessao_atual', () {
    final repo = FakeAuthRepository()
      ..sessaoFake = const UsuarioAtual(id: 'user-a', email: 'a@b.com');
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isTrue);
    expect(container.read(donoAtualIdProvider), 'user-a');
    expect(container.read(emailUsuarioProvider), 'a@b.com');
  });

  test('deve_ficar_desautenticado_quando_sem_sessao', () {
    final repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isFalse);
    expect(container.read(donoAtualIdProvider), '');
    expect(container.read(emailUsuarioProvider), isNull);
  });
}
