import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../providers/auth_providers.dart';

/// Tela de nova senha (wireframe 10 §1.3, F14-T03): destino do link de
/// recuperação (RF-01). O link autentica o usuário; a expiração cai no erro
/// com CTA "Pedir novo link".
class RedefinirSenhaScreen extends ConsumerStatefulWidget {
  const RedefinirSenhaScreen({super.key});

  @override
  ConsumerState<RedefinirSenhaScreen> createState() =>
      _RedefinirSenhaScreenState();
}

class _RedefinirSenhaScreenState extends ConsumerState<RedefinirSenhaScreen> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;
  bool _carregando = false;
  String? _erroSenha;
  String? _erroConfirmar;
  bool _falhou = false;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final senha = _senha.text;
    final confirmacao = _confirmacao.text;
    final curta = senha.length < 6;
    setState(() {
      _falhou = false;
      _erroSenha = curta ? AppStrings.erroSenhaCurta : null;
      _erroConfirmar = senha == confirmacao
          ? null
          : AppStrings.erroSenhasDiferentes;
    });
    if (curta || senha != confirmacao) return;

    setState(() => _carregando = true);
    try {
      await ref.read(authRepositoryProvider).atualizarSenha(senha);
      if (!mounted) return;
      ref.read(redefinindoSenhaProvider.notifier).concluir();
      mostrarSnackBar(context, AppStrings.senhaAlterada);
      context.go('/listas');
    } on AuthException catch (_) {
      // Link expirado/sessão inválida: oferece pedir novo link (doc 05 §6.1).
      if (mounted) setState(() => _falhou = true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _pedirNovoLink() {
    ref.read(redefinindoSenhaProvider.notifier).concluir();
    context.go('/recuperar-senha');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.definirNovaSenha)),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.tela,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _falhou
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppBanner(
                        tipo: AppBannerTipo.erro,
                        mensagem: AppStrings.erroRedefinirSenha,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppBotao(
                        rotulo: AppStrings.pedirNovoLink,
                        variante: AppBotaoVariante.texto,
                        onPressed: _pedirNovoLink,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCampoTexto(
                        controller: _senha,
                        label: AppStrings.novaSenha,
                        erro: _erroSenha,
                        senha: _ocultarSenha,
                        autofocus: true,
                        onSubmitted: _salvar,
                        sufixo: IconButton(
                          tooltip: _ocultarSenha
                              ? AppStrings.mostrarSenha
                              : AppStrings.ocultarSenha,
                          icon: Icon(
                            _ocultarSenha
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarSenha = !_ocultarSenha),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCampoTexto(
                        controller: _confirmacao,
                        label: AppStrings.confirmarSenha,
                        erro: _erroConfirmar,
                        senha: _ocultarConfirmacao,
                        onSubmitted: _salvar,
                        sufixo: IconButton(
                          tooltip: _ocultarConfirmacao
                              ? AppStrings.mostrarSenha
                              : AppStrings.ocultarSenha,
                          icon: Icon(
                            _ocultarConfirmacao
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _ocultarConfirmacao = !_ocultarConfirmacao,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppBotao(
                        rotulo: AppStrings.salvar,
                        carregando: _carregando,
                        onPressed: _salvar,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
