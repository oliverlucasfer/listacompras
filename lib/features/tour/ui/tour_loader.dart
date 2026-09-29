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
  static const _maxTentativas = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _talvezIniciar());
  }

  /// Tenta iniciar a etapa até os alvos ficarem visíveis. A home monta o loader
  /// no mesmo frame em que acabou de construir os alvos (pós-boas-vindas), e a
  /// etapa 2 depende de dados assíncronos; uma única tentativa corria antes dos
  /// alvos e o tour nunca abria.
  Future<void> _talvezIniciar() async {
    final vista = await ref.read(tourEtapaVistaProvider(widget.etapa).future);
    if (vista) return;
    for (var i = 0; i < _maxTentativas; i++) {
      if (!mounted) return;
      if (ref.read(tourControllerProvider.notifier).iniciar(widget.etapa)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
