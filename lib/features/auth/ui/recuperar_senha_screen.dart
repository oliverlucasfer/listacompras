import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';
import '../providers/auth_providers.dart';

/// Tela de Recuperação de senha (wireframe 10 §1.2): envia link único
/// (expira conforme Supabase).
class RecuperarSenhaScreen extends ConsumerStatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  ConsumerState<RecuperarSenhaScreen> createState() =>
      _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends ConsumerState<RecuperarSenhaScreen> {
  final _email = TextEditingController();
  bool _carregando = false;
  bool _enviado = false;
  String? _erroEmail;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valido) {
      setState(() => _erroEmail = AppStrings.erroEmailInvalido);
      return;
    }
    setState(() {
      _erroEmail = null;
      _carregando = true;
    });
    try {
      await ref.read(authRepositoryProvider).enviarRecuperacaoSenha(email);
      if (mounted) setState(() => _enviado = true);
    } catch (_) {
      // Não revela existência do e-mail; mensagem neutra (wireframe).
      if (mounted) setState(() => _enviado = true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.recuperarSenha)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _enviado
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mark_email_read,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(AppStrings.linkEnviado),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Informe seu e-mail:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: AppStrings.email,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_erroEmail != null) ErroInline(mensagem: _erroEmail!),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _carregando ? null : _enviar,
                        child: _carregando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(AppStrings.enviarLinkEmail),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Link único, expira conforme configuração do serviço.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
