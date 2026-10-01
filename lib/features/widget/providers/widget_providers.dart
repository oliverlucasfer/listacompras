import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ultima_lista_service.dart';
import '../data/widget_service_home_widget.dart';
import '../domain/widget_service.dart';

final widgetServiceProvider = Provider<WidgetService>(
  (ref) => WidgetServiceHomeWidget(),
);
final ultimaListaServiceProvider = Provider<UltimaListaService>(
  (ref) => UltimaListaService(),
);
