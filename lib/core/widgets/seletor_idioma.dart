import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../idioma/idioma_provider.dart';
import '../l10n/l10n.dart';
import 'app_dropdown.dart';

/// Largura a partir da qual os quatro segmentos (Sistema/Português/English/
/// Español) cabem com folga; abaixo disso o controle vira dropdown (R-20).
const limiarLarguraIdioma = 520.0;

/// Escala de texto a partir da qual o espaço útil encolhe o bastante para os
/// segmentos estourarem, mesmo em tela larga (R-20).
const limiarEscalaIdioma = 1.3;

/// Decide a forma do seletor de idioma (pura, para testar sem layout):
/// `true` usa [SegmentedButton]; `false` usa dropdown.
bool usarSeletorIdiomaSegmentado({
  required double largura,
  required double escalaTexto,
}) => largura >= limiarLarguraIdioma && escalaTexto < limiarEscalaIdioma;

/// Seletor de idioma (RF-39, F56): Sistema / Português / English / Español.
/// Adapta-se ao espaço disponível — em telas estreitas ou com fonte ampliada
/// troca os segmentos por um dropdown, que nunca estoura (R-20).
class SeletorIdioma extends ConsumerWidget {
  const SeletorIdioma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final atual = ref.watch(idiomaProvider).value ?? IdiomaApp.sistema;
    final media = MediaQuery.of(context);
    final larguraDisponivel = media.size.width;
    final escala = media.textScaler.scale(14) / 14;

    void selecionar(IdiomaApp idioma) =>
        ref.read(idiomaProvider.notifier).selecionar(idioma);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : larguraDisponivel;
        if (usarSeletorIdiomaSegmentado(
          largura: largura,
          escalaTexto: escala,
        )) {
          return SegmentedButton<IdiomaApp>(
            segments: [
              ButtonSegment(
                value: IdiomaApp.sistema,
                label: Text(l10n.idiomaSistema),
              ),
              ButtonSegment(
                value: IdiomaApp.pt,
                label: Text(l10n.idiomaPortugues),
              ),
              ButtonSegment(
                value: IdiomaApp.en,
                label: Text(l10n.idiomaIngles),
              ),
              ButtonSegment(
                value: IdiomaApp.es,
                label: Text(l10n.idiomaEspanhol),
              ),
            ],
            selected: {atual},
            onSelectionChanged: (selecao) => selecionar(selecao.first),
          );
        }
        return AppDropdown<IdiomaApp>(
          label: l10n.idiomaTitulo,
          valor: atual,
          itens: [
            DropdownMenuItem(
              value: IdiomaApp.sistema,
              child: Text(l10n.idiomaSistema),
            ),
            DropdownMenuItem(
              value: IdiomaApp.pt,
              child: Text(l10n.idiomaPortugues),
            ),
            DropdownMenuItem(
              value: IdiomaApp.en,
              child: Text(l10n.idiomaIngles),
            ),
            DropdownMenuItem(
              value: IdiomaApp.es,
              child: Text(l10n.idiomaEspanhol),
            ),
          ],
          onChanged: (idioma) {
            if (idioma != null) selecionar(idioma);
          },
        );
      },
    );
  }
}
