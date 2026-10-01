import 'package:home_widget/home_widget.dart';

import '../domain/widget_service.dart';

/// FQCN do provider nativo: a `applicationId` difere do `namespace`, então o
/// `home_widget` precisa do nome totalmente qualificado para achar a classe.
const nomeAppWidgetQualificado =
    'br.com.oliverlucas.lista_compras.MinhasListasWidgetProvider';

class WidgetServiceHomeWidget implements WidgetService {
  @override
  Future<void> atualizar(WidgetDados dados) async {
    await HomeWidget.saveWidgetData<String>('titulo', dados.titulo ?? '');
    await HomeWidget.saveWidgetData<int>('pendentes', dados.pendentes);
    await HomeWidget.saveWidgetData<bool>('tem_lista', dados.titulo != null);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: nomeAppWidgetQualificado,
    );
  }

  @override
  Future<String?> toqueInicial() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return uri?.host;
  }

  @override
  Stream<String> toques() => HomeWidget.widgetClicked
      .map((uri) => uri?.host ?? '')
      .where((h) => h.isNotEmpty);
}
