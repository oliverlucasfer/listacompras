import 'package:flutter/widgets.dart';

import '../dominio/categoria.dart';
import 'l10n.dart';

/// Rótulo localizado da categoria (RF-39, F56): o enum é domínio puro (sem
/// texto de UI); a tradução vive no ARB.
extension CategoriaL10n on CategoriaItem {
  String rotulo(BuildContext context) => switch (this) {
    CategoriaItem.hortifruti => context.l10n.categoriaHortifruti,
    CategoriaItem.mercearia => context.l10n.categoriaMercearia,
    CategoriaItem.frios => context.l10n.categoriaFrios,
    CategoriaItem.laticinios => context.l10n.categoriaLaticinios,
    CategoriaItem.congelados => context.l10n.categoriaCongelados,
    CategoriaItem.padaria => context.l10n.categoriaPadaria,
    CategoriaItem.bebidas => context.l10n.categoriaBebidas,
    CategoriaItem.pet => context.l10n.categoriaPet,
    CategoriaItem.limpeza => context.l10n.categoriaLimpeza,
    CategoriaItem.higiene => context.l10n.categoriaHigiene,
    CategoriaItem.outros => context.l10n.categoriaOutros,
  };
}
