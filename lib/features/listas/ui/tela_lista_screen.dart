import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/item.dart';
import '../domain/unidade.dart';
import '../providers/listas_providers.dart';

/// Tela da Lista de Compras (doc 05 §6.3, wireframe 10 §3.1, RF-03/RF-04).
/// Menu (⋮), indicador de sync, IA e drag-and-drop chegam em F3-T08/F4.
class TelaListaScreen extends ConsumerWidget {
  const TelaListaScreen({super.key, required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          appBar: AppBar(title: Text(lista.titulo)),
          body: Column(
            children: [
              _CampoAdicionar(listaId: listaId),
              Expanded(child: _ListaItens(listaId: listaId)),
            ],
          ),
        );
      },
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('$nome ${AppStrings.itemDuplicadoSomado}')),
          );
      }
    } else {
      await repo.adicionarItem(listaId: widget.listaId, nome: nome);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _controller,
        onSubmitted: (_) => _adicionar(),
        decoration: InputDecoration(
          labelText: AppStrings.adicionarItem,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: AppStrings.adicionarItem,
            icon: const Icon(Icons.add),
            onPressed: _adicionar,
          ),
        ),
      ),
    );
  }
}

class _ListaItens extends ConsumerWidget {
  const _ListaItens({required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itensAsync = ref.watch(itensDaListaProvider(listaId));
    return itensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text(AppStrings.erroGenerico)),
      data: (itens) {
        final pendentes = itens.where((i) => !i.concluido).toList();
        final concluidos = itens.where((i) => i.concluido).toList();
        if (itens.isEmpty) {
          return Center(child: Text(AppStrings.adicionarItem));
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _CabecalhoSecao('${AppStrings.itens} (${pendentes.length})'),
            for (final item in pendentes)
              _LinhaItem(listaId: listaId, item: item),
            if (concluidos.isNotEmpty)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  '${AppStrings.itensConcluidos} (${concluidos.length})',
                ),
                children: [
                  for (final item in concluidos)
                    _LinhaItem(listaId: listaId, item: item),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _CabecalhoSecao extends StatelessWidget {
  const _CabecalhoSecao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LinhaItem extends ConsumerWidget {
  const _LinhaItem({required this.listaId, required this.item});

  final String listaId;
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(item.id),
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
        await ref.read(listasRepositoryProvider).removerItem(item.id);
        if (!context.mounted) return true;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(AppStrings.itemRemovido),
              action: SnackBarAction(
                label: AppStrings.desfazer,
                onPressed: () =>
                    ref.read(listasRepositoryProvider).restaurarItem(item.id),
              ),
            ),
          );
        return true;
      },
      child: ListTile(
        leading: Checkbox(
          value: item.concluido,
          onChanged: (_) => ref
              .read(listasRepositoryProvider)
              .editarItem(item.id, concluido: !item.concluido),
        ),
        title: Text(
          item.nome,
          style: item.concluido
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        trailing: Text(
          '${_formatarQuantidade(item.quantidade)} ${item.unidade.valor}',
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
            TextField(
              controller: _nome,
              decoration: InputDecoration(
                labelText: AppStrings.adicionarItem,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Diminuir',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    final atual = _quantidadeLida() ?? 1;
                    if (atual > 1) {
                      _quantidade.text = _formatarQuantidade(atual - 1);
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _quantidade,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: AppStrings.quantidade,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final atual = _quantidadeLida() ?? 1;
                    _quantidade.text = _formatarQuantidade(atual + 1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        FilledButton(onPressed: _salvar, child: const Text(AppStrings.salvar)),
      ],
    );
  }

  String _formatarQuantidade(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
