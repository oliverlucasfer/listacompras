import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/usuario_local.dart';
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
import '../../../core/widgets/app_snack_bar.dart';
import '../../tour/tour_keys.dart';
import '../domain/lista_com_contagem.dart';
import '../providers/listas_providers.dart';
import 'sheet_titulo_lista.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, F10): todas as listas do aparelho.
class PainelListas extends ConsumerStatefulWidget {
  const PainelListas({super.key});

  @override
  ConsumerState<PainelListas> createState() => _PainelListasState();
}

class _PainelListasState extends ConsumerState<PainelListas> {
  final _busca = TextEditingController();
  bool _buscando = false;
  bool _mostrarArquivadas = false;

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
    final consulta = _busca.text.trim();
    final listasAsync = ref
        .watch(listasComContagemProvider)
        .whenData(
          (todas) => todas
              .where((c) => c.lista.donoId == idLocal)
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
            const Flexible(child: Text(AppStrings.minhasListas)),
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
              key: TourKeys.lupa,
              tooltip: AppStrings.buscar,
              icon: const Icon(Icons.search),
              onPressed: _abrirBusca,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
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
                    AppSpacing.xxxl + AppSpacing.xxl + AppSpacing.sm,
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
      floatingActionButton: FloatingActionButton.extended(
        key: TourKeys.novaLista,
        heroTag: 'fab-nova-lista',
        onPressed: () => abrirSheetNovaLista(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.novaLista),
      ),
    );
  }

  Widget _vazio(BuildContext context, WidgetRef ref) {
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
          padding: const EdgeInsets.only(top: AppSpacing.xs),
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
          itemBuilder: (context) => _itens(context),
        ),
      ),
    );
  }

  int get _pendentes => widget.contagem.totalItens - widget.contagem.concluidos;

  List<PopupMenuEntry<String>> _itens(BuildContext context) => [
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

  void _acaoMenu(String acao) {
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
            .duplicarLista(origemId: lista.id, titulo: nome, donoId: idLocal);
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

Future<void> abrirSheetNovaLista(BuildContext context, WidgetRef ref) {
  return abrirSheetTitulo(
    context,
    titulo: AppStrings.novaLista,
    rotuloBotao: AppStrings.criarLista,
    mensagemSucesso: AppStrings.listaCriada,
    onSalvar: (nome) async {
      await ref
          .read(listasRepositoryProvider)
          .criarLista(titulo: nome, donoId: idLocal);
    },
  );
}
