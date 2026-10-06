import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/l10n/categoria_l10n.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/voltar_para_inicio.dart';
import '../../../core/texto/busca.dart';
import '../../../core/texto/normalizar.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../compartilhamento/ui/sheet_compartilhar.dart';
import '../../historico/domain/mercado.dart';
import '../../historico/providers/historico_providers.dart';
import '../../historico/ui/modal_finalizar_compra.dart';
import '../../importacao/ui/modal_importar.dart';
import '../../importacao/ui/modal_previsao_importacao.dart';
import '../../tour/tour_controller.dart';
import '../../tour/tour_keys.dart';
import '../../tour/ui/tour_loader.dart';
import '../../voz/domain/reconhecimento_voz.dart';
import '../../voz/providers/reconhecimento_voz_provider.dart';
import '../../widget/providers/widget_providers.dart';
import '../../../core/dominio/categoria.dart';
import '../domain/historico_preco.dart';
import '../domain/item.dart';
import '../domain/orcamento.dart';
import '../domain/preco.dart';
import '../../../core/dominio/quantidade.dart';
import '../../../core/utils/formatacao.dart';
import '../domain/resultado_dedup.dart';
import '../domain/sugestao_item.dart';
import '../../../core/dominio/unidade.dart';
import '../providers/listas_providers.dart';
import '../providers/ordem_categorias_provider.dart';
import 'aviso_orcamento.dart';
import 'modal_adicionar_de_outra_lista.dart';
import 'sheet_titulo_lista.dart';
import 'total_carrinho.dart';

part 'alerta_orcamento_categorias.dart';
part 'campo_adicionar_item.dart';
part 'dialogo_orcamento.dart';
part 'linha_item.dart';
part 'lista_itens.dart';
part 'sheet_editar_item.dart';

/// Tela da Lista de Compras (doc 05 §6.3, wireframe 10 §3.1, RF-03/RF-04).
class TelaListaScreen extends ConsumerStatefulWidget {
  const TelaListaScreen({super.key, required this.listaId, this.foco = false});

  final String listaId;

  /// Foca o campo de adicionar ao abrir (rota `/adicionar`, RF-38, F55).
  final bool foco;

  @override
  ConsumerState<TelaListaScreen> createState() => _TelaListaScreenState();
}

class _TelaListaScreenState extends ConsumerState<TelaListaScreen> {
  /// Texto da busca isolado num [ValueNotifier] para o corpo reagir sem
  /// reconstruir a AppBar e o restante da tela a cada tecla (RF-17).
  final _consulta = ValueNotifier<String>('');

