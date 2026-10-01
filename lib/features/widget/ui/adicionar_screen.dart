import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_esqueleto.dart';
import '../../listas/providers/listas_providers.dart';
import '../providers/widget_providers.dart';

class AdicionarScreen extends ConsumerStatefulWidget {
  const AdicionarScreen({super.key});
  @override
  ConsumerState<AdicionarScreen> createState() => _AdicionarScreenState();
}

class _AdicionarScreenState extends ConsumerState<AdicionarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolver());
  }

  Future<void> _resolver() async {
    final ultima = await ref.read(ultimaListaServiceProvider).ler();
    final listas = await ref.read(listasRepositoryProvider).watchListas().first;
    final disponiveis = listas.where((l) => l.arquivadaEm == null).toList();
    final alvo =
        disponiveis.where((l) => l.id == ultima).firstOrNull ??
        (disponiveis.isNotEmpty ? disponiveis.first : null);
    if (!mounted) return;
    if (alvo == null) {
      context.go('/listas');
    } else {
      context.pushReplacement('/lista/${alvo.id}?foco=1');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppEsqueleto(linhas: 4));
}
