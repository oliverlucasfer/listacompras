import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import 'theme_mode_provider.dart';

/// Seletor de aparência (doc 15 §2): Claro / Escuro / Sistema.
class SeletorTema extends ConsumerWidget {
  const SeletorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(temaModoProvider).value ?? ThemeMode.system;
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
      onSelectionChanged: (selecao) =>
          ref.read(temaModoProvider.notifier).definir(selecao.first),
    );
  }
}
