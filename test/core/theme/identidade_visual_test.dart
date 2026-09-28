import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/theme/identidade_visual.dart';
import 'package:lista_compras/core/theme/tokens/app_colors.dart';

void main() {
  test('deve_usar_indigo_e_minhas_listas_quando_modo_lite', () {
    final container = ProviderContainer(
      overrides: [capacidadesProvider.overrideWithValue(AppCapacidades.lite)],
    );
    addTearDown(container.dispose);

    final identidade = container.read(identidadeVisualProvider);
    expect(identidade.seed, AppColors.seedLite);
    expect(identidade.nomeApp, 'Minhas Listas');
    expect(identidade.logoAsset, 'assets/branding/logo_lite.png');
  });

  test('deve_usar_verde_e_lista_de_compras_quando_colaborativo', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final identidade = container.read(identidadeVisualProvider);
    expect(identidade.seed, AppColors.seed);
    expect(identidade.nomeApp, 'Lista de Compras');
    expect(identidade.logoAsset, 'assets/branding/logo.png');
  });
}
