import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/politica_privacidade.dart';
import '../../../core/theme/seletor_tema.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../auth/providers/auth_providers.dart';

/// Tela Configurações (doc 06 §3, wireframe 10 §5, RF-11): e-mail da conta,
/// política de privacidade, versão e exclusão de conta (confirmação dupla —
/// fluxo completo na F5-T02).
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  void _abrirPolitica(BuildContext context) {
    AppSheet.mostrar<void>(
      context,
      child: SingleChildScrollView(child: Text(politicaPrivacidadeTexto)),
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
    final excluir = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirContaTitulo,
      mensagem: AppStrings.excluirContaMensagemFinal,
      confirmar: AppStrings.excluirConta,
    );
    if (!excluir || !context.mounted) return;
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
          const AppCabecalhoSecao(AppStrings.aparencia),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SeletorTema(),
          ),
          const AppCabecalhoSecao(AppStrings.conta),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.sair),
            onTap: () async {
              await ref.read(authRepositoryProvider).sair();
              if (context.mounted) context.go('/login');
            },
          ),
          const AppCabecalhoSecao(AppStrings.sobre),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppBotao(
                  rotulo: AppStrings.excluirMinhaConta,
                  variante: AppBotaoVariante.destrutivo,
                  icone: Icons.delete_forever_outlined,
                  onPressed: () => _confirmarExclusao(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.excluirMinhaContaAviso,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cores.error),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
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
          const SizedBox(height: AppSpacing.lg),
          AppCampoTexto(
            controller: _senha,
            label: AppStrings.senha,
            erro: _erro,
            senha: true,
            onSubmitted: _continuar,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: _verificando
              ? AppStrings.reautenticando
              : AppStrings.continuar,
          carregando: _verificando,
          expandido: false,
          onPressed: _continuar,
        ),
      ],
    );
  }
}
