part of 'tela_lista_screen.dart';

class _SheetEditarItem extends ConsumerStatefulWidget {
  const _SheetEditarItem({
    required this.item,
    required this.listaId,
    this.onRemover,
  });

  final Item item;
  final String listaId;

  /// Ação de remover (com Desfazer) oferecida dentro do editor (F12-T06);
  /// nula em contextos sem remoção.
  final Future<void> Function()? onRemover;

  @override
  ConsumerState<_SheetEditarItem> createState() => _SheetEditarItemState();
}

class _SheetEditarItemState extends ConsumerState<_SheetEditarItem> {
  late final _nome = TextEditingController(text: widget.item.nome);
  late final _quantidade = TextEditingController(
    text: formatarQuantidade(widget.item.quantidade),
  );
  late Unidade _unidade = widget.item.unidade;
  late CategoriaItem _categoria = widget.item.categoria;
  late final _preco = TextEditingController(
    text: _precoInicial(widget.item.precoCentavos),
  );
  String? _erroNome;
  String? _erroQuantidade;
  String? _erroPreco;

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    _preco.dispose();
    super.dispose();
  }

  String _precoInicial(int? centavos) => centavos == null
      ? ''
      : (centavos / 100).toStringAsFixed(2).replaceAll('.', ',');

  double? _quantidadeLida() {
    final valor = parseQuantidade(_quantidade.text);
    if (valor == null || valor <= 0) return null;
    return valor;
  }

  int? _precoLido() {
    try {
      return parsePrecoParaCentavos(_preco.text);
    } on ArgumentError {
      return null;
    }
  }

  /// Linha de histórico de preços (RF-29, F37): último preço pago + variação
  /// vs o preço atual, apenas quando as unidades casam.
  Widget _linhaHistoricoPreco(HistoricoPreco hist) {
    final registradoEm = hist.registradoEm.toLocal();
    final diaMes =
        '${registradoEm.day.toString().padLeft(2, '0')}/'
        '${registradoEm.month.toString().padLeft(2, '0')}';

    final atual = _precoLido();
    String? variacao;
    Color? corVariacao;
    if (atual != null && _unidade.valor == hist.unidade) {
      final diff = atual - hist.precoCentavos;
      if (diff == 0) {
        variacao = context.l10n.mesmoPreco;
      } else if (diff > 0) {
        variacao = context.l10n.precoSubiu(formatarReais(diff));
        corVariacao = Theme.of(context).colorScheme.error;
      } else {
        variacao = context.l10n.precoBaixou(formatarReais(-diff));
        corVariacao = Theme.of(context).colorScheme.primary;
      }
    }

    final estilo = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.ultimaCompra(
              formatarReais(hist.precoCentavos),
              diaMes,
            ),
            style: estilo,
          ),
          if (variacao != null)
            Text(variacao, style: estilo?.copyWith(color: corVariacao)),
        ],
      ),
    );
  }

  /// Preços por mercado do item (RF-35, F52): mostra o último preço em cada
  /// mercado para a unidade atual, com o mais barato em destaque. Oculta quando
  /// não há histórico com mercado.
  Widget _linhaPorMercado(List<PrecoMercado> precos) {
    final estilo = Theme.of(context).textTheme.bodySmall;
    final destaque = Theme.of(context).colorScheme.primary;
    final menor = precos
        .map((p) => p.precoCentavos)
        .reduce((a, b) => a < b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.porMercado,
            style: estilo?.copyWith(fontWeight: FontWeight.bold),
          ),
          for (final p in precos)
            Text(
              p.precoCentavos == menor
                  ? '${p.mercado}: ${formatarReais(p.precoCentavos)} '
                        '(${context.l10n.maisBarato})'
                  : '${p.mercado}: ${formatarReais(p.precoCentavos)}',
              style: p.precoCentavos == menor
                  ? estilo?.copyWith(
                      color: destaque,
                      fontWeight: FontWeight.bold,
                    )
                  : estilo,
            ),
        ],
      ),
    );
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final quantidade = _quantidadeLida();
    int? preco;
    var precoValido = true;
    try {
      preco = parsePrecoParaCentavos(_preco.text);
    } on ArgumentError {
      precoValido = false;
    }
    setState(() {
      _erroNome = nome.isEmpty ? context.l10n.erroNomeVazio : null;
      _erroQuantidade = quantidade == null
          ? context.l10n.erroQuantidadeInvalida
          : null;
      _erroPreco = precoValido ? null : context.l10n.erroPrecoInvalido;
    });
    if (nome.isEmpty || quantidade == null || !precoValido) return;
    // Avisa (RF-36) se o novo preço fizer o total dos marcados cruzar o
    // orçamento — o editor não passa pelo toggle de concluído.
    if (widget.item.concluido) {
      final itens =
          ref.read(itensDaListaProvider(widget.item.listaId)).value ??
          const <Item>[];
      await talvezAvisarCruzamentoPreco(
        context,
        ref,
        widget.item.listaId,
        itens: itens,
        item: widget.item,
        novoPreco: preco,
      );
    }
    await ref
        .read(listasRepositoryProvider)
        .editarItem(
          widget.item.id,
          nome: nome,
          quantidade: quantidade,
          unidade: _unidade,
          categoria: _categoria,
          precoCentavos: preco,
          limparPreco: preco == null,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hist = ref.watch(historicoPrecoProvider(widget.item.nome)).value;
    final precos =
        ref
            .watch(
              precosPorMercadoProvider((normalizarTexto(_nome.text), _unidade)),
            )
            .value ??
        const <PrecoMercado>[];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.editarItem,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCampoTexto(
            controller: _nome,
            label: context.l10n.nomeDoItem,
            erro: _erroNome,
            onChanged: (_) => setState(() => _erroNome = null),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n.diminuir,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final atual = _quantidadeLida() ?? 1;
                        if (atual > 1) {
                          _quantidade.text = formatarQuantidade(atual - 1);
                          if (_erroQuantidade != null) {
                            setState(() => _erroQuantidade = null);
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: AppCampoTexto(
                        controller: _quantidade,
                        label: context.l10n.quantidade,
                        erro: _erroQuantidade,
                        teclado: TextInputType.text,
                        onChanged: (_) {
                          if (_erroQuantidade != null) {
                            setState(() => _erroQuantidade = null);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.aumentar,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final atual = _quantidadeLida() ?? 1;
                        _quantidade.text = formatarQuantidade(atual + 1);
                        if (_erroQuantidade != null) {
                          setState(() => _erroQuantidade = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppDropdown<Unidade>(
                  label: context.l10n.unidade,
                  expandido: true,
                  valor: _unidade,
                  itens: [
                    for (final u in Unidade.values)
                      DropdownMenuItem(value: u, child: Text(u.valor)),
                  ],
                  onChanged: (u) {
                    if (u != null) setState(() => _unidade = u);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdown<CategoriaItem>(
                  label: context.l10n.categoria,
                  expandido: true,
                  valor: _categoria,
                  itens: [
                    for (final c in CategoriaItem.values)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.rotulo(context)),
                      ),
                  ],
                  onChanged: (c) {
                    if (c != null) setState(() => _categoria = c);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCampoTexto(
                  controller: _preco,
                  label: context.l10n.preco,
                  erro: _erroPreco,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _erroPreco = null),
                ),
              ),
            ],
          ),
          if (hist != null) _linhaHistoricoPreco(hist),
          if (precos.isNotEmpty) _linhaPorMercado(precos),
          const SizedBox(height: AppSpacing.lg),
          // Rodapé sempre sem estouro (RNF-06): o `OverflowBar` externo põe
          // Remover à esquerda e o grupo à direita quando cabem, e só empilha
          // quando não cabe. O interno agrupa Cancelar/Salvar e, **sem
          // `alignment`**, mede apenas o próprio conteúdo — com `alignment`
          // ele reivindicaria toda a largura e o externo sempre acharia que
          // não cabe (empilhando o rodapé em qualquer tela).
          OverflowBar(
            alignment: widget.onRemover == null
                ? MainAxisAlignment.end
                : MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.sm,
            children: [
              if (widget.onRemover != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(widget.onRemover!());
                  },
                  child: Text(
                    context.l10n.removerItem,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              OverflowBar(
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppSpacing.sm,
                overflowSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancelar),
                  ),
                  AppBotao(
                    rotulo: context.l10n.salvar,
                    expandido: false,
                    onPressed: _salvar,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
