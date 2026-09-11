import 'package:flutter/material.dart';

/// Ações padronizadas (doc 15 §3). Cobre os botões preenchidos, tonais,
/// contornados, de texto e destrutivos — o destrutivo sempre com foreground
/// explícito para garantir contraste sobre `colorScheme.error`.
enum AppBotaoVariante { filled, tonal, outlined, texto, destrutivo }

class AppBotao extends StatelessWidget {
  const AppBotao({
    super.key,
    required this.rotulo,
    this.onPressed,
    this.icone,
    this.variante = AppBotaoVariante.filled,
    this.carregando = false,
    this.expandido = true,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final AppBotaoVariante variante;
  final bool carregando;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final acao = carregando ? null : onPressed;
    final conteudo = _conteudo(context);

    final botao = switch (variante) {
      AppBotaoVariante.filled => FilledButton(onPressed: acao, child: conteudo),
      AppBotaoVariante.tonal => FilledButton.tonal(
        onPressed: acao,
        child: conteudo,
      ),
      AppBotaoVariante.outlined => OutlinedButton(
        onPressed: acao,
        child: conteudo,
      ),
      AppBotaoVariante.texto => TextButton(onPressed: acao, child: conteudo),
      AppBotaoVariante.destrutivo => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: cores.error,
          foregroundColor: cores.onError,
        ),
        onPressed: acao,
        child: conteudo,
      ),
    };

    return expandido ? SizedBox(width: double.infinity, child: botao) : botao;
  }

  Widget _conteudo(BuildContext context) {
    if (carregando) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(rotulo),
        ],
      );
    }
    if (icone == null) return Text(rotulo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icone), const SizedBox(width: 8), Text(rotulo)],
    );
  }
}
