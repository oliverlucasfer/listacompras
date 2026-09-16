import '../../../core/l10n/app_strings.dart';
import 'lista.dart';

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

  String get contagem => AppStrings.progressoLista(concluidos, totalItens);
}
