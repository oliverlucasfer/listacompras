import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/utils/tempo_relativo.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../../convites/domain/convite.dart';
import '../../convites/domain/papel.dart';
import '../../convites/providers/convites_providers.dart';
import '../../convites/providers/papel_providers.dart';
import '../domain/lista_com_contagem.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';

/// Filtro do painel de listas (doc 05 §6.2, F10): as listas em que o usuário
/// é dono vs. aquelas em que participa como membro.
enum FiltroListas { minhas, compartilhadas }

/// Painel de listas reutilizável (Minhas × Compartilhadas).
class PainelListas extends ConsumerWidget {
  const PainelListas({super.key, required this.filtro});

  final FiltroListas filtro;

  bool get _compartilhadas => filtro == FiltroListas.compartilhadas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(donoAtualIdProvider);
    final listasAsync = ref
        .watch(listasComContagemProvider)
        .whenData(
          (todas) => todas
              .where(
                (c) => _compartilhadas
                    ? c.lista.donoId != usuario
                    : c.lista.donoId == usuario,
              )
              .toList(),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _compartilhadas ? AppStrings.compartilhadas : AppStrings.minhasListas,
        ),
        actions: [
          if (_compartilhadas)
            IconButton(
              tooltip: AppStrings.conviteComCodigo,
              icon: const Icon(Icons.person_add),
              onPressed: () => abrirDialogoEntrarComCodigo(context, ref),
            ),
        ],
      ),
      body: listasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppEstadoErro(
          mensagem: AppStrings.erroGenerico,
          onRetentar: () => ref.invalidate(listasComContagemProvider),
        ),
        data: (listas) => listas.isEmpty
            ? _vazio(context, ref)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  88,
                ),
                itemCount: listas.length,
                itemBuilder: (context, i) => _CardLista(contagem: listas[i]),
              ),
      ),
      floatingActionButton: _compartilhadas
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-nova-lista',
              onPressed: () => abrirSheetNovaLista(context, ref),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.novaLista),
            ),
    );
  }

  Widget _vazio(BuildContext context, WidgetRef ref) {
    if (_compartilhadas) {
      return AppEstadoVazio(
        icone: Icons.group_outlined,
        titulo: AppStrings.nenhumaCompartilhada,
        descricao: AppStrings.nenhumaCompartilhadaDica,
        acao: AppBotao(
          rotulo: AppStrings.conviteComCodigo,
          icone: Icons.person_add,
          expandido: false,
          onPressed: () => abrirDialogoEntrarComCodigo(context, ref),
        ),
      );
    }
    return AppEstadoVazio(
      icone: Icons.sticky_note_2_outlined,
      titulo: AppStrings.nenhumaLista,
      descricao: AppStrings.criePrimeiraLista,
      acao: AppBotao(
        rotulo: AppStrings.criarPrimeiraLista,
        icone: Icons.add,
        expandido: false,
        onPressed: () => abrirSheetNovaLista(context, ref),
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
    final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.go('/lista/${lista.id}'),
        onLongPress: ehDono
            ? () => _abrirAcoes(context, ref, contagem)
            : () => context.push('/membros/${lista.id}'),
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
    AppSheet.mostrar<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text(AppStrings.renomear),
            onTap: () {
              Navigator.pop(context);
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
              Navigator.pop(context);
              _confirmarExclusao(context, ref, contagem);
            },
          ),
        ],
      ),
    );
  }

  void _abrirSheetRenomear(
    BuildContext context,
    WidgetRef ref,
    ListaComContagem contagem,
  ) {
    abrirSheetTitulo(
      context,
      titulo: AppStrings.renomearLista,
      rotuloBotao: AppStrings.salvar,
      valorInicial: contagem.lista.titulo,
      onSalvar: (nome) => ref
          .read(listasRepositoryProvider)
          .renomearLista(id: contagem.lista.id, titulo: nome),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    ListaComContagem contagem,
  ) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirLista,
      mensagem: AppStrings.excluirListaMensagem,
    );
    if (confirmou) {
      await ref.read(listasRepositoryProvider).excluirLista(contagem.lista.id);
    }
  }
}

/// Diálogo "Entrar com código" (doc 08 §1.1, RF-13): colar token cru →
/// aceita o convite e navega para a lista; erro vira SnackBar amigável.
void abrirDialogoEntrarComCodigo(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => const _DialogoEntrarComCodigo(),
  ).then((_) {
    ref.invalidate(listasComContagemProvider);
  });
}

class _DialogoEntrarComCodigo extends ConsumerStatefulWidget {
  const _DialogoEntrarComCodigo();

  @override
  ConsumerState<_DialogoEntrarComCodigo> createState() =>
      _DialogoEntrarComCodigoState();
}

class _DialogoEntrarComCodigoState
    extends ConsumerState<_DialogoEntrarComCodigo> {
  final _token = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _entrar(BuildContext dialogContext) async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      mostrarSnackBar(dialogContext, AppStrings.conviteInvalido);
      return;
    }
    setState(() => _carregando = true);
    try {
      final listaId = await ref.read(convitesRepositoryProvider).aceitar(token);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) context.go('/lista/$listaId');
    } on ErroConvite catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        mostrarSnackBar(context, e.message);
      }
    } catch (_) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        mostrarSnackBar(context, AppStrings.conviteInesperado);
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.conviteComCodigo),
      content: AppCampoTexto(
        controller: _token,
        label: AppStrings.conviteCampoCodigo,
        onSubmitted: () => _entrar(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: AppStrings.conviteConvidadoEntrar,
          carregando: _carregando,
          expandido: false,
          onPressed: () => _entrar(context),
        ),
      ],
    );
  }
}

Future<void> abrirSheetNovaLista(BuildContext context, WidgetRef ref) {
  return abrirSheetTitulo(
    context,
    titulo: AppStrings.novaLista,
    rotuloBotao: AppStrings.criarLista,
    onSalvar: (nome) async {
      final lista = await ref
          .read(listasRepositoryProvider)
          .criarLista(titulo: nome, donoId: ref.read(donoAtualIdProvider));
      // Papel local imediato (funciona offline): o criador é dono. O servidor
      // confirma a associação em `lista_membros` na migration 0010.
      ref.read(papelRepositoryProvider).atualizar(lista.id, Papel.dono);
    },
  );
}
