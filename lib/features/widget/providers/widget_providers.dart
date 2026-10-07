import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plataforma.dart';
import '../data/ultima_lista_service.dart';
import '../data/widget_service_home_widget.dart';
import '../domain/widget_service.dart';

/// O widget de tela inicial (RF-38) é **Android-only**; em Web/Desktop o
/// `WidgetAtualizador` não é montado e o plugin `home_widget` não é acionado.
bool plataformaComWidget() => apenasAndroid();

final widgetServiceProvider = Provider<WidgetService>(
  (ref) => WidgetServiceHomeWidget(),
);
final ultimaListaServiceProvider = Provider<UltimaListaService>(
  (ref) => UltimaListaService(),
);

/// Última lista aberta (RF-38, F55), reativa: `TelaListaScreen` grava e o
/// `WidgetAtualizador` observa, mantendo o widget em dia na mesma sessão.
class UltimaListaNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(ultimaListaServiceProvider).ler();

  Future<void> registrar(String listaId) async {
    state = AsyncData(listaId);
    await ref.read(ultimaListaServiceProvider).registrar(listaId);
  }
}

final ultimaListaProvider = AsyncNotifierProvider<UltimaListaNotifier, String?>(
  UltimaListaNotifier.new,
);
