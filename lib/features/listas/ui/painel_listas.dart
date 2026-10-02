import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/usuario_local.dart';
import '../../../core/l10n/l10n.dart';
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

/// Formata o tempo relativo na borda de UI (RF-39, F56): a camada de domínio
/// devolve apenas [TempoRelativo]; o texto fica aqui.
String _textoTempoRelativo(BuildContext context, TempoRelativo tempo) =>
    switch (tempo.tipo) {
      TempoRelativoTipo.agora => context.l10n.tempoAgora,
      TempoRelativoTipo.minutos => context.l10n.tempoMinutos(tempo.valor),
      TempoRelativoTipo.horas => context.l10n.tempoHoras(tempo.valor),
      TempoRelativoTipo.ontem => context.l10n.tempoOntem,
      TempoRelativoTipo.dias => context.l10n.tempoDias(tempo.valor),
      TempoRelativoTipo.meses => context.l10n.tempoMeses(tempo.valor),
      TempoRelativoTipo.anos => context.l10n.tempoAnos(tempo.valor),
    };

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
            Flexible(child: Text(context.l10n.minhasListas)),
          ],
        ),
        actions: [
          if (_buscando)
            IconButton(
              tooltip: context.l10n.limparBusca,
              icon: const Icon(Icons.close),
              onPressed: _fecharBusca,
            )
          else ...[
            IconButton(
              tooltip: context.l10n.mostrarArquivadas,
              icon: Icon(
                _mostrarArquivadas
                    ? Icons.inventory_2
                    : Icons.inventory_2_outlined,
              ),
              onPressed: () =>
                  setState(() => _mostrarArquivadas = !_mostrarArquivadas),
            ),
            IconButton(
              tooltip: context.l10n.receberLista,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => context.push('/receber-lista'),
            ),
            IconButton(
              key: TourKeys.lupa,
              tooltip: context.l10n.buscar,
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
                label: context.l10n.buscarLista,
                hint: context.l10n.nomeDaLista,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: listasAsync.when(
              loading: () => const AppEsqueleto(linhas: 4),
              error: (_, _) => AppEstadoErro(
                mensagem: context.l10n.erroGenerico,
                onRetentar: () => ref.invalidate(listasComContagemProvider),
              ),
              data: (listas) {
                if (listas.isEmpty) {
                  return _buscando && consulta.isNotEmpty
                      ? AppEstadoVazio(
                          icone: Icons.search_off,
                          titulo: context.l10n.nenhumaListaEncontrada,
                          descricao: context.l10n.buscaSemResultadoDica,
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
        label: Text(context.l10n.novaLista),
      ),
    );
  }

  Widget _vazio(BuildContext context, WidgetRef ref) {
    return AppEstadoVazio(
      icone: Icons.sticky_note_2_outlined,
      titulo: context.l10n.nenhumaLista,
      descricao: context.l10n.criePrimeiraLista,
      acao: AppBotao(
        rotulo: context.l10n.criarPrimeiraLista,
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
              Text(
                context.l10n.progressoLista(
                  widget.contagem.concluidos,
                  widget.contagem.totalItens,
                ),
              ),
              Text(
                '${context.l10n.atualizada} ${_textoTempoRelativo(context, tempoRelativo(lista.atualizadoEm, agora: DateTime.now()))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (lista.arquivadaEm != null)
                AppChip(rotulo: context.l10n.arquivada),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: _menuKey,
          tooltip: context.l10n.menu,
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
      PopupMenuItem(value: 'arquivar', child: Text(context.l10n.arquivar))
    else
      PopupMenuItem(
        value: 'desarquivar',
        child: Text(context.l10n.desarquivar),
      ),
    if (_pendentes > 0)
      PopupMenuItem(value: 'duplicar', child: Text(context.l10n.comprarDeNovo)),
    PopupMenuItem(value: 'renomear', child: Text(context.l10n.renomear)),
    PopupMenuItem(
      value: 'excluir',
      child: Text(
        context.l10n.excluir,
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
      titulo: context.l10n.comprarDeNovo,
      descricao: context.l10n.duplicarDescricao(_pendentes),
      rotuloBotao: context.l10n.criarLista,
      valorInicial: lista.titulo,
      mensagemSucesso: context.l10n.listaCriada,
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
      titulo: context.l10n.renomearLista,
      rotuloBotao: context.l10n.salvar,
      valorInicial: widget.contagem.lista.titulo,
      mensagemSucesso: context.l10n.listaRenomeada,
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
          arquivada
              ? context.l10n.listaArquivada
              : context.l10n.listaDesarquivada,
        );
      }
    } catch (_) {
      if (mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
    }
  }

  Future<void> _confirmarExclusao() async {
    final contagem = widget.contagem;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: context.l10n.excluirListaTitulo(contagem.lista.titulo),
      mensagem: context.l10n.excluirListaMensagem(contagem.totalItens, 'false'),
    );
    if (confirmou) {
      await ref.read(listasRepositoryProvider).excluirLista(contagem.lista.id);
    }
  }
}

Future<void> abrirSheetNovaLista(BuildContext context, WidgetRef ref) {
  return abrirSheetTitulo(
    context,
    titulo: context.l10n.novaLista,
    rotuloBotao: context.l10n.criarLista,
    mensagemSucesso: context.l10n.listaCriada,
    onSalvar: (nome) async {
      await ref
          .read(listasRepositoryProvider)
          .criarLista(titulo: nome, donoId: idLocal);
    },
  );
}
