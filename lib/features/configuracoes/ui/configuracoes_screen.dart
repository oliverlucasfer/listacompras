import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Confirmação dupla (doc 06 §3.3.1): 1) senha com reautenticação,
    // 2) diálogo final — "Esta ação é permanente...".
    final autenticou = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoSenhaExclusao(),
    );
    if (autenticou != true || !context.mounted) return;
    final excluir = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.excluirContaTitulo),
        content: const Text(AppStrings.excluirContaMensagemFinal),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancelar),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.excluirConta),
          ),
        ],
      ),
    );
    if (excluir != true || !context.mounted) return;
    await _excluirConta(context, ref);
  }

  Future<void> _excluirConta(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppStrings.excluindoConta),
          ],
        ),
      ),
    );
    try {
      // O bootstrap (doc 03 §7) detecta o fim da sessão e limpa cache/fila.
      await ref.read(authRepositoryProvider).excluirConta();
      if (context.mounted) Navigator.pop(context);
    } on Exception {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(AppStrings.erroGenerico)),
          );
      }
    }
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

/// Passo 1 da confirmação dupla: reautenticação por senha (doc 06 §3.3.1).
class _DialogoSenhaExclusao extends ConsumerStatefulWidget {
  const _DialogoSenhaExclusao();

  @override
  ConsumerState<_DialogoSenhaExclusao> createState() =>
      _DialogoSenhaExclusaoState();
}

class _DialogoSenhaExclusaoState extends ConsumerState<_DialogoSenhaExclusao> {
  final _senha = TextEditingController();
  bool _verificando = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    setState(() {
      _verificando = true;
      _erro = null;
    });
    final email = ref.watch(emailUsuarioProvider);
    try {
      await ref
          .read(authRepositoryProvider)
          .entrar(email: email ?? '', senha: _senha.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthException {
      if (mounted) {
        setState(() {
          _verificando = false;
          _erro = AppStrings.senhaIncorreta;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.excluirContaTitulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.excluirContaSenhaMensagem),
          const SizedBox(height: 16),
          TextField(
            controller: _senha,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _continuar(),
            decoration: InputDecoration(
              labelText: AppStrings.senha,
              border: const OutlineInputBorder(),
              errorText: _erro,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancelar),
        ),
        FilledButton(
          onPressed: _verificando ? null : _continuar,
          child: _verificando
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(AppStrings.reautenticando),
                  ],
                )
              : const Text(AppStrings.continuar),
        ),
      ],
    );
  }
}
