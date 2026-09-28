import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/providers/onboarding_provider.dart';
import '../../tour/tour_controller.dart';
import '../../tour/ui/tour_loader.dart';
import 'painel_listas.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, wireframe 10 §2, RF-02): as listas em
/// que o usuário é dono. Abre as boas-vindas uma vez (RF-27) e, em seguida,
/// dispara a etapa 1 do tour (RF-27, F46).
class MinhasListasScreen extends ConsumerStatefulWidget {
  const MinhasListasScreen({super.key});

  @override
  ConsumerState<MinhasListasScreen> createState() => _MinhasListasScreenState();
}

class _MinhasListasScreenState extends ConsumerState<MinhasListasScreen> {
  bool _onboardingResolvido = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolverOnboarding());
  }

  Future<void> _resolverOnboarding() async {
    if (!mounted) return;
    final visto = await ref.read(onboardingVistoProvider.future);
    if (!mounted) return;
    if (!visto) {
      // Espera o usuário concluir as boas-vindas para só então iniciar o tour.
      await context.push('/boas-vindas');
      if (!mounted) return;
    }
    setState(() => _onboardingResolvido = true);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const PainelListas(filtro: FiltroListas.minhas),
      if (_onboardingResolvido) const TourLoader(etapa: TourEtapa.primeira),
    ],
  );
}
