import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';

/// Bloco recolhível com o **texto bruto** reconhecido pelo OCR (RF-40).
///
/// Diagnóstico: permite ver e copiar o que o OCR leu — útil quando o preço não
/// foi reconhecido ou veio errado. Fechado por padrão; não grava nem persiste
/// nada (a imagem também não é armazenada).
class TextoLidoOcr extends StatelessWidget {
  const TextoLidoOcr({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(context.l10n.etiquetaTextoLido),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
