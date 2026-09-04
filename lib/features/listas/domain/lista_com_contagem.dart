import '../domain/lista.dart';

/// Lista com contagem de itens para o card do painel (wireframe 10 §2.1:
/// "3/10 itens concluídos"). Itens com tombstone ficam fora da contagem.
class ListaComContagem {
  const ListaComContagem({
    required this.lista,
    required this.totalItens,
    required this.concluidos,
  });

  final Lista lista;
  final int totalItens;
  final int concluidos;

  String get contagem {
    final palavra = totalItens == 1 ? 'item concluído' : 'itens concluídos';
    return '$concluidos/$totalItens $palavra';
  }
}
