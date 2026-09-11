import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../convites/data/papel_repository.dart';
import '../../convites/domain/papel.dart';
import '../../convites/providers/papel_providers.dart';
import '../../convites/ui/sheet_convidar.dart';
import '../../ia/ui/modal_importar_ia.dart';
import '../../ia/ui/modal_previsao_ia.dart';
import '../../sync/ui/indicador_sync.dart';
import '../domain/categoria.dart';
import '../domain/item.dart';
import '../domain/unidade.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';

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

  /// Papel do usuário na lista (F7-T03): stream do PapelRepository reativo;
  /// enquanto o primeiro evento não chega, lê o estado atual do repositório
  /// (o menu pode abrir antes do microtask do stream).
  Papel _papelNaLista(String listaId) {
    final viaStream = ref.watch(papelNaListaStreamProvider(listaId)).value;
    if (viaStream != null) return viaStream;
    return ref.watch(papelRepositoryProvider).papelDe(listaId) ?? Papel.leitor;
  }

  /// Feedback "membro entrou" (doc 08 §7, F7-T07): realtime INSERT de
  /// outro membro sinaliza o notifier — só a tela aberta da mesma lista
  /// mostra o SnackBar (sem nome, o RLS não expõe outros perfis).
  void _aoMembroEntrar() {
    final listaId = _membroEntrou?.value;
    if (listaId == null || listaId != widget.listaId || !mounted) return;
    _papelRepo?.consumirEntrada();
    mostrarSnackBar(context, AppStrings.membroEntrou);
  }

  @override
  void initState() {
    super.initState();
    _papelRepo = ref.read(papelRepositoryProvider);
    _membroEntrou = _papelRepo?.membroEntrou;
    _membroEntrou?.addListener(_aoMembroEntrar);
  }

  @override
  void dispose() {
    _membroEntrou?.removeListener(_aoMembroEntrar);
    super.dispose();
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
    if (confirmou) {
      ref.read(listasRepositoryProvider).limparConcluidos(idLista);
    }
  }

  Future<void> _confirmarExcluirLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final titulo = ref.read(listaPorIdProvider(idLista)).value?.titulo ?? '';
    final nItens = ref.read(itensDaListaProvider(idLista)).value?.length ?? 0;
    final mensagem = nItens == 1
        ? 'O item será removido.'
        : 'Os $nItens itens serão removidos.';
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: 'Excluir "$titulo"?',
      mensagem: mensagem,
    );
    if (!confirmou) return;
    await ref.read(listasRepositoryProvider).excluirLista(idLista);
    if (context.mounted) context.go('/listas');
  }

  /// Importação por IA (doc 05 §6.3/§6.4, RF-06): entrada → pré-visualização
  /// → gravação local dos itens confirmados.
  Future<void> _importarPorIa(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final resposta = await abrirModalImportarIa(context, ref, idLista);
    if (resposta == null || !context.mounted) return;
    await confirmarItensImportados(context, ref, idLista, resposta);
  }

  @override
  Widget build(BuildContext context) {
    final listaId = widget.listaId;
    final listaAsync = ref.watch(listaPorIdProvider(listaId));
    return listaAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(AppStrings.erroGenerico)),
      ),
      data: (lista) {
        if (lista == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text(AppStrings.listaNaoEncontrada)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(lista.titulo),
            actions: [
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
              if (_papelNaLista(lista.id) == Papel.leitor)
                const _BannerSomenteLeitura(),
              if (_papelNaLista(lista.id) != Papel.leitor)
                _CampoAdicionar(listaId: listaId),
              Expanded(child: _ListaItens(listaId: listaId)),
              if (_papelNaLista(lista.id) != Papel.leitor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: AppBotao(
                    rotulo: AppStrings.importarPorIa,
                    variante: AppBotaoVariante.outlined,
                    icone: Icons.smart_toy_outlined,
                    onPressed: () => _importarPorIa(context, ref, listaId),
                  ),
                ),
            ],
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
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.somenteLeitura,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Text(AppStrings.somenteLeituraDica),
        ],
      ),
    );
  }
}

class _CampoAdicionar extends ConsumerStatefulWidget {
  const _CampoAdicionar({required this.listaId});

  final String listaId;

  @override
  ConsumerState<_CampoAdicionar> createState() => _CampoAdicionarState();
}

