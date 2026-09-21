import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/navigation/voltar_para_inicio.dart';
import '../../../core/texto/busca.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../../convites/data/papel_repository.dart';
import '../../convites/domain/papel.dart';
import '../../convites/providers/papel_providers.dart';
import '../../convites/ui/sheet_convidar.dart';
import '../../convites/ui/tela_membros_screen.dart';
import '../../importacao/ui/modal_importar.dart';
import '../../importacao/ui/modal_previsao_importacao.dart';
import '../../sync/ui/indicador_sync.dart';
import '../domain/categoria.dart';
import '../domain/item.dart';
import '../domain/preco.dart';
import '../domain/resultado_dedup.dart';
import '../domain/sugestao_item.dart';
import '../domain/unidade.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';
import 'total_carrinho.dart';

/// Tela da Lista de Compras (doc 05 §6.3, wireframe 10 §3.1, RF-03/RF-04).
/// Indicador de sync (F4-T07), IA (F4-T01) e drag-and-drop (F4-T05) chegam depois.
class TelaListaScreen extends ConsumerStatefulWidget {
  const TelaListaScreen({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<TelaListaScreen> createState() => _TelaListaScreenState();
}

class _TelaListaScreenState extends ConsumerState<TelaListaScreen> {
  PapelRepository? _papelRepo;
  ValueNotifier<String?>? _membroEntrou;
  ValueNotifier<String?>? _donoTransferido;
  final _busca = TextEditingController();
  bool _buscando = false;

  /// Papel efetivo na lista (F7-T03 + correção): o dono é derivado da própria
  /// lista local antes do papel do servidor (editável offline/após reinício).
  Papel _papelNaLista(String listaId) =>
      ref.watch(papelEfetivoProvider(listaId));

  /// Feedback "membro entrou" (doc 08 §7, F7-T07): realtime INSERT de
  /// outro membro sinaliza o notifier — só a tela aberta da mesma lista
  /// mostra o SnackBar (sem nome, o RLS não expõe outros perfis).
  void _aoMembroEntrar() {
    final listaId = _membroEntrou?.value;
    if (listaId == null || listaId != widget.listaId || !mounted) return;
    _papelRepo?.consumirEntrada();
    mostrarSnackBar(context, AppStrings.membroEntrou);
  }

  /// Feedback "você agora é dono" (RF-14): UPDATE de `lista_membros` que
  /// promove o usuário a dono sinaliza o notifier — sem nome, o RLS não
  /// expõe perfis.
  void _aoVirarDono() {
    final listaId = _donoTransferido?.value;
    if (listaId == null || listaId != widget.listaId || !mounted) return;
    _papelRepo?.consumirDono();
    mostrarSnackBar(context, AppStrings.voceAgoraDono);
  }

  @override
  void initState() {
    super.initState();
    _papelRepo = ref.read(papelRepositoryProvider);
    _membroEntrou = _papelRepo?.membroEntrou;
    _membroEntrou?.addListener(_aoMembroEntrar);
    _donoTransferido = _papelRepo?.donoTransferido;
    _donoTransferido?.addListener(_aoVirarDono);
  }

  @override
  void dispose() {
    _busca.dispose();
    _membroEntrou?.removeListener(_aoMembroEntrar);
    _donoTransferido?.removeListener(_aoVirarDono);
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    if (!mounted) return;
    _busca.clear();
    setState(() => _buscando = false);
  }

  void _limparBusca() {
    if (!mounted) return;
    _busca.clear();
    setState(() {});
  }

  void _acaoMenu(
    BuildContext context,
    WidgetRef ref,
    String idLista,
    String acao,
  ) {
    final repo = ref.read(listasRepositoryProvider);
    switch (acao) {
      case 'desmarcar':
        repo.desmarcarTodos(idLista);
      case 'limpar':
        _confirmarLimparConcluidos(context, ref, idLista);
      case 'renomear':
        abrirSheetTitulo(
          context,
          titulo: AppStrings.renomearLista,
          rotuloBotao: AppStrings.salvar,
          mensagemSucesso: AppStrings.listaRenomeada,
          onSalvar: (nome) => repo.renomearLista(id: idLista, titulo: nome),
        );
      case 'excluir':
        _confirmarExcluirLista(context, ref, idLista);
      case 'convidar':
        abrirSheetConvidar(context, ref, idLista);
      case 'membros':
        context.push('/membros/$idLista');
    }
  }

  Future<void> _confirmarLimparConcluidos(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.limparConcluidos,
      mensagem: AppStrings.limparConcluidosMensagem,
      confirmar: AppStrings.limpar,
    );
    if (!confirmou) return;
    final repo = ref.read(listasRepositoryProvider);
    final List<Item> removidos;
    try {
      removidos = await repo.limparConcluidos(idLista);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
      return;
    }
    if (!context.mounted || removidos.isEmpty) return;
    mostrarSnackBar(
      context,
      AppStrings.concluidosRemovidos,
      rotuloAcao: AppStrings.desfazer,
      onAcao: () {
        unawaited(() async {
          try {
            for (final item in removidos) {
              await repo.restaurarItem(item.id);
            }
          } catch (_) {
            if (context.mounted) {
              mostrarSnackBar(context, AppStrings.erroGenerico);
            }
          }
        }());
      },
    );
  }

  Future<void> _confirmarExcluirLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final titulo = ref.read(listaPorIdProvider(idLista)).value?.titulo ?? '';
    final nItens = ref.read(itensDaListaProvider(idLista)).value?.length ?? 0;
    final membros = ref.read(membrosDaListaProvider(idLista)).value;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirListaTitulo(titulo),
      mensagem: AppStrings.excluirListaMensagem(
        nItens,
        // Best-effort: se os membros ainda não foram carregados, assume só o
        // dono (não bloqueia a exclusão).
        temMembros: (membros?.length ?? 0) > 1,
      ),
    );
    if (!confirmou) return;
    await ref.read(listasRepositoryProvider).excluirLista(idLista);
    if (context.mounted) context.go('/listas');
  }

  /// Importação de lista (doc 05 §6.4, RF-16): entrada → pré-visualização
  /// → gravação local dos itens confirmados.
  Future<void> _importarLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final resposta = await abrirModalImportar(context, ref, idLista);
    if (resposta == null || !context.mounted) return;
    await confirmarItensImportados(context, ref, idLista, resposta);
  }

  @override
  Widget build(BuildContext context) {
    final listaId = widget.listaId;
    final listaAsync = ref.watch(listaPorIdProvider(listaId));
    return listaAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.lista),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.lista),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        // Erro com retry, no padrão dos demais estados (doc 15 §3, F14-T04).
        body: AppEstadoErro(
          mensagem: AppStrings.erroGenerico,
          onRetentar: () => ref.invalidate(listaPorIdProvider(listaId)),
        ),
      ),
      data: (lista) {
        if (lista == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.lista),
              leading: botaoVoltarInicio(context, '/listas'),
            ),
            body: Center(
              child: AppEstadoVazio(
                titulo: AppStrings.listaNaoEncontrada,
                acao: AppBotao(
                  rotulo: AppStrings.voltarParaListas,
                  variante: AppBotaoVariante.texto,
                  expandido: false,
                  onPressed: () => context.go('/listas'),
                ),
              ),
            ),
          );
        }
        final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
        final inicio = inicioDaLista(ehDono: ehDono);
        return PopScopeVoltarInicio(
          inicio: inicio,
          child: Scaffold(
            appBar: AppBar(
              leading: botaoVoltarInicio(context, inicio),
              title: Text(lista.titulo),
              actions: [
                if (_papelNaLista(lista.id) == Papel.dono ||
                    _papelNaLista(lista.id) == Papel.editor)
                  IconButton(
                    tooltip: AppStrings.modoMercado,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    onPressed: () => context.push('/mercado/${lista.id}'),
                  ),
                if (_buscando)
                  IconButton(
                    tooltip: AppStrings.limparBusca,
                    icon: const Icon(Icons.close),
                    onPressed: _fecharBusca,
                  )
                else
                  IconButton(
                    tooltip: AppStrings.buscar,
                    icon: const Icon(Icons.search),
                    onPressed: _abrirBusca,
                  ),
                PopupMenuButton<String>(
                  tooltip: AppStrings.menu,
                  onSelected: (acao) => _acaoMenu(context, ref, lista.id, acao),
                  itemBuilder: (context) {
                    // Papel (doc 08 §1, F7-T04): editor escreve itens, dono
                    // além disso exclui lista e convida; leitor só navega a
                    // membros. Papel reativo (F7-T03); loading/null = leitor.
                    final papel = _papelNaLista(lista.id);
                    final podeEscrever =
                        papel == Papel.dono || papel == Papel.editor;
                    final ehDono = papel == Papel.dono;
                    return [
                      if (podeEscrever)
                        const PopupMenuItem(
                          value: 'desmarcar',
                          child: Text(AppStrings.desmarcarTodos),
                        ),
                      if (podeEscrever)
                        const PopupMenuItem(
                          value: 'limpar',
                          child: Text(AppStrings.limparConcluidos),
                        ),
                      if (podeEscrever)
                        const PopupMenuItem(
                          value: 'renomear',
                          child: Text(AppStrings.renomearLista),
                        ),
                      // Membros (doc 08 §8) todos veem; navegação inclui
                      // "Sair da lista" para não-donos.
                      const PopupMenuItem(
                        value: 'membros',
                        child: Text(AppStrings.membros),
                      ),
                      if (ehDono)
                        const PopupMenuItem(
                          value: 'convidar',
                          child: Text(AppStrings.convidar),
                        ),
                      if (ehDono)
                        PopupMenuItem(
                          value: 'excluir',
                          child: Text(
                            AppStrings.excluirLista,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                const IndicadorSync(),
                if (_buscando)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: AppCampoTexto(
                      controller: _busca,
                      label: AppStrings.buscarItem,
                      hint: AppStrings.nomeDoItem,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                if (_papelNaLista(lista.id) == Papel.leitor)
                  const _BannerSomenteLeitura(),
                if (_papelNaLista(lista.id) != Papel.leitor)
                  _CampoAdicionar(
                    listaId: listaId,
                    onItemAdicionado: _buscando ? _fecharBusca : null,
                  ),
                Expanded(
                  child: _ListaItens(
                    listaId: listaId,
                    consulta: _busca.text,
                    onLimparBusca: _limparBusca,
                  ),
                ),
                TotalCarrinho(listaId: listaId),
                if (_papelNaLista(lista.id) != Papel.leitor)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      child: AppBotao(
                        rotulo: AppStrings.importarLista,
                        variante: AppBotaoVariante.outlined,
                        icone: Icons.playlist_add,
                        onPressed: () => _importarLista(context, ref, listaId),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerSomenteLeitura extends StatelessWidget {
  const _BannerSomenteLeitura();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AppBanner(
        tipo: AppBannerTipo.leitura,
        mensagem:
            '${AppStrings.somenteLeitura}: ${AppStrings.somenteLeituraDica}',
      ),
    );
  }
}

class _CampoAdicionar extends ConsumerStatefulWidget {
  const _CampoAdicionar({required this.listaId, this.onItemAdicionado});

  final String listaId;
  final VoidCallback? onItemAdicionado;

  @override
  ConsumerState<_CampoAdicionar> createState() => _CampoAdicionarState();
}

class _CampoAdicionarState extends ConsumerState<_CampoAdicionar> {
  final _controller = TextEditingController();

  /// Unidade usada quando o texto digitado não traz uma (F12-T06).
  Unidade _unidade = Unidade.un;

  /// Erro inline quando o parser descarta o texto digitado (F14-T07).
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    // Reconhece "1kg de banana" → Banana, 1 kg (F12-T06); sem unidade no
    // texto, aplica a unidade escolhida no seletor.
    final extra = interpretarItemAvulso(texto, unidadePadrao: _unidade);
    if (extra == null) {
      // Texto só com pontuação/separador: nada foi reconhecido (F14-T07).
      setState(() => _erro = AppStrings.naoEntendiItem);
      return;
    }
    await _adicionarItemDedup(
      nome: extra.nome,
      quantidade: extra.quantidade,
      unidade: extra.unidade,
    );
    _controller.clear();
    if (mounted) widget.onItemAdicionado?.call();
  }

  /// Núcleo de escrita compartilhado por `_adicionar` (entrada rápida) e
  /// `_adicionarSugerido` (chip, RF-19): delega a dedup ao repositório (RF-10).
  /// A sugestão de categoria continua aqui, na cadeia local (F6-T03).
  Future<void> _adicionarItemDedup({
    required String nome,
    required double quantidade,
    required Unidade unidade,
  }) async {
    final categoria = await ref
        .read(sugestaoCategoriasProvider)
        .sugerirCategoria(nome);
    final resultado = await ref
        .read(listasRepositoryProvider)
        .adicionarItemDedup(
          listaId: widget.listaId,
          nome: nome,
          quantidade: quantidade,
          unidade: unidade,
          categoria: categoria,
        );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoDedup.somado:
        mostrarSnackBar(context, '$nome ${AppStrings.itemDuplicadoSomado}');
      case ResultadoDedup.substituido:
        mostrarSnackBar(context, '$nome: ${AppStrings.itemAtualizado}');
      case ResultadoDedup.adicionado:
        break;
    }
  }

  /// Adiciona um item a partir do chip de sugestão (RF-19), reaproveitando
  /// a mesma deduplicação da entrada rápida (evita duplicar um nome já
  /// concluído na lista aberta, que também vira sugestão).
  Future<void> _adicionarSugerido(String nome) async {
    await _adicionarItemDedup(nome: nome, quantidade: 1, unidade: Unidade.un);
    _controller.clear();
    if (mounted) {
      setState(() {});
      widget.onItemAdicionado?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes =
        ref.watch(itensFrequentesProvider(widget.listaId)).value ??
        const <SugestaoItem>[];
    final mostrarChips =
        _controller.text.trim().isEmpty && sugestoes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mostrarChips)
            Semantics(
              label: AppStrings.sugestoes,
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sugestoes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final s = sugestoes[i];
                    return Semantics(
                      button: true,
                      label: AppStrings.adicionarSugerido(s.nome),
                      child: ActionChip(
                        label: Text(s.nome),
                        onPressed: () => _adicionarSugerido(s.nome),
                      ),
                    );
                  },
                ),
              ),
            ),
          AppCampoTexto(
            controller: _controller,
            label: AppStrings.adicionarItem,
            erro: _erro,
            onChanged: (_) => setState(() => _erro = null),
            onSubmitted: _adicionar,
            sufixo: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<Unidade>(
                  tooltip: AppStrings.unidade,
                  initialValue: _unidade,
                  onSelected: (u) => setState(() => _unidade = u),
                  itemBuilder: (context) => [
                    for (final u in Unidade.values)
                      PopupMenuItem(value: u, child: Text(u.valor)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_unidade.valor),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.adicionarItem,
                  icon: const Icon(Icons.add),
                  onPressed: _adicionar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaItens extends ConsumerWidget {
  const _ListaItens({
    required this.listaId,
    required this.consulta,
    this.onLimparBusca,
  });

  final String listaId;
  final String consulta;
  final VoidCallback? onLimparBusca;

  bool _casa(Item item) =>
      consulta.trim().isEmpty || contemBusca(item.nome, consulta);

  void _reordenarGrupo(
    WidgetRef ref,
    CategoriaItem categoria,
    List<Item> grupo,
    int oldIndex,
    int newIndex,
  ) {
    // Drag é restrito ao grupo (F6-T04, spec §6): reordena só os ids do
    // grupo; a exibição ordena por (categoria, ordem, id).
    final ordenados = [...grupo]
      ..removeAt(oldIndex)
      ..insert(newIndex, grupo[oldIndex]);
    ref.read(listasRepositoryProvider).reordenarItens(listaId, [
      for (final i in ordenados) i.id,
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papel = ref.watch(papelEfetivoProvider(listaId));
    final podeEscrever = papel != Papel.leitor;
    final itensAsync = ref.watch(itensDaListaProvider(listaId));
    return itensAsync.when(
      loading: () => const AppEsqueleto(linhas: 5),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(itensDaListaProvider(listaId)),
      ),
      data: (itens) {
        if (itens.isEmpty) {
          return AppEstadoVazio(
            icone: Icons.shopping_basket_outlined,
            titulo: podeEscrever
                ? AppStrings.nenhumItem
                : AppStrings.listaVazia,
            descricao: podeEscrever
                ? AppStrings.nenhumItemDica
                : AppStrings.listaVaziaDica,
          );
        }
        final pendentes = itens.where((i) => !i.concluido && _casa(i)).toList();
        final concluidos = itens.where((i) => i.concluido && _casa(i)).toList();
        final filtrando = consulta.trim().isNotEmpty;
        if (filtrando && pendentes.isEmpty && concluidos.isEmpty) {
          return AppEstadoVazio(
            icone: Icons.search_off,
            titulo: AppStrings.nenhumItemEncontrado,
            descricao: AppStrings.buscaSemResultadoDica,
            acao: AppBotao(
              rotulo: AppStrings.limparBusca,
              variante: AppBotaoVariante.texto,
              expandido: false,
              onPressed: onLimparBusca,
            ),
          );
        }
        final slivers = <Widget>[];
        // Grupos na ordem do enum (doc 01 §3.2); exibição = (categoria, ordem,
        // id) — o stream já chega ordenado por (ordem, id).
        for (final categoria in CategoriaItem.values) {
          final grupo = pendentes
              .where((i) => i.categoria == categoria)
              .toList();
          if (grupo.isEmpty) continue;
          slivers
            ..add(
              SliverToBoxAdapter(
                child: AppCabecalhoSecao(
                  categoria.rotulo,
                  contagem: grupo.length,
                ),
              ),
            )
            ..add(
              podeEscrever && !filtrando
                  ? SliverReorderableList(
                      itemCount: grupo.length,
                      onReorderItem: (oldIndex, newIndex) => _reordenarGrupo(
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
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _LinhaItem(
                          key: ValueKey(grupo[index].id),
                          listaId: listaId,
                          item: grupo[index],
                          index: -1,
                          podeEscrever: podeEscrever,
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
                  '${AppStrings.itensConcluidos} (${concluidos.length})',
                ),
                children: [
                  for (final item in concluidos)
                    _LinhaItem(
                      key: ValueKey(item.id),
                      listaId: listaId,
                      item: item,
                      index: -1,
                      podeEscrever: podeEscrever,
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
      },
    );
  }
}

class _LinhaItem extends ConsumerWidget {
  const _LinhaItem({
    super.key,
    required this.listaId,
    required this.item,
    required this.index,
    this.podeEscrever = true,
  });

  final String listaId;
  final Item item;

  /// Posição na seção reordenável; concluídos não participam (-1).
  final int index;

  /// Leitor (doc 08 §1, F7-T04): sem checkbox, sem swipe, sem alça.
  final bool podeEscrever;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linha = ListTile(
      // Tocar no item abre o editor (F12-T06) — o swipe continua disponível.
      onTap: podeEscrever ? () => _abrirDialogoEditar(context, ref) : null,
      leading: podeEscrever
          // O checkbox recebe o nome do item como rótulo (doc 15 §4): sem isso
          // o leitor de tela anuncia uma caixa de seleção sem contexto.
          ? MergeSemantics(
              child: Semantics(
                label: item.nome,
                child: Checkbox(
                  value: item.concluido,
                  onChanged: (_) => ref
                      .read(listasRepositoryProvider)
                      .editarItem(item.id, concluido: !item.concluido),
                ),
              ),
            )
          : const SizedBox(width: 40),
      title: Text(
        item.nome,
        style: item.concluido
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_formatarQuantidade(item.quantidade)} ${item.unidade.valor}'),
          if (podeEscrever && index >= 0)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.drag_handle,
                  size: 24,
                  semanticLabel: AppStrings.reordenar,
                ),
              ),
            ),
        ],
      ),
    );
    if (!podeEscrever) return linha;
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
          _abrirDialogoEditar(context, ref);
          return false;
        }
        await _removerComUndo(context, ref);
        return true;
      },
      child: linha,
    );
  }

  /// Remove o item e oferece Desfazer (usado pelo swipe e pelo diálogo).
  Future<void> _removerComUndo(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(listasRepositoryProvider);
    await repo.removerItem(item.id);
    if (!context.mounted) return;
    mostrarSnackBar(
      context,
      AppStrings.itemRemovido,
      rotuloAcao: AppStrings.desfazer,
      onAcao: () => repo.restaurarItem(item.id),
    );
  }

  String _formatarQuantidade(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  void _abrirDialogoEditar(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _DialogoEditarItem(
        item: item,
        listaId: listaId,
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

class _DialogoEditarItem extends ConsumerStatefulWidget {
  const _DialogoEditarItem({
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
  ConsumerState<_DialogoEditarItem> createState() => _DialogoEditarItemState();
}

class _DialogoEditarItemState extends ConsumerState<_DialogoEditarItem> {
  late final _nome = TextEditingController(text: widget.item.nome);
  late final _quantidade = TextEditingController(
    text: _formatarQuantidade(widget.item.quantidade),
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
    final bruto = _quantidade.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(bruto);
    if (valor == null || valor <= 0) return null;
    return valor;
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
      _erroNome = nome.isEmpty ? AppStrings.erroNomeVazio : null;
      _erroQuantidade = quantidade == null
          ? AppStrings.erroQuantidadeInvalida
          : null;
      _erroPreco = precoValido ? null : AppStrings.erroPrecoInvalido;
    });
    if (nome.isEmpty || quantidade == null || !precoValido) return;
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
    return AlertDialog(
      title: const Text(AppStrings.editarItem),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCampoTexto(
              controller: _nome,
              label: AppStrings.nomeDoItem,
              erro: _erroNome,
              onChanged: (_) {
                if (_erroNome != null) setState(() => _erroNome = null);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: AppStrings.diminuir,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    final atual = _quantidadeLida() ?? 1;
                    if (atual > 1) {
                      _quantidade.text = _formatarQuantidade(atual - 1);
                      if (_erroQuantidade != null) {
                        setState(() => _erroQuantidade = null);
                      }
                    }
                  },
                ),
                Expanded(
                  child: AppCampoTexto(
                    controller: _quantidade,
                    label: AppStrings.quantidade,
                    erro: _erroQuantidade,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      if (_erroQuantidade != null) {
                        setState(() => _erroQuantidade = null);
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.aumentar,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final atual = _quantidadeLida() ?? 1;
                    _quantidade.text = _formatarQuantidade(atual + 1);
                    if (_erroQuantidade != null) {
                      setState(() => _erroQuantidade = null);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<Unidade>(
              label: AppStrings.unidade,
              valor: _unidade,
              itens: [
                for (final u in Unidade.values)
                  DropdownMenuItem(value: u, child: Text(u.valor)),
              ],
              onChanged: (u) {
                if (u != null) setState(() => _unidade = u);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // Categoria (F6-T04, spec §6): mudar de grupo via edição.
            AppDropdown<CategoriaItem>(
              label: AppStrings.categoria,
              valor: _categoria,
              itens: [
                for (final c in CategoriaItem.values)
                  DropdownMenuItem(value: c, child: Text(c.rotulo)),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _categoria = c);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // Preço unitário opcional (RF-21, F25): vazio = sem preço.
            AppCampoTexto(
              controller: _preco,
              label: AppStrings.preco,
              erro: _erroPreco,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_erroPreco != null) setState(() => _erroPreco = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onRemover != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(widget.onRemover!());
            },
            child: Text(
              AppStrings.removerItem,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: AppStrings.salvar,
          expandido: false,
          onPressed: _salvar,
        ),
      ],
    );
  }

  String _formatarQuantidade(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
