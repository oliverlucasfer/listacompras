import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/politica_privacidade.dart';
import '../../auth/providers/auth_providers.dart';

/// Tela Configurações (doc 06 §3, wireframe 10 §5, RF-11): e-mail da conta,
/// política de privacidade, versão e exclusão de conta (confirmação dupla —
/// fluxo completo na F5-T02).
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  void _abrirPolitica(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Text(politicaPrivacidadeTexto),
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref) async {
    // Fluxo de confirmação dupla (doc 06 §3.3.1) — implementado na F5-T02.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = Theme.of(context).colorScheme;
    final email = ref.watch(emailUsuarioProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.configuracoes)),
      body: ListView(
        children: [
          const _CabecalhoSecao(AppStrings.conta),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(email ?? ''),
          ),
          const _CabecalhoSecao(AppStrings.sobre),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(AppStrings.politicaPrivacidade),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirPolitica(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppStrings.versao),
            trailing: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) =>
                  Text(snapshot.data?.version ?? '—'),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cores.error,
                    foregroundColor: cores.onError,
                  ),
                  onPressed: () => _confirmarExclusao(context, ref),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text(AppStrings.excluirMinhaConta),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.excluirMinhaContaAviso,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cores.error),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoSecao extends StatelessWidget {
  const _CabecalhoSecao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