class _CampoAdicionarState extends ConsumerState<_CampoAdicionar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) return;
    final repo = ref.read(listasRepositoryProvider);
    final itens =
        ref.read(itensDaListaProvider(widget.listaId)).value ?? const <Item>[];
    Item? existente;
    for (final i in itens) {
      if (i.nome.toLowerCase() == nome.toLowerCase()) {
        existente = i;
        break;
      }
    }
    if (existente != null) {
      // Duplicado: aumenta a quantidade em vez de bloquear (doc 05 §6.3).
      await repo.editarItem(existente.id, quantidade: existente.quantidade + 1);
      if (mounted) {
        mostrarSnackBar(context, '$nome ${AppStrings.itemDuplicadoSomado}');
      }
    } else {
      // Sugestão local em camadas (F6-T03, spec §4): memória → dicionário
      // → outros; zero rede.
      final categoria = await ref
          .read(sugestaoCategoriasProvider)
          .sugerirCategoria(nome);
      await repo.adicionarItem(
        listaId: widget.listaId,
        nome: nome,
        categoria: categoria,
      );
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: AppCampoTexto(
        controller: _controller,
        label: AppStrings.adicionarItem,
        onSubmitted: _adicionar,
        sufixo: IconButton(
          tooltip: AppStrings.adicionarItem,
          icon: const Icon(Icons.add),
          onPressed: _adicionar,
        ),
      ),
    );
  }
}

class _ListaItens extends ConsumerWidget {
  const _ListaItens({required this.listaId});

  final String listaId;

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
    final papel =
        ref.watch(papelNaListaStreamProvider(listaId)).value ??
        (ref.watch(papelRepositoryProvider).papelDe(listaId) ?? Papel.leitor);
    final podeEscrever = papel != Papel.leitor;
    final itensAsync = ref.watch(itensDaListaProvider(listaId));
    return itensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
        final pendentes = itens.where((i) => !i.concluido).toList();
        final concluidos = itens.where((i) => i.concluido).toList();
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
              podeEscrever
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
                          podeEscrever: false,
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
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
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
        slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 24)));
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
      leading: podeEscrever
          ? Checkbox(
              value: item.concluido,
              onChanged: (_) => ref
                  .read(listasRepositoryProvider)
                  .editarItem(item.id, concluido: !item.concluido),
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
                padding: const EdgeInsets.all(12),
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
    // Capturado antes de qualquer remoção: o undo do SnackBar pode rodar
    // após este widget desmontar (Riverpod proíbe ref pós-unmount).
    final repo = ref.read(listasRepositoryProvider);
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
        await repo.removerItem(item.id);
        if (!context.mounted) return true;
        mostrarSnackBar(
          context,
          AppStrings.itemRemovido,
          rotuloAcao: AppStrings.desfazer,
          onAcao: () => repo.restaurarItem(item.id),
        );
        return true;
      },
      child: linha,
    );
  }

  String _formatarQuantidade(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  void _abrirDialogoEditar(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _DialogoEditarItem(item: item, listaId: listaId),
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
  const _DialogoEditarItem({required this.item, required this.listaId});

  final Item item;
  final String listaId;

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

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  double? _quantidadeLida() {
    final bruto = _quantidade.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(bruto);
    if (valor == null || valor <= 0) return null;
    return valor;
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final quantidade = _quantidadeLida();
    if (nome.isEmpty || quantidade == null) return;
    await ref
        .read(listasRepositoryProvider)
        .editarItem(
          widget.item.id,
          nome: nome,
          quantidade: quantidade,
          unidade: _unidade,
          categoria: _categoria,
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
            AppCampoTexto(controller: _nome, label: AppStrings.adicionarItem),
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
                    }
                  },
                ),
                Expanded(
                  child: AppCampoTexto(
                    controller: _quantidade,
                    label: AppStrings.quantidade,
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.aumentar,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final atual = _quantidadeLida() ?? 1;
                    _quantidade.text = _formatarQuantidade(atual + 1);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<Unidade>(
              initialValue: _unidade,
              decoration: InputDecoration(
                labelText: AppStrings.unidade,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final u in Unidade.values)
                  DropdownMenuItem(value: u, child: Text(u.valor)),
              ],
              onChanged: (u) {
                if (u != null) setState(() => _unidade = u);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // Categoria (F6-T04, spec §6): mudar de grupo via edição.
            DropdownButtonFormField<CategoriaItem>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: AppStrings.categoria,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in CategoriaItem.values)
                  DropdownMenuItem(value: c, child: Text(c.rotulo)),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _categoria = c);
              },
            ),
          ],
        ),
      ),
      actions: [
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
