import 'package:flutter/material.dart';

import 'core/l10n/app_strings.dart';

/// Placeholder da home até as telas da Fase 3 (doc 05 §2). Confirma que o
/// tema (claro/escuro automático) aplica em Android/Web.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appNome)),
      body: Center(
        child: Text(
          AppStrings.minhasListas,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
