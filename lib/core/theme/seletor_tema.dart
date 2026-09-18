import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
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
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(AppStrings.temaClaro),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(AppStrings.temaSistema),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(AppStrings.temaEscuro),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {atual},
            onSelectionChanged: (selecao) => definir(selecao.first),
          );
        }
        return DropdownButtonFormField<ThemeMode>(
          initialValue: atual,
          decoration: const InputDecoration(labelText: AppStrings.aparencia),
          items: const [
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text(AppStrings.temaClaro),
            ),
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text(AppStrings.temaSistema),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text(AppStrings.temaEscuro),
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
