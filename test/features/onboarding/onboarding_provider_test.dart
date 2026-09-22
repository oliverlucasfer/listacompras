import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/onboarding/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_carregar_falso_quando_nunca_visto', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final visto = await container.read(onboardingVistoProvider.future);

    expect(visto, isFalse);
  });

  test('deve_carregar_verdadeiro_quando_ja_visto', () async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final visto = await container.read(onboardingVistoProvider.future);

    expect(visto, isTrue);
  });

  test('deve_marcar_visto_quando_chama', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(onboardingVistoProvider.future);

    await container.read(onboardingVistoProvider.notifier).marcarVisto();

    expect(container.read(onboardingVistoProvider).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_visto'), isTrue);
  });
}
