import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';
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

  bool _emailValido(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

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
    if (!_emailValido(email)) {
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppStrings.email,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_erroEmail != null) ErroInline(mensagem: _erroEmail!),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senha,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.senha,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_erroSenha != null) ErroInline(mensagem: _erroSenha!),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmar,
                    obscureText: true,
                    onSubmitted: (_) => _registrar(),
                    decoration: InputDecoration(
                      labelText: AppStrings.confirmarSenha,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_erroConfirmar != null)
                    ErroInline(mensagem: _erroConfirmar!),
                  CheckboxListTile(
                    value: _aceitouPolitica,
                    onChanged: (v) =>
                        setState(() => _aceitouPolitica = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.liPoliticaPrivacidade),
                  ),
                  if (_erroGeral != null) ErroInline(mensagem: _erroGeral!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _carregando ? null : _registrar,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.criarConta),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(AppStrings.entrar),
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
class _VerificacaoEmail extends ConsumerWidget {
  const _VerificacaoEmail({required this.email, this.next});

  final String email;
  final String? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.verificarSeuEmail)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
                Text(
                  AppStrings.verificarEmailMensagem,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => ref
                      .read(authRepositoryProvider)
                      .reenviarVerificacao(email),
                  child: const Text(AppStrings.reenviarLink),
                ),
                TextButton(
                  onPressed: () => context.go(
                    next == null || next!.isEmpty
                        ? '/login'
                        : Uri.parse('/login')
                              .replace(queryParameters: {'next': next!})
                              .toString(),
                  ),
                  child: const Text(AppStrings.entrar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
