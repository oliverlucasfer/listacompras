part of 'tela_lista_screen.dart';

class _ListaItens extends ConsumerWidget {
  const _ListaItens({
    required this.listaId,
    required this.consulta,
    this.onLimparBusca,
  });

  final String listaId;
  final ValueNotifier<String> consulta;
  final VoidCallback? onLimparBusca;

  bool _casa(Item item, String valorConsulta) =>
      valorConsulta.trim().isEmpty || contemBusca(item.nome, valorConsulta);

  Future<void> _reordenarGrupo(
    BuildContext context,
    WidgetRef ref,
    CategoriaItem categoria,
    List<Item> grupo,
    int oldIndex,
    int newIndex,
  ) async {
    // Drag é restrito ao grupo (F6-T04, spec §6): reordena só os ids do
    // grupo; a exibição ordena por (categoria, ordem, id).
    final ordenados = [...grupo]
      ..removeAt(oldIndex)
      ..insert(newIndex, grupo[oldIndex]);
    try {
      await ref.read(listasRepositoryProvider).reordenarItens(listaId, [
        for (final i in ordenados) i.id,
      ]);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itensAsync = ref.watch(itensDaListaProvider(listaId));
    // Grupos na ordem pessoal das categorias (RF-24), com fallback para o
    // enum (doc 01 §3.2) enquanto a preferência carrega.
    final ordemCategorias =
        ref.watch(ordemCategoriasProvider).value ?? CategoriaItem.values;
    return itensAsync.when(
      loading: () => const AppEsqueleto(linhas: 5),
      error: (_, _) => AppEstadoErro(
        mensagem: context.l10n.erroGenerico,
        onRetentar: () => ref.invalidate(itensDaListaProvider(listaId)),
      ),
      // A busca fica num [ValueNotifier] próprio: digitar reconstrói só a
      // lista filtrada, sem refazer os `ref.watch` acima nem a tela inteira.
      data: (itens) => ValueListenableBuilder<String>(
        valueListenable: consulta,
        builder: (context, valorConsulta, _) =>
            _itens(context, ref, itens, ordemCategorias, valorConsulta),
      ),
    );
  }

  Widget _itens(
    BuildContext context,
    WidgetRef ref,
    List<Item> itens,
    List<CategoriaItem> ordemCategorias,
    String valorConsulta,
  ) {
    if (itens.isEmpty) {
      return AppEstadoVazio(
        icone: Icons.shopping_basket_outlined,
        titulo: context.l10n.nenhumItem,
        descricao: context.l10n.nenhumItemDica,
      );
    }
    // Passada única: separa pendentes/concluídos e monta os grupos por
    // categoria preservando a ordem de exibição (categoria, ordem, id) —
    // o stream já chega ordenado por (ordem, id).
    final pendentes = <Item>[];
    final concluidos = <Item>[];
    final grupos = <CategoriaItem, List<Item>>{};
    for (final item in itens) {
      if (!_casa(item, valorConsulta)) continue;
      if (item.concluido) {
        concluidos.add(item);
      } else {
        pendentes.add(item);
        grupos.putIfAbsent(item.categoria, () => <Item>[]).add(item);
      }
    }
    final filtrando = valorConsulta.trim().isNotEmpty;
    if (filtrando && pendentes.isEmpty && concluidos.isEmpty) {
      return AppEstadoVazio(
        icone: Icons.search_off,
        titulo: context.l10n.nenhumItemEncontrado,
        descricao: context.l10n.buscaSemResultadoDica,
        acao: AppBotao(
          rotulo: context.l10n.limparBusca,
          variante: AppBotaoVariante.texto,
          expandido: false,
          onPressed: onLimparBusca,
        ),
      );
    }
    final slivers = <Widget>[];
    // Primeiro item pendente na ordem exibida: alvo do passo do tour
    // (RF-27, F46). O loader também só existe quando há item ativo.
    String? alvoTourId;
    for (final categoria in ordemCategorias) {
      final grupo = grupos[categoria];
      if (grupo != null && grupo.isNotEmpty) {
        alvoTourId = grupo.first.id;
        break;
      }
    }
    if (pendentes.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(child: TourLoader(etapa: TourEtapa.recursos)),
      );
    }
    for (final categoria in ordemCategorias) {
      final grupo = grupos[categoria];
      if (grupo == null || grupo.isEmpty) continue;
      slivers
        ..add(
          SliverToBoxAdapter(
            child: AppCabecalhoSecao(
              categoria.rotulo(context),
              contagem: grupo.length,
            ),
          ),
        )
        ..add(
          !filtrando
              ? SliverReorderableList(
                  itemCount: grupo.length,
                  onReorderItem: (oldIndex, newIndex) => _reordenarGrupo(
                    context,
                    ref,
                    categoria,
                    grupo,
                    oldIndex,
                    newIndex,
                  ),
                  itemBuilder: (context, index) => _LinhaItem(
                    key: ValueKey(grupo[index].id),
                    listaId: listaId,
                    item: grupo[index],
                    index: index,
                    tourAlvo: grupo[index].id == alvoTourId,
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _LinhaItem(
                      key: ValueKey(grupo[index].id),
                      listaId: listaId,
                      item: grupo[index],
                      index: -1,
                      tourAlvo: grupo[index].id == alvoTourId,
                    ),
                    childCount: grupo.length,
                  ),
                ),
        );
    }
    if (concluidos.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: ExpansionTile(
            tilePadding: AppSpacing.horizontal,
            title: Text(
              '${context.l10n.itensConcluidos} (${concluidos.length})',
            ),
            children: [
              for (final item in concluidos)
                _LinhaItem(
                  key: ValueKey(item.id),
                  listaId: listaId,
                  item: item,
                  index: -1,
                ),
            ],
          ),
        ),
      );
    }
    slivers.add(
      const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
    );
    return CustomScrollView(slivers: slivers);
  }
}
