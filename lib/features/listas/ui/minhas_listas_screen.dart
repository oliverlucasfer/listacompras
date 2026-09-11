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
import '../../convites/providers/convites_providers.dart';
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
            tooltip: AppStrings.conviteComCodigo,
            icon: const Icon(Icons.person_add),
            onPressed: () => _abrirDialogoEntrarComCodigo(context, ref),
          ),
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
        error: (_, _) => AppEstadoErro(
          mensagem: AppStrings.erroGenerico,
          onRetentar: () => ref.invalidate(listasComContagemProvider),
        ),
        data: (listas) => listas.isEmpty
            ? AppEstadoVazio(
                icone: Icons.sticky_note_2_outlined,
                titulo: AppStrings.nenhumaLista,
                descricao: AppStrings.criePrimeiraLista,
                acao: AppBotao(
                  rotulo: AppStrings.criarPrimeiraLista,
                  icone: Icons.add,
                  expandido: false,
                  onPressed: () => _abrirSheetNovaLista(context, ref),
                ),
              )
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-nova-lista',
        onPressed: () => _abrirSheetNovaLista(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.novaLista),
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
    return AppCard(
      padding: EdgeInsets.zero,
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
void _abrirDialogoEntrarComCodigo(BuildContext context, WidgetRef ref) {
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
