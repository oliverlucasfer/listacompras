import 'app_modo.dart';

/// Compara o modo do entrypoint com o pacote instalado (F42/F47). Com flavors,
/// o pacote `...listacompras.lite` implica modo Lite; os demais, colaborativo.
bool modoCompativelComPacote(AppModo modo, String pacote) {
  final ehPacoteLite = pacote.endsWith('.lite');
  return modo == AppModo.lite ? ehPacoteLite : !ehPacoteLite;
}
