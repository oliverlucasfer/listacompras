import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';
import '../providers/auth_providers.dart';

/// Tela de Login (wireframe 10 §1.1): e-mail, senha com toggle, botão com
/// spinner e erro inline.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Rota de retorno após login bem-sucedido (doc 08 §3.1): o convite passa
  /// `?next=/entrar?token=...`. Vazio → o guard manda para /listas.
  final String? next;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erroEmail;
  String? _erroSenha;
  String? _erroGeral;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  bool _emailValido(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  Future<void> _entrar() async {
    setState(() {
      _erroEmail = null;
      _erroSenha = null;
      _erroGeral = null;
    });

    final email = _email.text.trim();
    final senha = _senha.text;
    var valido = true;
    if (!_emailValido(email)) {
      setState(() => _erroEmail = AppStrings.erroEmailInvalido);
      valido = false;
    }
    if (senha.isEmpty) {
      setState(() => _erroSenha = AppStrings.erroCamposVazios);
      valido = false;
    }
    if (!valido) return;

    setState(() => _carregando = true);
    try {
      await ref.read(authRepositoryProvider).entrar(email: email, senha: senha);
      // Com `next`, volta ao fluxo que originou o login (ex.: aceite do
      // convite); sem next, o guard do router redireciona para /listas.
      final destino = widget.next;
      if (destino != null && destino.isNotEmpty && mounted) {
        context.go(destino);
      }
    } on AuthException {
      if (mounted) setState(() => _erroGeral = AppStrings.erroAutenticacao);
    } catch (_) {
      if (mounted) setState(() => _erroGeral = AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Icon(
                    Icons.shopping_cart,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.appNome,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: AppStrings.email,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_erroEmail != null) ErroInline(mensagem: _erroEmail!),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senha,
                    obscureText: _ocultarSenha,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      labelText: AppStrings.senha,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _ocultarSenha = !_ocultarSenha),
                        icon: Icon(
                          _ocultarSenha
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (_erroSenha != null) ErroInline(mensagem: _erroSenha!),
                  if (_erroGeral != null) ...[
                    const SizedBox(height: 8),
                    ErroInline(mensagem: _erroGeral!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(AppStrings.entrar),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/registro'),
                    child: const Text(AppStrings.criarMinhaConta),
                  ),
                  TextButton(
                    onPressed: () => context.go('/recuperar-senha'),
                    child: const Text(AppStrings.esqueciMinhaSenha),
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
