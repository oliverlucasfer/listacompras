import '../../../core/dominio/categoria.dart';

/// Ordem completa: começa pela ordem salva (ignorando duplicatas) e anexa as
/// categorias ausentes na ordem do enum — uma categoria nova nunca some da UI.
List<CategoriaItem> normalizarOrdem(List<CategoriaItem> salva) {
  final vistas = <CategoriaItem>{};
  final ordem = <CategoriaItem>[];
  for (final c in salva) {
    if (vistas.add(c)) ordem.add(c);
  }
  for (final c in CategoriaItem.values) {
    if (vistas.add(c)) ordem.add(c);
  }
  return ordem;
}

/// CSV de `CategoriaItem.valor`.
String serializarOrdem(List<CategoriaItem> ordem) =>
    normalizarOrdem(ordem).map((c) => c.valor).join(',');

/// Desserializa o CSV; desconhecidas são ignoradas e a ordem é normalizada.
/// `null`/vazio → ordem padrão do enum.
List<CategoriaItem> desserializarOrdem(String? csv) {
  if (csv == null || csv.trim().isEmpty) return List.of(CategoriaItem.values);
  final porValor = {for (final c in CategoriaItem.values) c.valor: c};
  final lida = <CategoriaItem>[];
  for (final parte in csv.split(',')) {
    final c = porValor[parte.trim()];
    if (c != null) lida.add(c);
  }
  return normalizarOrdem(lida);
}

/// Converte o índice final do `onReorderItem` (já ajustado pelo Flutter) no
/// índice cru que o `onReorder`/`moverItem` esperam.
int indiceCruDeReordenacao(int oldIndex, int newIndex) =>
    newIndex > oldIndex ? newIndex + 1 : newIndex;

/// Move `oldIndex` para `newIndex` (mesma semântica do `onReorder` do
/// `ReorderableListView`: ao descer, o índice final é decrementado).
List<T> moverItem<T>(List<T> lista, int oldIndex, int newIndex) {
  final copia = [...lista];
  var destino = newIndex;
  if (destino > oldIndex) destino -= 1;
  final item = copia.removeAt(oldIndex);
  copia.insert(destino, item);
  return copia;
}
