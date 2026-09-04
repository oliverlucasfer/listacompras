import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../auth/providers/auth_providers.dart';

/// Placeholder do Painel Minhas Listas — implementação completa na F3-T05.
/// Serve para validar o guard de rotas da F3-T03.
class ListasPlaceholder extends ConsumerWidget {
  const ListasPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.minhasListas),
        actions: [
          IconButton(
            tooltip: AppStrings.sair,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).sair();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: const Center(child: Text(AppStrings.minhasListas)),
    );
  }
}
