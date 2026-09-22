import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/texto/busca.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/utils/tempo_relativo.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_logo.dart';
import '../../sync/ui/indicador_sync.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../../convites/domain/convite.dart';
import '../../convites/domain/papel.dart';
import '../../convites/providers/convites_providers.dart';
import '../../convites/providers/papel_providers.dart';
import '../../convites/ui/acao_sair_da_lista.dart';
import '../../convites/ui/convites_pendentes_secao.dart';
import '../domain/lista_com_contagem.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';

/// Filtro do painel de listas (doc 05 §6.2, F10): as listas em que o usuário
/// é dono vs. aquelas em que participa como membro.
enum FiltroListas { minhas, compartilhadas }

/// Painel de listas reutilizável (Minhas × Compartilhadas).
class PainelListas extends ConsumerStatefulWidget {
  const PainelListas({super.key, required this.filtro});

  final FiltroListas filtro;

  @override
  ConsumerState<PainelListas> createState() => _PainelListasState();
}

class _PainelListasState extends ConsumerState<PainelListas> {
  final _busca = TextEditingController();
  bool _buscando = false;
  bool _mostrarArquivadas = false;

  bool get _compartilhadas => widget.filtro == FiltroListas.compartilhadas;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    if (!mounted) return;
    _busca.clear();
    setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(donoAtualIdProvider);
    final consulta = _busca.text.trim();
    final listasAsync = ref
        .watch(listasComContagemProvider)
        .whenData(
          (todas) => todas
              .where(
                (c) => _compartilhadas
                    ? c.lista.donoId != usuario
                    : c.lista.donoId == usuario,
              )
              .where((c) => _mostrarArquivadas || c.lista.arquivadaEm == null)
              .where(
                (c) =>
                    consulta.isEmpty || contemBusca(c.lista.titulo, consulta),
              )
              .toList(),
        );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                _compartilhadas
                    ? AppStrings.compartilhadas
                    : AppStrings.minhasListas,
              ),
            ),
          ],
        ),
        actions: [
          if (_buscando)
            IconButton(
              tooltip: AppStrings.limparBusca,
              icon: const Icon(Icons.close),
              onPressed: _fecharBusca,
            )
          else ...[
            IconButton(
              tooltip: AppStrings.mostrarArquivadas,
              icon: Icon(
                _mostrarArquivadas
                    ? Icons.inventory_2
                    : Icons.inventory_2_outlined,
              ),
              onPressed: () =>
                  setState(() => _mostrarArquivadas = !_mostrarArquivadas),
            ),
            IconButton(
              tooltip: AppStrings.buscar,
              icon: const Icon(Icons.search),
              onPressed: _abrirBusca,
            ),
            if (_compartilhadas)
              IconButton(
                tooltip: AppStrings.conviteComCodigo,
                icon: const Icon(Icons.person_add),
                onPressed: () => abrirDialogoEntrarComCodigo(context, ref),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: IndicadorSync(),
          ),
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
                label: AppStrings.buscarLista,
                hint: AppStrings.nomeDaLista,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (!_compartilhadas) const ConvitesPendentesSecao(),
          Expanded(
            child: listasAsync.when(
              loading: () => const AppEsqueleto(linhas: 4),
              error: (_, _) => AppEstadoErro(
                mensagem: AppStrings.erroGenerico,
                onRetentar: () => ref.invalidate(listasComContagemProvider),
              ),
              data: (listas) {
                if (listas.isEmpty) {
                  return _buscando && consulta.isNotEmpty
                      ? const AppEstadoVazio(
                          icone: Icons.search_off,
                          titulo: AppStrings.nenhumaListaEncontrada,
                          descricao: AppStrings.buscaSemResultadoDica,
                        )
                      : _vazio(context, ref);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    88,
                  ),
                  itemCount: listas.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CardLista(contagem: listas[i]),
                );
              },
            ),
          ),
        ],
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

class _CardLista extends ConsumerStatefulWidget {
  const _CardLista({required this.contagem});

  final ListaComContagem contagem;

  @override
  ConsumerState<_CardLista> createState() => _CardListaState();
}

