part of 'tela_lista_screen.dart';

class _DialogoOrcamento extends StatefulWidget {
  const _DialogoOrcamento({
    required this.orcamentoCentavos,
    required this.onSalvar,
    required this.onRemover,
  });

  /// Orçamento atual em centavos; `null` = lista sem orçamento.
  final int? orcamentoCentavos;

  /// Grava o orçamento (offline-first, via repositório).
  final Future<void> Function(int centavos) onSalvar;

  /// Remove o orçamento existente.
  final Future<void> Function() onRemover;

  @override
  State<_DialogoOrcamento> createState() => _DialogoOrcamentoState();
}

class _DialogoOrcamentoState extends State<_DialogoOrcamento> {
  late final _campo = TextEditingController(
    text: widget.orcamentoCentavos == null
        ? ''
        : formatarReais(widget.orcamentoCentavos!),
  );
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// Executa a escrita (salvar/remover), fecha o diálogo e mostra o feedback;
  /// em falha mantém o diálogo aberto com o erro genérico inline.
  Future<void> _executar(Future<void> Function() acao, String mensagem) async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await acao();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = context.l10n.erroGenerico;
          _ocupado = false;
        });
      }
      return;
    }
    if (!mounted) return;
    mostrarSnackBar(context, mensagem);
    Navigator.pop(context);
  }

  Future<void> _salvar() async {
    int? lido;
    try {
      lido = parsePrecoParaCentavos(_campo.text);
    } on ArgumentError {
      setState(() => _erro = context.l10n.erroOrcamentoInvalido);
      return;
    }
    if (lido == null) {
      setState(() => _erro = context.l10n.erroOrcamentoInvalido);
      return;
    }
    final centavos = lido;
    await _executar(
      () => widget.onSalvar(centavos),
      context.l10n.orcamentoDefinido,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.orcamento),
      content: AppCampoTexto(
        controller: _campo,
        label: context.l10n.campoOrcamento,
        erro: _erro,
        autofocus: true,
        teclado: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          if (_erro != null) setState(() => _erro = null);
        },
      ),
      actions: [
        if (widget.orcamentoCentavos != null)
          TextButton(
            onPressed: _ocupado
                ? null
                : () => _executar(
                    widget.onRemover,
                    context.l10n.orcamentoRemovido,
                  ),
            child: Text(
              context.l10n.removerOrcamento,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelar),
        ),
        AppBotao(
          rotulo: context.l10n.salvar,
          expandido: false,
          carregando: _ocupado,
          onPressed: _salvar,
        ),
      ],
    );
  }
}
