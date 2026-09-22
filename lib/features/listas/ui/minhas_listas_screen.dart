import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/providers/onboarding_provider.dart';
import 'painel_listas.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, wireframe 10 §2, RF-02): as listas em
/// que o usuário é dono. Abre as boas-vindas uma vez (RF-27).
class MinhasListasScreen extends ConsumerStatefulWidget {
  const MinhasListasScreen({super.key});

  @override
  ConsumerState<MinhasListasScreen> createState() => _MinhasListasScreenState();
}

class _MinhasListasScreenState extends ConsumerState<MinhasListasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final visto = await ref.read(onboardingVistoProvider.future);
      if (!visto && mounted) context.push('/boas-vindas');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const PainelListas(filtro: FiltroListas.minhas);
}
