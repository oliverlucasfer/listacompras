class WidgetDados {
  const WidgetDados({required this.titulo, required this.pendentes});
  final String? titulo;
  final int pendentes;
}

/// Ponte com o widget da tela inicial (Android, RF-38). Fake nos testes.
abstract interface class WidgetService {
  Future<void> atualizar(WidgetDados dados);
  Future<String?> toqueInicial();
  Stream<String> toques();
}
