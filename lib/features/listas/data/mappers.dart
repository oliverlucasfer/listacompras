import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';
import '../domain/historico_preco.dart';
import '../domain/item.dart';
import '../domain/lista.dart';

/// Mapeia as linhas do Drift para as entidades de domínio — mantém o domínio
/// puro (sem `import drift/database.dart`).
extension ItemLocalDataDominio on ItemLocalData {
  Item toDomain() => Item(
    id: id,
    listaId: listaId,
    nome: nome,
    quantidade: quantidade,
    unidade: Unidade.fromValor(unidade),
    categoria: CategoriaItem.fromValor(categoria),
    concluido: concluido,
    ordem: ordem,
    criadoEm: createdAt,
    atualizadoEm: updatedAt,
    precoCentavos: precoCentavos,
  );
}

extension ListaLocalDataDominio on ListaLocalData {
  Lista toDomain() => Lista(
    id: id,
    titulo: titulo,
    donoId: donoId,
    criadoEm: createdAt,
    atualizadoEm: updatedAt,
    arquivadaEm: arquivadaEm,
    orcamentoCentavos: orcamentoCentavos,
  );
}

extension HistoricoPrecoLocalDataDominio on HistoricoPrecoLocalData {
  HistoricoPreco toDomain() => HistoricoPreco(
    precoCentavos: precoCentavos,
    unidade: unidade,
    registradoEm: registradoEm,
  );
}
