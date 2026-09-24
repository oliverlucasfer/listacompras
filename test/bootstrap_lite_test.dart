import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';

void main() {
  test('deve_autenticar_como_local_quando_modo_lite_sem_supabase', () {
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isTrue);
    expect(container.read(donoAtualIdProvider), 'local');
  });
}
