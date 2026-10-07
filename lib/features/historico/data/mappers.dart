import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';
import '../domain/ida.dart';

/// Mapeia as linhas do Drift para as entidades de domínio do histórico —
/// mantém o domínio puro (sem `import drift/database.dart`).
extension IdaCompraDataDominio on IdaCompraData {
  Ida toDomain() => Ida(
    id: id,
    listaId: listaId,
    titulo: titulo,
    finalizadaEm: finalizadaEm,
    totalCentavos: totalCentavos,
    itensCount: itensCount,
    mercado: mercado,
  );
}

extension ItemIdaDataDominio on ItemIdaData {
  ItemDaIda toDomain() => ItemDaIda(
    id: id,
    idaId: idaId,
    nome: nome,
    quantidade: quantidade,
    unidade: Unidade.fromValor(unidade),
    categoria: CategoriaItem.fromValor(categoria),
    precoCentavos: precoCentavos,
  );
}
