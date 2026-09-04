import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/tempo_relativo.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/lista_com_contagem.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';

/// Painel "Minhas Listas" (doc 05 Â§6.2, wireframe 10 Â§2, RF-02).
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
            tooltip: AppStrings.configuracoes,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/configuracoes'),
          ),
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
  return abrirSheetTitulo(
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
  return abrirSheetTitulo(
    context,
    titulo: titulo,
    rotuloBotao: rotuloBotao,
    valorInicial: valorInicial,
    onSalvar: onSalvar,
  );
}
