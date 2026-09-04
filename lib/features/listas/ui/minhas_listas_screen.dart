import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/tempo_relativo.dart';
import '../../../core/widgets/erro_inline.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/lista_com_contagem.dart';
import '../providers/listas_providers.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, wireframe 10 §2, RF-02).
class MinhasListasScreen extends ConsumerWidget {
  const MinhasListasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listasAsync = ref.watch(listasComContagemProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.minhasListas),
        actions: [
          IconButton(
            tooltip: AppStrings.sair,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).sair();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: listasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(AppStrings.erroGenerico),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(listasComContagemProvider),
                child: const Text(AppStrings.tentarNovamente),
              ),
            ],
          ),
        ),
        data: (listas) => listas.isEmpty
            ? const _EstadoVazio()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: listas.length,
                itemBuilder: (context, i) => _CardLista(contagem: listas[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-nova-lista',
        onPressed: () => _abrirSheetNovaLista(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.novaLista),
      ),
    );
  }
}

class _EstadoVazio extends ConsumerWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.nenhumaLista,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.criePrimeiraLista,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _abrirSheetNovaLista(context, ref),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.criarPrimeiraLista),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardLista extends ConsumerWidget {
  const _CardLista({required this.contagem});

  final ListaComContagem contagem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = contagem.lista;
    return Card(
      child: ListTile(
        onTap: () => context.go('/lista/${lista.id}'),
        onLongPress: () => _abrirAcoes(context, ref, contagem),
        title: Text(
          lista.titulo,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contagem.contagem),
              Text(
                '${AppStrings.atualizada} ${tempoRelativo(lista.atualizadoEm, agora: DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirAcoes(
    BuildContext context,
    WidgetRef ref,
    ListaComContagem contagem,
  ) {
    final esquema = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.renomear),
              onTap: () {
                Navigator.pop(sheetContext);
                _abrirSheetRenomear(context, ref, contagem);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: esquema.error),
              title: Text(
                AppStrings.excluir,
                style: TextStyle(color: esquema.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmarExclusao(context, ref, contagem);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSheetRenomear(
    BuildContext context,
    WidgetRef ref,
    ListaComContagem contagem,
  ) {
    _abrirSheetTitulo(
      context,
      titulo: AppStrings.renomearLista,
      rotuloBotao: AppStrings.salvar,
      valorInicial: contagem.lista.titulo,
      onSalvar: (nome) => ref
          .read(listasRepositoryProvider)
          .renomearLista(id: contagem.lista.id, titulo: nome),
    );
  }

  void _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    ListaComContagem contagem,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.excluirLista),
        content: const Text(AppStrings.excluirListaMensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancelar),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(listasRepositoryProvider)
                  .excluirLista(contagem.lista.id);
            },
            child: const Text(AppStrings.excluir),
          ),
        ],
      ),
    );
  }
}

Future<void> _abrirSheetNovaLista(BuildContext context, WidgetRef ref) {
  return _abrirSheetTitulo(
    context,
    titulo: AppStrings.novaLista,
    rotuloBotao: AppStrings.criarLista,
    onSalvar: (nome) => ref
        .read(listasRepositoryProvider)
        .criarLista(titulo: nome, donoId: ref.read(donoAtualIdProvider)),
  );
}

Future<void> _abrirSheetTitulo(
  BuildContext context, {
  required String titulo,
  required String rotuloBotao,
  required Future<void> Function(String nome) onSalvar,
  String? valorInicial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _SheetTituloLista(
      titulo: titulo,
      rotuloBotao: rotuloBotao,
      valorInicial: valorInicial,
      onSalvar: onSalvar,
    ),
  );
}

class _SheetTituloLista extends StatefulWidget {
  const _SheetTituloLista({
    required this.titulo,
    required this.rotuloBotao,
    required this.onSalvar,
    this.valorInicial,
  });

  final String titulo;
  final String rotuloBotao;
  final Future<void> Function(String nome) onSalvar;
  final String? valorInicial;

  @override
  State<_SheetTituloLista> createState() => _SheetTituloListaState();
}

class _SheetTituloListaState extends State<_SheetTituloLista> {
  late final _controller = TextEditingController(text: widget.valorInicial);
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = AppStrings.erroNomeVazio);
      return;
    }
    setState(() {
      _erro = null;
      _salvando = true;
    });
    try {
      await widget.onSalvar(nome);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = AppStrings.erroGenerico;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.cancelar,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _salvar(),
              decoration: InputDecoration(
                labelText: AppStrings.nomeDaLista,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_erro != null) ErroInline(mensagem: _erro!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.rotuloBotao),
            ),
          ],
        ),
      ),
    );
  }
}
