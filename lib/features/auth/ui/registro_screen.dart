import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/texto/validacao.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_politica_privacidade.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../providers/auth_providers.dart';

/// Tela de Registro (wireframe 10 §1.2): e-mail, senha, confirmação,
/// aceite da política e tela "Verifique seu e-mail" após registro.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key, this.next});

  /// Rota de retorno pós-verificação: propagada para o login (doc 08 §3.1).
  final String? next;

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmar = true;
  bool _aceitouPolitica = false;
  String? _erroEmail;
  String? _erroSenha;
  String? _erroConfirmar;
  String? _erroGeral;
  bool _aguardandoVerificacao = false;
  String? _emailRegistrado;
  String? _destino;

  @override
  void initState() {
    super.initState();
    _destino = widget.next;
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() {
      _erroEmail = null;
      _erroSenha = null;
      _erroConfirmar = null;
      _erroGeral = null;
    });

    final email = _email.text.trim();
    final senha = _senha.text;
    var valido = true;
    if (!emailValido(email)) {
      setState(() => _erroEmail = AppStrings.erroEmailInvalido);
      valido = false;
    }
    if (senha.length < 6) {
      setState(() => _erroSenha = AppStrings.erroSenhaCurta);
      valido = false;
    }
    if (_confirmar.text != senha) {
      setState(() => _erroConfirmar = AppStrings.erroSenhasDiferentes);
      valido = false;
    }
    if (!_aceitouPolitica) {
      setState(() => _erroGeral = AppStrings.erroPoliticaPrivacidade);
      valido = false;
    }
    if (!valido) return;

    setState(() => _carregando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .registrar(email: email, senha: senha);
      if (mounted) {
        setState(() {
          _aguardandoVerificacao = true;
          _emailRegistrado = email;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => _erroGeral = e.message.toLowerCase().contains('already')
              ? AppStrings.erroEmailJaCadastrado
              : AppStrings.erroGenerico,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _erroGeral = AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_aguardandoVerificacao) {
      return _VerificacaoEmail(email: _emailRegistrado ?? '', next: _destino);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.criarConta)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.tela,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCampoTexto(
                    controller: _email,
                    label: AppStrings.email,
                    erro: _erroEmail,
                    teclado: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCampoTexto(
                    controller: _senha,
                    label: AppStrings.senha,
                    erro: _erroSenha,
                    senha: _ocultarSenha,
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
                  const SizedBox(height: AppSpacing.lg),
                  AppCampoTexto(
                    controller: _confirmar,
                    label: AppStrings.confirmarSenha,
                    erro: _erroConfirmar,
                    senha: _ocultarConfirmar,
                    onSubmitted: _registrar,
                    sufixo: IconButton(
                      tooltip: _ocultarConfirmar
                          ? AppStrings.mostrarSenha
                          : AppStrings.ocultarSenha,
                      icon: Icon(
                        _ocultarConfirmar
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _ocultarConfirmar = !_ocultarConfirmar,
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _aceitouPolitica,
                    onChanged: (v) =>
                        setState(() => _aceitouPolitica = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.liPoliticaPrivacidade),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => abrirPoliticaPrivacidade(context),
                      child: const Text(AppStrings.verPolitica),
                    ),
                  ),
                  if (_erroGeral != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppBanner(tipo: AppBannerTipo.erro, mensagem: _erroGeral!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppBotao(
                    rotulo: AppStrings.criarConta,
                    carregando: _carregando,
                    onPressed: _registrar,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppBotao(
                    rotulo: AppStrings.entrar,
                    variante: AppBotaoVariante.texto,
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tela "Verifique seu e-mail" (wireframe 10 §1.2) com reenvio de link.
class _VerificacaoEmail extends ConsumerStatefulWidget {
  const _VerificacaoEmail({required this.email, this.next});

  final String email;
  final String? next;

  @override
  ConsumerState<_VerificacaoEmail> createState() => _VerificacaoEmailState();
}

class _VerificacaoEmailState extends ConsumerState<_VerificacaoEmail> {
  bool _reenviando = false;

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);
    try {
      await ref.read(authRepositoryProvider).reenviarVerificacao(widget.email);
      if (mounted) mostrarSnackBar(context, AppStrings.linkReenviado);
    } catch (_) {
      if (mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.verificarSeuEmail)),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.tela,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_unread,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.verificarEmailMensagem,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppBotao(
                  rotulo: AppStrings.reenviarLink,
                  variante: AppBotaoVariante.outlined,
                  carregando: _reenviando,
                  onPressed: _reenviar,
                ),
                AppBotao(
                  rotulo: AppStrings.entrar,
                  variante: AppBotaoVariante.texto,
                  onPressed: () => context.go(
                    widget.next == null || widget.next!.isEmpty
                        ? '/login'
                        : Uri.parse('/login')
                              .replace(queryParameters: {'next': widget.next!})
                              .toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