class _CardListaState extends ConsumerState<_CardLista> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) {
    final lista = widget.contagem.lista;
    final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/lista/${lista.id}'),
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
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
              Text(widget.contagem.contagem),
              Text(
                '${AppStrings.atualizada} ${tempoRelativo(lista.atualizadoEm, agora: DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (lista.arquivadaEm != null)
                const AppChip(rotulo: AppStrings.arquivada),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: _menuKey,
          tooltip: AppStrings.menu,
          icon: const Icon(Icons.more_vert),
          onSelected: _acaoMenu,
          itemBuilder: (context) =>
              ehDono ? _itensDono(context) : _itensMembro(),
        ),
      ),
    );
  }

  int get _pendentes => widget.contagem.totalItens - widget.contagem.concluidos;

  List<PopupMenuEntry<String>> _itensDono(BuildContext context) => [
    if (widget.contagem.lista.arquivadaEm == null)
      const PopupMenuItem(value: 'arquivar', child: Text(AppStrings.arquivar))
    else
      const PopupMenuItem(
        value: 'desarquivar',
        child: Text(AppStrings.desarquivar),
      ),
    if (_pendentes > 0)
      const PopupMenuItem(
        value: 'duplicar',
        child: Text(AppStrings.comprarDeNovo),
      ),
    const PopupMenuItem(value: 'renomear', child: Text(AppStrings.renomear)),
    PopupMenuItem(
      value: 'excluir',
      child: Text(
        AppStrings.excluir,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  ];

  List<PopupMenuEntry<String>> _itensMembro() => [
    if (_pendentes > 0)
      const PopupMenuItem(
        value: 'duplicar',
        child: Text(AppStrings.comprarDeNovo),
      ),
    const PopupMenuItem(value: 'membros', child: Text(AppStrings.membros)),
    const PopupMenuItem(value: 'sair', child: Text(AppStrings.sairDaLista)),
  ];

  void _acaoMenu(String acao) {
    final listaId = widget.contagem.lista.id;
    switch (acao) {
      case 'duplicar':
        _duplicar();
      case 'renomear':
        _abrirSheetRenomear();
      case 'arquivar':
        _definirArquivada(true);
      case 'desarquivar':
        _definirArquivada(false);
      case 'excluir':
        _confirmarExclusao();
      case 'membros':
        context.push('/membros/$listaId');
      case 'sair':
        confirmarSairDaLista(context, ref, listaId);
    }
  }

  Future<void> _duplicar() async {
    final lista = widget.contagem.lista;
    String? criadoId;
    await abrirSheetTitulo(
      context,
      titulo: AppStrings.comprarDeNovo,
      descricao: AppStrings.duplicarDescricao(_pendentes),
      rotuloBotao: AppStrings.criarLista,
      valorInicial: lista.titulo,
      mensagemSucesso: AppStrings.listaCriada,
      onSalvar: (nome) async {
        final nova = await ref
            .read(listasRepositoryProvider)
            .duplicarLista(
              origemId: lista.id,
              titulo: nome,
              donoId: ref.read(donoAtualIdProvider),
            );
        ref.read(papelRepositoryProvider).atualizar(nova.id, Papel.dono);
        criadoId = nova.id;
      },
    );
    if (criadoId != null && mounted) {
      context.push('/lista/$criadoId');
    }
  }

  void _abrirSheetRenomear() {
    abrirSheetTitulo(
      context,
      titulo: AppStrings.renomearLista,
      rotuloBotao: AppStrings.salvar,
      valorInicial: widget.contagem.lista.titulo,
      mensagemSucesso: AppStrings.listaRenomeada,
      onSalvar: (nome) => ref
          .read(listasRepositoryProvider)
          .renomearLista(id: widget.contagem.lista.id, titulo: nome),
    );
  }

  Future<void> _definirArquivada(bool arquivada) async {
    try {
      await ref
          .read(listasRepositoryProvider)
          .definirArquivada(widget.contagem.lista.id, arquivada: arquivada);
      if (mounted) {
        mostrarSnackBar(
          context,
          arquivada ? AppStrings.listaArquivada : AppStrings.listaDesarquivada,
        );
      }
    } catch (_) {
      if (mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }

  Future<void> _confirmarExclusao() async {
    final contagem = widget.contagem;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: AppStrings.excluirListaTitulo(contagem.lista.titulo),
      mensagem: AppStrings.excluirListaMensagem(
        contagem.totalItens,
        temMembros: false,
      ),
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
    mensagemSucesso: AppStrings.listaCriada,
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
