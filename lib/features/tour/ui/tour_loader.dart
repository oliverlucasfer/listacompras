import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tour_controller.dart';

/// Dispara uma etapa do tour quando ela ainda não foi vista. Não renderiza
/// nada: a renderização fica no `TourOverlay` de raiz (ver `app.dart`), que
/// assume espaço **full-screen** — o `Spotlight` lê posições globais via
/// `localToGlobal`, então colocá-lo dentro de um `Scaffold.body` desalinharia
/// o recorte pela AppBar/safe area (contrato da F46-T03).
///
/// A verificação roda no primeiro frame após a montagem; as telas que dependem
/// de dados assíncronos (etapa 2) só montam o loader quando os alvos já existem.
class TourLoader extends ConsumerStatefulWidget {
  const TourLoader({super.key, required this.etapa});

  final TourEtapa etapa;

  @override
  ConsumerState<TourLoader> createState() => _TourLoaderState();
}

class _TourLoaderState extends ConsumerState<TourLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _talvezIniciar());
  }

  Future<void> _talvezIniciar() async {
    if (!mounted) return;
    final vista = await ref.read(tourEtapaVistaProvider(widget.etapa).future);
    if (vista || !mounted) return;
    ref.read(tourControllerProvider.notifier).iniciar(widget.etapa);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
