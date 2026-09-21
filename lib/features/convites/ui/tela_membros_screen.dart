import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/navigation/voltar_para_inicio.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/convite.dart';
import '../domain/papel.dart';
import '../providers/convites_providers.dart';
import '../providers/papel_providers.dart';
import 'acao_sair_da_lista.dart';

/// Membros da lista (doc 08 §5/§8, F7-T03, RF-13): FutureProvider.family por
/// listaId via `membrosDaLista`; dono troca papel (editor↔leitor), remove
/// membro e transfere o dono (RF-14, F24); não-dono sai da lista e, após
/// transferir, o ex-dono vira `editor` e passa a poder sair (doc 08 §6).
/// **Correção:** o dono é mesclado a partir da lista local (`donoId`) quando o
/// servidor não devolve a linha — a tela nunca fica
/// vazia para listas próprias (offline ou associação pendente).
final membrosDaListaProvider = FutureProvider.family<List<MembroLista>, String>(
  (ref, listaId) async {
    final membros = await ref
        .watch(convitesRepositoryProvider)
        .membrosDaLista(listaId);
    final donoId = ref.watch(listaPorIdProvider(listaId)).value?.donoId;
    if (donoId != null &&
        donoId.isNotEmpty &&
        !membros.any((m) => m.papel == Papel.dono)) {
      return [MembroLista(userId: donoId, papel: Papel.dono), ...membros];
    }
    return membros;
  },
);

class TelaMembrosScreen extends ConsumerStatefulWidget {
  const TelaMembrosScreen({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<TelaMembrosScreen> createState() => _TelaMembrosScreenState();
}

class _TelaMembrosScreenState extends ConsumerState<TelaMembrosScreen> {
  String get listaId => widget.listaId;

  @override
  void initState() {
    super.initState();
    // Refetch ao abrir: evita servir um `[]` cacheado de quando a lista ainda
    // não havia sincronizado a associação de membros.
    Future.microtask(() => ref.invalidate(membrosDaListaProvider(listaId)));
  }

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
      case 'transferir':
        _confirmarTransferencia(context, ref, membro);
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
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.papelAtualizado);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
  }

  Future<void> _confirmarRemover(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
  ) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.removerMembro,
      mensagem: AppStrings.removerMembroMensagem,
      confirmar: AppStrings.removerMembro,
    );
    if (!confirmou) return;
    final repo = ref.read(convitesRepositoryProvider);
    try {
      await repo.removerMembro(listaId: listaId, userId: membro.userId);
      ref.invalidate(membrosDaListaProvider(listaId));
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.membroRemovido);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
  }

  Future<void> _confirmarTransferencia(
    BuildContext context,
    WidgetRef ref,
    MembroLista membro,
  ) async {
    // Confirmação dupla (doc 08 §6): explica a perda de poderes e confirma.
    final passo1 = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.transferirDonoTitulo,
      mensagem: AppStrings.transferirDonoMensagem,
      confirmar: AppStrings.continuar,
    );
    if (!passo1 || !context.mounted) return;
    final passo2 = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.transferirDonoTitulo,
      mensagem: AppStrings.transferirDonoMensagemFinal,
      confirmar: AppStrings.transferirDono,
    );
    if (!passo2 || !context.mounted) return;

    try {
      await ref
          .read(convitesRepositoryProvider)
          .transferirDono(listaId: listaId, novoDonoId: membro.userId);
      ref.read(papelRepositoryProvider).atualizar(listaId, Papel.editor);
      ref.invalidate(membrosDaListaProvider(listaId));
      if (context.mounted) mostrarSnackBar(context, AppStrings.donoTransferido);
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }

  String _rotuloPapel(Papel papel) => switch (papel) {
    Papel.dono => AppStrings.papelDono,
    Papel.editor => AppStrings.convidarPapelEditor,
    Papel.leitor => AppStrings.convidarPapelLeitor,
  };

  @override
  Widget build(BuildContext context) {
    final usuarioId = ref.watch(donoAtualIdProvider);
    final membrosAsync = ref.watch(membrosDaListaProvider(listaId));
    final lista = ref.watch(listaPorIdProvider(listaId)).value;
    final inicio = inicioDaLista(ehDono: lista?.donoId == usuarioId);
    final titulo = lista == null
        ? AppStrings.membros
        : '${AppStrings.membros} · ${lista.titulo}';
    return PopScopeVoltarInicio(
      inicio: inicio,
      child: Scaffold(
        appBar: AppBar(
          leading: botaoVoltarInicio(context, inicio),
          title: Text(titulo),
          actions: [
            // O gate só decide com dados carregados: enquanto isLoading (ou
            // papel desconhecido, ex.: erro), não renderiza "Sair da lista".
            if (membrosAsync.hasValue && !_eDono(membrosAsync, usuarioId))
              TextButton(
                onPressed: () => confirmarSairDaLista(context, ref, listaId),
                child: const Text(AppStrings.sairDaLista),
              ),
          ],
        ),
        body: membrosAsync.when(
          loading: () => const AppEsqueleto(linhas: 4),
          error: (_, _) => AppEstadoErro(
            mensagem: AppStrings.erroGenerico,
            onRetentar: () => ref.invalidate(membrosDaListaProvider(listaId)),
          ),
          data: (membros) {
            if (membros.isEmpty) {
              // Só acontece sem cache local (membrosDaListaProvider sempre
              // mescla o dono): instrução sem ações, pois o papel não é
              // confiável aqui (doc 08 §8, F14-T04).
              return Center(
                child: AppEstadoVazio(
                  titulo: AppStrings.nenhumParticipante,
                  descricao: AppStrings.nenhumParticipanteDica,
                ),
              );
            }
            return ListView.builder(
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
                      AppChip(rotulo: _rotuloPapel(membro.papel)),
                      if (_eDono(membrosAsync, usuarioId) && !souEu)
                        PopupMenuButton<String>(
                          tooltip: AppStrings.menu,
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
                            if (_eDono(membrosAsync, usuarioId) && !souEu)
                              PopupMenuItem(
                                value: 'transferir',
                                child: Text(AppStrings.transferirDono),
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
