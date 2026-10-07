part of 'tela_lista_screen.dart';

class _LinhaItem extends ConsumerWidget {
  const _LinhaItem({
    super.key,
    required this.listaId,
    required this.item,
    required this.index,
    this.tourAlvo = false,
  });

  final String listaId;
  final Item item;

  /// Posição na seção reordenável; concluídos não participam (-1).
  final int index;

  /// Primeira linha ativa: ancora o passo do tour (RF-27, F46).
  final bool tourAlvo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linha = ListTile(
      key: tourAlvo ? TourKeys.itemLista : null,
      // Tocar no item abre o editor (F12-T06) — o swipe continua disponível.
      onTap: () => _abrirSheetEditar(context, ref),
      // O checkbox recebe o nome do item como rótulo (doc 15 §4): sem isso o
      // leitor de tela anuncia uma caixa de seleção sem contexto.
      leading: MergeSemantics(
        child: Semantics(
          label: item.nome,
          child: Checkbox(
            value: item.concluido,
            onChanged: (_) => _alternar(context, ref),
          ),
        ),
      ),
      title: Text(
        item.nome,
        style: item.concluido
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatarQuantidadeComUnidade(item.quantidade, item.unidade)),
          if (index >= 0)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.drag_handle,
                  size: 24,
                  semanticLabel: context.l10n.reordenar,
                ),
              ),
            ),
        ],
      ),
    );
    return Dismissible(
      key: key!,
      background: _FundoSwipe(
        alinhamento: Alignment.centerLeft,
        icone: Icons.edit_outlined,
        cor: Theme.of(context).colorScheme.primaryContainer,
      ),
      secondaryBackground: _FundoSwipe(
        alinhamento: Alignment.centerRight,
        icone: Icons.delete_outline,
        cor: Theme.of(context).colorScheme.errorContainer,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _abrirSheetEditar(context, ref);
          return false;
        }
        return _removerComUndo(context, ref);
      },
      child: linha,
    );
  }

  /// Marca/desmarca o item avisando antes se o total cruzar o orçamento
  /// (RF-36, F53-T03). O aviso usa os itens atuais (antes da escrita).
  Future<void> _alternar(BuildContext context, WidgetRef ref) async {
    final itens =
        ref.read(itensDaListaProvider(listaId)).value ?? const <Item>[];
    final marcando = !item.concluido;
    await talvezAvisarCruzamento(
      context,
      ref,
      listaId,
      itens: itens,
      item: item,
      marcando: marcando,
    );
    try {
      await ref
          .read(itensRepositoryProvider)
          .editarItem(item.id, concluido: marcando);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
    }
  }

  /// Remove o item e oferece Desfazer (usado pelo swipe e pelo diálogo).
  /// Devolve `false` se a escrita falhar (o swipe não confirma a remoção).
  Future<bool> _removerComUndo(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(itensRepositoryProvider);
    try {
      await repo.removerItem(item.id);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
      return false;
    }
    if (!context.mounted) return true;
    // O contexto da linha é desmontado quando o stream remove o item; captura
    // o messenger e a mensagem de erro antes, para o Desfazer conseguir
    // reportar uma falha de restauração sem tocar num contexto morto.
    final messenger = ScaffoldMessenger.of(context);
    final erro = context.l10n.erroGenerico;
    mostrarSnackBar(
      context,
      context.l10n.itemRemovido,
      rotuloAcao: context.l10n.desfazer,
      messenger: messenger,
      onAcao: () async {
        try {
          await repo.restaurarItem(item.id);
        } catch (_) {
          mostrarSnackBarComMessenger(messenger, erro);
        }
      },
    );
    return true;
  }

  Future<void> _abrirSheetEditar(BuildContext context, WidgetRef ref) async {
    await AppSheet.mostrar<void>(
      context,
      child: _SheetEditarItem(
        item: item,
        onRemover: () => _removerComUndo(context, ref),
      ),
    );
  }
}

class _FundoSwipe extends StatelessWidget {
  const _FundoSwipe({
    required this.alinhamento,
    required this.icone,
    required this.cor,
  });

  final Alignment alinhamento;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cor,
      alignment: alinhamento,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Icon(icone),
    );
  }
}
