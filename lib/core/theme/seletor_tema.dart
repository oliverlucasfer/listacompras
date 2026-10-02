import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../widgets/app_dropdown.dart';
import 'theme_mode_provider.dart';

/// Largura a partir da qual os três segmentos (ícone + rótulo) cabem com
/// folga; abaixo disso o controle vira dropdown (R-20, F21-T01).
const limiarLarguraSegmentado = 360.0;

/// Escala de texto a partir da qual o espaço útil encolhe o bastante para
/// os segmentos estourarem, mesmo em tela larga (R-20, F21-T01).
const limiarEscalaSegmentado = 1.3;

/// Decide a forma do seletor de tema (pura, para testar sem layout):
/// `true` usa [SegmentedButton]; `false` usa dropdown.
bool usarSeletorSegmentado({
  required double largura,
  required double escalaTexto,
}) =>
    largura >= limiarLarguraSegmentado && escalaTexto < limiarEscalaSegmentado;

/// Seletor de aparência (doc 15 §2): Claro / Escuro / Sistema.
/// Adapta-se ao espaço disponível — em telas estreitas ou com fonte ampliada
/// troca os segmentos por um dropdown, que nunca estoura (R-20).
class SeletorTema extends ConsumerWidget {
  const SeletorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(temaModoProvider).value ?? ThemeMode.system;
    final media = MediaQuery.of(context);
    final larguraDisponivel = media.size.width;
    final escala = media.textScaler.scale(14) / 14;

    void definir(ThemeMode modo) =>
        ref.read(temaModoProvider.notifier).definir(modo);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : larguraDisponivel;
        if (usarSeletorSegmentado(largura: largura, escalaTexto: escala)) {
          return SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(context.l10n.temaClaro),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(context.l10n.temaSistema),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(context.l10n.temaEscuro),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {atual},
            onSelectionChanged: (selecao) => definir(selecao.first),
          );
        }
        return AppDropdown<ThemeMode>(
          label: context.l10n.aparencia,
          valor: atual,
          itens: [
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text(context.l10n.temaClaro),
            ),
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text(context.l10n.temaSistema),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text(context.l10n.temaEscuro),
            ),
          ],
          onChanged: (modo) {
            if (modo != null) definir(modo);
          },
        );
      },
    );
  }
}
