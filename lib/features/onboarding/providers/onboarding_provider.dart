import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = 'onboarding_visto';

/// Se as boas-vindas já foram vistas (RF-27), local no dispositivo — espelha o
/// `temaModoProvider` (doc 15). Sem rede/Drift.
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave) ?? false;
  }

  Future<void> marcarVisto() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, true);
  }
}

final onboardingVistoProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
