import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/convite.dart';
import '../providers/convites_providers.dart';

/// Rota `/entrar?token=...` (doc 08 §1.1, RF-13): destino do deep link de
/// convite. Sem sessão mostra o contexto de convite e envia o usuário ao
/// login/registro com `?next=` de volta; com sessão aceita o convite
/// (RPC idempotente) e navega para a lista.
class EntrarScreen extends ConsumerStatefulWidget {
  const EntrarScreen({super.key, this.token});

  final String? token;

  @override
  ConsumerState<EntrarScreen> createState() => _EntrarScreenState();
}

class _EntrarScreenState extends ConsumerState<EntrarScreen> {
  bool _carregando = false;
  ErroConvite? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processar());
  }

  /// true quando o usuário já tem sessão (chamado pós-mount, então o
  /// read pontual reflete o retorno do login via `?next=`).
  bool get _autenticado => ref.read(authRepositoryProvider).sessaoAtual != null;

  /// Login/registro com `?next=/entrar?token=...` (doc 08 §3.1): retoma o
  /// aceite após autenticação. URIs relativos: replace codifica o valor.
  Uri _rotaLogin({required String base}) => Uri.parse(base).replace(
    queryParameters: {
      'next': Uri.parse('/entrar')
          .replace(
            queryParameters: {if (widget.token != null) 'token': widget.token!},
          )
          .toString(),
    },
  );

  Future<void> _processar() async {
    if (!_autenticado) return;
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(
        () => _erro = const ErroConvite(
          'convite_invalido',
          AppStrings.conviteInvalido,
        ),
      );
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final listaId = await ref.read(convitesRepositoryProvider).aceitar(token);
      if (mounted) context.go('/listas/$listaId');
    } on ErroConvite catch (e) {
      if (mounted) setState(() => _erro = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = const ErroConvite(
            'inesperado',
            AppStrings.conviteInesperado,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_autenticado) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.conviteConvidadoTitulo)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    AppStrings.conviteConvidadoMensagem,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      context.go(_rotaLogin(base: '/login').toString()),
                  child: const Text(AppStrings.conviteConvidadoEntrar),
                ),
                OutlinedButton(
                  onPressed: () =>
                      context.go(_rotaLogin(base: '/registro').toString()),
                  child: const Text(AppStrings.conviteConvidadoRegistrar),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_erro != null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.conviteConvidadoTitulo)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _erro!.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _processar,
                  child: const Text(AppStrings.tentarNovamente),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.conviteConvidadoTitulo)),
      body: const SizedBox.shrink(),
    );
  }
}
