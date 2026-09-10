import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/convite.dart';
import '../domain/papel.dart';
import '../providers/convites_providers.dart';
import '../providers/papel_providers.dart';

/// Membros da lista (doc 08 §5/§8, F7-T03, RF-13): FutureProvider.family por
/// listaId via `membrosDaLista`; dono troca papel (editor↔leitor) e remove
/// membro; não-dono sai da lista (doc 08 §5 — transferência de dono adiada,
/// então o dono não sai).
final membrosDaListaProvider = FutureProvider.family<List<MembroLista>, String>(
  (ref, listaId) =>
      ref.watch(convitesRepositoryProvider).membrosDaLista(listaId),
);

class TelaMembrosScreen extends ConsumerWidget {
  const TelaMembrosScreen({super.key, required this.listaId});

  final String listaId;

  void _acaoMenu(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
    String acao,
  ) {
    switch (acao) {
      case 'editor':
        _mudarPapel(context, ref, membro, Papel.editor);
      case 'leitor':
        _mudarPapel(context, ref, membro, Papel.leitor);
      case 'remover':
        _confirmarRemover(context, ref, membro);
    }
  }

  Future<void> _mudarPapel(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
    Papel papel,
  ) async {
    final repo = ref.read(convitesRepositoryProvider);
    try {
      await repo.mudarPapel(
        listaId: listaId,
        userId: membro.userId,
        papel: papel,
      );
      ref.invalidate(membrosDaListaProvider(listaId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(AppStrings.erroGenerico)));
      }
    }
  }

  void _confirmarRemover(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.removerMembro),
        content: const Text(AppStrings.removerMembroMensagem),
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
              final repo = ref.read(convitesRepositoryProvider);
              try {
                await repo.removerMembro(
                  listaId: listaId,
                  userId: membro.userId,
                );
                ref.invalidate(membrosDaListaProvider(listaId));
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(AppStrings.erroGenerico)),
                    );
                }
              }
            },
            child: const Text(AppStrings.removerMembro),
          ),
        ],
      ),
    );
  }

  void _confirmarSair(BuildContext context, WidgetRef ref) {
    final repoConvites = ref.read(convitesRepositoryProvider);
    final repoPapeis = ref.read(papelRepositoryProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.sairListaTitulo),
        content: const Text(AppStrings.sairListaMensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancelar),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await repoConvites.sairDaLista(listaId);
                repoPapeis.remover(listaId);
                if (context.mounted) context.go('/listas');
              } on ErroConvite catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(AppStrings.erroGenerico)),
                    );
                }
              }
            },
            child: const Text(AppStrings.sairDaLista),
          ),
        ],
      ),
    );
  }

  String _rotuloPapel(Papel papel) => switch (papel) {
    Papel.dono => AppStrings.papelDono,
    Papel.editor => AppStrings.convidarPapelEditor,
    Papel.leitor => AppStrings.convidarPapelLeitor,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioId = ref.watch(donoAtualIdProvider);
    final membrosAsync = ref.watch(membrosDaListaProvider(listaId));
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.membros),
        actions: [
          if (!_eDono(membrosAsync, usuarioId))
            TextButton(
              onPressed: () => _confirmarSair(context, ref),
              child: const Text(AppStrings.sairDaLista),
            ),
        ],
      ),
      body: membrosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(AppStrings.erroGenerico),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(membrosDaListaProvider(listaId)),
                child: const Text(AppStrings.tentarNovamente),
              ),
            ],
          ),
        ),
        data: (membros) => ListView.builder(
          itemCount: membros.length,
          itemBuilder: (context, i) {
            final membro = membros[i];
            final souEu = membro.userId == usuarioId;
            return ListTile(
              leading: Icon(
                souEu ? Icons.person : Icons.person_outline,
                color: souEu ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                souEu ? AppStrings.voce : _identificador(membro),
                style: souEu
                    ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )
                    : null,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      _rotuloPapel(membro.papel),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_eDono(membrosAsync, usuarioId) && !souEu)
                    PopupMenuButton<String>(
                      onSelected: (acao) =>
                          _acaoMenu(context, ref, membro, acao),
                      itemBuilder: (context) => [
                        CheckedPopupMenuItem<String>(
                          value: 'editor',
                          checked: membro.papel == Papel.editor,
                          child: const Text(AppStrings.convidarPapelEditor),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'leitor',
                          checked: membro.papel == Papel.leitor,
                          child: const Text(AppStrings.convidarPapelLeitor),
                        ),
                        PopupMenuItem(
                          value: 'remover',
                          child: Text(
                            AppStrings.removerMembro,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Papel próprio derivado da própria lista de membros (sem canal extra);
  /// usuário ausente = desconhecido → não-dono.
  bool _eDono(AsyncValue<List<MembroLista>> membrosAsync, String usuarioId) {
    final membros = membrosAsync.value;
    if (membros == null) return false;
    return membros.any((m) => m.userId == usuarioId && m.papel == Papel.dono);
  }

  String _identificador(MembroLista membro) => membro.userId.length <= 8
      ? membro.userId
      : '${membro.userId.substring(0, 8)}…';
}