  /// Permite limpar o campo controlado pelo [_CampoBusca] sem `setState`.
  final _buscaKey = GlobalKey<_CampoBuscaState>();
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    // Registra a lista aberta para o widget apontar a rota `/adicionar`
    // (RF-38, F55). Adiado para depois do frame: o registro reativo atualiza um
    // provider e não pode rodar durante o build da árvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(ultimaListaProvider.notifier).registrar(widget.listaId),
      );
    });
  }

  @override
  void dispose() {
    _consulta.dispose();
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    if (!mounted) return;
    _consulta.value = '';
    _buscaKey.currentState?.limpar();
    setState(() => _buscando = false);
  }

  void _limparBusca() {
    if (!mounted) return;
    _consulta.value = '';
    _buscaKey.currentState?.limpar();
  }

  Future<void> _acaoMenu(
    BuildContext context,
    WidgetRef ref,
    String idLista,
    String acao,
  ) async {
    final repo = ref.read(listasRepositoryProvider);
    switch (acao) {
      case 'desmarcar':
        try {
          await repo.desmarcarTodos(idLista);
        } catch (_) {
          if (context.mounted) {
            mostrarSnackBar(context, context.l10n.erroGenerico);
          }
        }
      case 'limpar':
        _confirmarLimparConcluidos(context, ref, idLista);
      case 'finalizar':
        await abrirFinalizarCompra(context, ref, idLista);
      case 'renomear':
        abrirSheetTitulo(
          context,
          titulo: context.l10n.renomearLista,
          rotuloBotao: context.l10n.salvar,
          mensagemSucesso: context.l10n.listaRenomeada,
          onSalvar: (nome) => repo.renomearLista(id: idLista, titulo: nome),
        );
      case 'orcamento':
        _abrirDialogoOrcamento(context, ref, idLista);
      case 'excluir':
        _confirmarExcluirLista(context, ref, idLista);
      case 'outraLista':
        _adicionarDeOutraLista(context, ref, idLista);
      case 'compartilhar':
        await abrirSheetCompartilhar(context, ref, idLista);
    }
  }

  /// Abre o diálogo de orçamento da lista (RF-28, F36-T03): campo em R$ com
  /// erro inline, Salvar e Remover orçamento. Escrita offline-first (Drift +
  /// fila via repositório); o leitor não vê a ação no menu.
  Future<void> _abrirDialogoOrcamento(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) {
    final orcamento = ref
        .read(listaPorIdProvider(idLista))
        .value
        ?.orcamentoCentavos;
    final repo = ref.read(listasRepositoryProvider);
    return showDialog<void>(
      context: context,
      builder: (_) => _DialogoOrcamento(
        orcamentoCentavos: orcamento,
        onSalvar: (centavos) =>
            repo.definirOrcamento(idLista, centavos: centavos),
        onRemover: () => repo.definirOrcamento(idLista, centavos: null),
      ),
    );
  }

  /// Adicionar itens pendentes de outra lista (F27-T02, RF-23): abre o modal,
  /// aplica a dedup no lote e dá feedback da quantidade adicionada.
  Future<void> _adicionarDeOutraLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final selecionados = await abrirModalAdicionarDeOutraLista(
      context,
      listaAtualId: idLista,
    );
    if (selecionados == null || selecionados.isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(listasRepositoryProvider)
          .adicionarItensDedup(idLista, selecionados);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
      return;
    }
    if (context.mounted) {
      mostrarSnackBar(
        context,
        context.l10n.itensAdicionadosDeOutra(selecionados.length),
      );
    }
  }

  Future<void> _confirmarLimparConcluidos(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: context.l10n.limparConcluidos,
      mensagem: context.l10n.limparConcluidosMensagem,
      confirmar: context.l10n.limpar,
    );
    if (!confirmou) return;
    final repo = ref.read(listasRepositoryProvider);
    final List<Item> removidos;
    try {
      removidos = await repo.limparConcluidos(idLista);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
      return;
    }
    if (!context.mounted || removidos.isEmpty) return;
    mostrarSnackBar(
      context,
      context.l10n.concluidosRemovidos,
      rotuloAcao: context.l10n.desfazer,
      onAcao: () {
        unawaited(() async {
          try {
            for (final item in removidos) {
              await repo.restaurarItem(item.id);
            }
          } catch (_) {
            if (context.mounted) {
              mostrarSnackBar(context, context.l10n.erroGenerico);
            }
          }
        }());
      },
    );
  }

  Future<void> _confirmarExcluirLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final titulo = ref.read(listaPorIdProvider(idLista)).value?.titulo ?? '';
    final nItens = ref.read(itensDaListaProvider(idLista)).value?.length ?? 0;
    final confirmou = await AppDialog.confirmarDestrutivo(
      context,
      titulo: context.l10n.excluirListaTitulo(titulo),
      mensagem: context.l10n.excluirListaMensagem(nItens, 'false'),
    );
    if (!confirmou) return;
    try {
      await ref.read(listasRepositoryProvider).excluirLista(idLista);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, context.l10n.erroGenerico);
      return;
    }
    if (context.mounted) context.go('/listas');
  }

  /// Importação de lista (doc 05 §6.4, RF-16): entrada → pré-visualização
  /// → gravação local dos itens confirmados.
  Future<void> _importarLista(
    BuildContext context,
    WidgetRef ref,
    String idLista,
  ) async {
    final resposta = await abrirModalImportar(context, ref, idLista);
    if (resposta == null || !context.mounted) return;
    await confirmarItensImportados(context, ref, idLista, resposta);
  }

  @override
  Widget build(BuildContext context) {
    final listaId = widget.listaId;
    final listaAsync = ref.watch(listaPorIdProvider(listaId));
    return listaAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.lista),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        body: const AppEsqueleto(linhas: 5),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.lista),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        // Erro com retry, no padrão dos demais estados (doc 15 §3, F14-T04).
        body: AppEstadoErro(
          mensagem: context.l10n.erroGenerico,
          onRetentar: () => ref.invalidate(listaPorIdProvider(listaId)),
        ),
      ),
      data: (lista) {
        if (lista == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.lista),
              leading: botaoVoltarInicio(context, '/listas'),
            ),
            body: Center(
              child: AppEstadoVazio(
                titulo: context.l10n.listaNaoEncontrada,
                acao: AppBotao(
                  rotulo: context.l10n.voltarParaListas,
                  variante: AppBotaoVariante.texto,
                  expandido: false,
                  onPressed: () => context.go('/listas'),
                ),
              ),
            ),
          );
        }
        final inicio = inicioDaLista();
        final itens =
            ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
        // Mercado da última ida desta lista (RF-35, F52): consulta escopada de
        // uma linha (sem varrer o histórico inteiro).
        final mercado = ref.watch(mercadoUltimaIdaProvider(listaId)).value;
        return PopScopeVoltarInicio(
          inicio: inicio,
          child: Scaffold(
            appBar: AppBar(
              leading: botaoVoltarInicio(context, inicio),
              title: Text(lista.titulo),
              actions: [
                IconButton(
                  key: TourKeys.botaoMercado,
                  tooltip: context.l10n.modoMercado,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  onPressed: () => context.push('/mercado/${lista.id}'),
                ),
                if (_buscando)
                  IconButton(
                    tooltip: context.l10n.limparBusca,
                    icon: const Icon(Icons.close),
                    onPressed: _fecharBusca,
                  )
                else
                  IconButton(
                    tooltip: context.l10n.buscar,
                    icon: const Icon(Icons.search),
                    onPressed: _abrirBusca,
                  ),
                PopupMenuButton<String>(
                  key: TourKeys.menuMais,
                  tooltip: context.l10n.menu,
                  onSelected: (acao) => _acaoMenu(context, ref, lista.id, acao),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'desmarcar',
                      child: Text(context.l10n.desmarcarTodos),
                    ),
                    PopupMenuItem(
                      value: 'limpar',
                      child: Text(context.l10n.limparConcluidos),
                    ),
                    if (itens.any((i) => i.concluido))
                      PopupMenuItem(
                        value: 'finalizar',
                        child: Text(context.l10n.finalizarCompra),
                      ),
                    PopupMenuItem(
                      value: 'renomear',
                      child: Text(context.l10n.renomearLista),
                    ),
                    PopupMenuItem(
                      value: 'orcamento',
                      child: Text(context.l10n.orcamento),
                    ),
                    PopupMenuItem(
                      value: 'outraLista',
                      child: Text(context.l10n.adicionarDeOutraLista),
                    ),
                    PopupMenuItem(
                      value: 'compartilhar',
                      child: Text(context.l10n.compartilharLista),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text(
                        context.l10n.excluirLista,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (mercado != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: const Icon(Icons.storefront_outlined, size: 18),
                        label: Text(mercado),
                      ),
                    ),
                  ),
                if (_buscando)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: _CampoBusca(
                      key: _buscaKey,
                      onChanged: (valor) => _consulta.value = valor,
                    ),
                  ),
                _CampoAdicionar(
                  listaId: listaId,
                  autofocus: widget.foco,
                  onItemAdicionado: _buscando ? _fecharBusca : null,
                ),
                Expanded(
                  child: _ListaItens(
                    listaId: listaId,
                    consulta: _consulta,
                    onLimparBusca: _limparBusca,
                  ),
                ),
                TotalCarrinho(listaId: listaId),
                _AlertaOrcamentoCategorias(listaId: listaId),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (itens.any((i) => i.concluido))
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: AppBotao(
                              rotulo: context.l10n.finalizarCompra,
                              icone: Icons.shopping_bag_outlined,
                              onPressed: () =>
                                  abrirFinalizarCompra(context, ref, listaId),
                            ),
                          ),
                        AppBotao(
                          key: TourKeys.botaoImportar,
                          rotulo: context.l10n.importarLista,
                          variante: AppBotaoVariante.outlined,
                          icone: Icons.playlist_add,
                          onPressed: () =>
                              _importarLista(context, ref, listaId),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Campo de busca por nome na lista (RF-17). Dono do próprio
/// [TextEditingController] e do `autofocus`; notifica a tela a cada tecla sem
/// `setState` (o corpo escuta o [ValueNotifier]). Expõe [limpar] para o
/// controlador externo zerar o campo sem reconstruir a tela.
class _CampoBusca extends StatefulWidget {
  const _CampoBusca({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<_CampoBusca> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void limpar() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    return AppCampoTexto(
      controller: _controller,
      label: context.l10n.buscarItem,
      hint: context.l10n.nomeDoItem,
      autofocus: true,
      onChanged: widget.onChanged,
    );
  }
}
