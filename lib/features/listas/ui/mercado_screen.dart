import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/navigation/voltar_para_inicio.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../auth/providers/auth_providers.dart';
import '../../convites/domain/papel.dart';
import '../../convites/providers/papel_providers.dart';
import '../../sync/ui/indicador_sync.dart';
import '../domain/item.dart';
import '../../../core/dominio/quantidade.dart';
import '../providers/listas_providers.dart';
import 'total_carrinho.dart';

/// Modo mercado (RF-18, doc 05 §6.5, wireframe 10 §3.5): tela focada para
/// usar no corredor — só pendentes grandes, toque para marcar, faixa
/// recolhível "Marcados" como undo e nenhum menu/busca/drag/importação.
class MercadoScreen extends ConsumerStatefulWidget {
  const MercadoScreen({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<MercadoScreen> createState() => _MercadoScreenState();
}

class _MercadoScreenState extends ConsumerState<MercadoScreen> {
  /// Itens marcados nesta sessão de tela (contador do topo). Não inclui os
  /// que já estavam concluídos antes de abrir.
  final _marcadosNaSessao = <String>{};

  Future<void> _marcar(Item item) async {
    setState(() => _marcadosNaSessao.add(item.id));
    await ref
        .read(listasRepositoryProvider)
        .editarItem(item.id, concluido: true);
  }

  Future<void> _desmarcar(Item item) async {
    setState(() => _marcadosNaSessao.remove(item.id));
    await ref
        .read(listasRepositoryProvider)
        .editarItem(item.id, concluido: false);
  }

  /// Ids marcados nesta sessão que ainda existem **e** estão concluídos no
  /// stream atual: um desmarque remoto (LWW) ou soft delete não pode deixar o
  /// contador preso num valor obsoleto (ex.: `1 de 0`). Poda os ausentes.
  int _marcadosValidos(List<Item> itens) {
    final concluidos = {
      for (final item in itens)
        if (item.concluido) item.id,
    };
    _marcadosNaSessao.removeWhere((id) => !concluidos.contains(id));
    return _marcadosNaSessao.length;
  }

  /// Volta à tela da lista; sem pilha (deep link), navega para a rota.
  void _voltarParaLista() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lista/${widget.listaId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listaId = widget.listaId;
    final listaAsync = ref.watch(listaPorIdProvider(listaId));
    return listaAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.modoMercado),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        body: const AppEsqueleto(linhas: 5),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.modoMercado),
          leading: botaoVoltarInicio(context, '/listas'),
        ),
        body: AppEstadoErro(
          mensagem: AppStrings.erroGenerico,
          onRetentar: () => ref.invalidate(listaPorIdProvider(listaId)),
        ),
      ),
      data: (lista) {
        if (lista == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.modoMercado),
              leading: botaoVoltarInicio(context, '/listas'),
            ),
            body: Center(
              child: AppEstadoVazio(
                titulo: AppStrings.listaNaoEncontrada,
                acao: AppBotao(
                  rotulo: AppStrings.voltarParaListas,
                  variante: AppBotaoVariante.texto,
                  expandido: false,
                  onPressed: () => context.go('/listas'),
                ),
              ),
            ),
          );
        }
        final ehDono = lista.donoId == ref.watch(donoAtualIdProvider);
        final inicio = inicioDaLista(ehDono: ehDono);
        // Default conservador: enquanto o papel não carrega, trata como
        // leitor (tela somente leitura, sem checkbox ativo — doc 05 §6.5).
        final podeEscrever =
            ref.watch(papelEfetivoProvider(listaId)) != Papel.leitor;
        final itensAsync = ref.watch(itensDaListaProvider(listaId));
        return PopScopeVoltarInicio(
          inicio: inicio,
          child: Scaffold(
            appBar: AppBar(
              leading: botaoVoltarInicio(context, inicio),
              title: Text(lista.titulo),
            ),
            body: Column(
              children: [
                const IndicadorSync(),
                Expanded(
                  child: itensAsync.when(
                    loading: () => const AppEsqueleto(linhas: 5),
                    error: (_, _) => AppEstadoErro(
                      mensagem: AppStrings.erroGenerico,
                      onRetentar: () =>
                          ref.invalidate(itensDaListaProvider(listaId)),
                    ),
                    data: (itens) => _CorpoMercado(
                      listaId: listaId,
                      itens: itens,
                      marcadosNaSessao: _marcadosValidos(itens),
                      podeEscrever: podeEscrever,
                      onMarcar: _marcar,
                      onDesmarcar: _desmarcar,
                      onVoltarParaLista: _voltarParaLista,
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

class _CorpoMercado extends StatelessWidget {
  const _CorpoMercado({
    required this.listaId,
    required this.itens,
    required this.marcadosNaSessao,
    required this.podeEscrever,
    required this.onMarcar,
    required this.onDesmarcar,
    required this.onVoltarParaLista,
  });

  final String listaId;
  final List<Item> itens;

  /// Quantidade de itens marcados nesta sessão e ainda concluídos no stream.
  final int marcadosNaSessao;
  final bool podeEscrever;
  final ValueChanged<Item> onMarcar;
  final ValueChanged<Item> onDesmarcar;
  final VoidCallback onVoltarParaLista;

  @override
  Widget build(BuildContext context) {
    final pendentes = itens.where((i) => !i.concluido).toList();
    final concluidos = itens.where((i) => i.concluido).toList();
    // A faixa aberta não pode consumir o corpo inteiro: um teto de 40% da
    // tela garante espaço para a área principal mesmo com muitos concluídos.
    final maxFaixa = MediaQuery.sizeOf(context).height * 0.4;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              AppStrings.mercadoProgresso(marcadosNaSessao, itens.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        TotalCarrinho(listaId: listaId),
        Expanded(
          child: pendentes.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: AppEstadoVazio(
                        icone: Icons.shopping_cart_checkout,
                        titulo: AppStrings.mercadoTudoComprado,
                        acao: AppBotao(
                          rotulo: AppStrings.voltarParaLista,
                          variante: AppBotaoVariante.outlined,
                          expandido: false,
                          onPressed: onVoltarParaLista,
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: pendentes.length,
                  itemBuilder: (context, index) => _LinhaMercado(
                    item: pendentes[index],
                    concluido: false,
                    podeEscrever: podeEscrever,
                    onAlternar: () => onMarcar(pendentes[index]),
                  ),
                ),
        ),
        if (concluidos.isNotEmpty)
          _FaixaMarcados(
            itens: concluidos,
            maxAltura: maxFaixa,
            podeEscrever: podeEscrever,
            abrirInicialmente: marcadosNaSessao > 0,
            onDesmarcar: onDesmarcar,
          ),
      ],
    );
  }
}

/// Linha generosa de item do mercado: checkbox à esquerda (alvo ≥48dp) e
/// toque em toda a linha alterna o estado.
class _LinhaMercado extends StatelessWidget {
  const _LinhaMercado({
    required this.item,
    required this.concluido,
    required this.podeEscrever,
    required this.onAlternar,
  });

  final Item item;
  final bool concluido;
  final bool podeEscrever;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return InkWell(
      onTap: podeEscrever ? onAlternar : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              MergeSemantics(
                child: Semantics(
                  label: item.nome,
                  child: Checkbox(
                    value: concluido,
                    onChanged: podeEscrever ? (_) => onAlternar() : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        decoration: concluido
                            ? TextDecoration.lineThrough
                            : null,
                        color: concluido ? cores.onSurfaceVariant : null,
                      ),
                    ),
                    Text(
                      '${formatarQuantidade(item.quantidade)} '
                      '${item.unidade.valor}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cores.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa recolhível "Marcados (n)" no rodapé: toque no item desmarca e ele
/// volta aos pendentes. Fecha por padrão e abre automaticamente na primeira
/// marcação da sessão.
///
/// O conteúdo fica sempre montado (altura 0 quando fechada) para preservar o
/// estado da animação e a semântica dos itens; a altura 0 impede toque/pintura
/// e o `ExcludeSemantics` evita anunciar itens escondidos.
///
/// Ao abrir, a área expansível é limitada a ~40% da tela com rolagem interna
/// (`ListView`): sem esse teto, listas reais (~9+ concluídos) estouram a
/// `Column` do corpo e esmagam a área de pendentes.
class _FaixaMarcados extends StatefulWidget {
  const _FaixaMarcados({
    required this.itens,
    required this.maxAltura,
    required this.podeEscrever,
    required this.abrirInicialmente,
    required this.onDesmarcar,
  });

  final List<Item> itens;

  /// Teto da área expansível quando aberta (rolagem interna a partir daí).
  final double maxAltura;
  final bool podeEscrever;
  final bool abrirInicialmente;
  final ValueChanged<Item> onDesmarcar;

  @override
  State<_FaixaMarcados> createState() => _FaixaMarcadosState();
}

class _FaixaMarcadosState extends State<_FaixaMarcados> {
  late bool _aberta = widget.abrirInicialmente;

  @override
  void didUpdateWidget(covariant _FaixaMarcados oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.abrirInicialmente && !oldWidget.abrirInicialmente) {
      _aberta = true;
    }
  }

  void _alternar() {
    if (!widget.podeEscrever) return;
    setState(() => _aberta = !_aberta);
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Material(
      color: cores.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _aberta,
            child: ListTile(
              onTap: _alternar,
              title: Text(
                '${AppStrings.mercadoMarcados} (${widget.itens.length})',
              ),
              trailing: Icon(_aberta ? Icons.expand_less : Icons.expand_more),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              heightFactor: _aberta ? 1 : 0,
              child: ExcludeSemantics(
                excluding: !_aberta,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxAltura),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.itens.length,
                    itemBuilder: (context, index) => _LinhaMercado(
                      item: widget.itens[index],
                      concluido: true,
                      podeEscrever: widget.podeEscrever,
                      onAlternar: () => widget.onDesmarcar(widget.itens[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
