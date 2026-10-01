import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../listas/domain/preco.dart';
import '../domain/estatisticas.dart';
import '../providers/historico_providers.dart';
import 'grafico_gasto_mensal.dart';

/// Aba de estatísticas do histórico (RF-34, F51): gasto por período (últimos
/// 12 meses), gasto por categoria, itens mais comprados e evolução de preço.
class EstatisticasTab extends ConsumerStatefulWidget {
  const EstatisticasTab({super.key});

  @override
  ConsumerState<EstatisticasTab> createState() => _EstatisticasTabState();
}

class _EstatisticasTabState extends ConsumerState<EstatisticasTab> {
  static const _maxMeses = 12;
  String? _nomeSelecionado;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        const AppCabecalhoSecao(AppStrings.gastoPorPeriodo),
        const _SecaoGastoPorPeriodo(maxMeses: _maxMeses),
        const AppCabecalhoSecao(AppStrings.gastoPorCategoria),
        const _SecaoGastoPorCategoria(),
        const AppCabecalhoSecao(AppStrings.gastoPorMercado),
        const _SecaoGastoPorMercado(),
        const AppCabecalhoSecao(AppStrings.itensMaisComprados),
        const _SecaoItensMaisComprados(),
        const AppCabecalhoSecao(AppStrings.evolucaoDePreco),
        _SecaoEvolucaoPreco(
          nomeSelecionado: _nomeSelecionado,
          onSelecionar: (nome) => setState(() => _nomeSelecionado = nome),
        ),
      ],
    );
  }
}

class _SecaoGastoPorPeriodo extends ConsumerWidget {
  const _SecaoGastoPorPeriodo({required this.maxMeses});

  final int maxMeses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(gastoPorMesProvider);
    return dados.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(gastoPorMesProvider),
      ),
      data: (meses) {
        final ultimos = meses.length > maxMeses
            ? meses.sublist(meses.length - maxMeses)
            : meses;
        if (ultimos.isEmpty) return const _SemDados();
        final total = ultimos.fold<int>(0, (s, m) => s + m.totalCentavos);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GraficoGastoMensal(dados: ultimos),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                AppStrings.totalNoPeriodo(formatarReais(total)),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SecaoGastoPorCategoria extends ConsumerWidget {
  const _SecaoGastoPorCategoria();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(gastoPorCategoriaProvider);
    return dados.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(gastoPorCategoriaProvider),
      ),
      data: (categorias) {
        if (categorias.isEmpty) return const _SemDados();
        final total = categorias.fold<int>(
          0,
          (soma, c) => soma + c.totalCentavos,
        );
        return Column(
          children: [
            for (final c in categorias)
              ListTile(
                dense: true,
                title: Text(c.categoria.rotulo),
                trailing: Text(
                  '${formatarReais(c.totalCentavos)} · '
                  '${_percentual(c.totalCentavos, total)}',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SecaoGastoPorMercado extends ConsumerWidget {
  const _SecaoGastoPorMercado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(gastoPorMercadoProvider);
    return dados.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(gastoPorMercadoProvider),
      ),
      data: (mercados) {
        if (mercados.isEmpty) return const _SemDados();
        return Column(
          children: [
            for (final m in mercados)
              ListTile(
                dense: true,
                title: Text(m.mercado ?? AppStrings.semMercado),
                trailing: Text(formatarReais(m.totalCentavos)),
              ),
          ],
        );
      },
    );
  }
}

class _SecaoItensMaisComprados extends ConsumerStatefulWidget {
  const _SecaoItensMaisComprados();

  @override
  ConsumerState<_SecaoItensMaisComprados> createState() =>
      _SecaoItensMaisCompradosState();
}

class _SecaoItensMaisCompradosState
    extends ConsumerState<_SecaoItensMaisComprados> {
  _OrdemItens _ordem = _OrdemItens.frequencia;

  @override
  Widget build(BuildContext context) {
    final dados = ref.watch(itensMaisCompradosProvider);
    return dados.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(itensMaisCompradosProvider),
      ),
      data: (itens) {
        if (itens.isEmpty) return const _SemDados();
        final ordenados = [...itens]
          ..sort((a, b) {
            if (_ordem == _OrdemItens.gasto) {
              final c = b.totalCentavos.compareTo(a.totalCentavos);
              return c != 0 ? c : a.nome.compareTo(b.nome);
            }
            final c = b.vezes.compareTo(a.vezes);
            return c != 0 ? c : a.nome.compareTo(b.nome);
          });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SegmentedButton<_OrdemItens>(
                segments: const [
                  ButtonSegment(
                    value: _OrdemItens.frequencia,
                    label: Text(AppStrings.porFrequencia),
                  ),
                  ButtonSegment(
                    value: _OrdemItens.gasto,
                    label: Text(AppStrings.porGasto),
                  ),
                ],
                selected: {_ordem},
                onSelectionChanged: (selecao) =>
                    setState(() => _ordem = selecao.first),
              ),
            ),
            for (final item in ordenados)
              ListTile(
                dense: true,
                title: Text(item.nome),
                trailing: Text(
                  '${item.vezes}x · ${formatarReais(item.totalCentavos)}',
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _OrdemItens { frequencia, gasto }

class _SecaoEvolucaoPreco extends ConsumerWidget {
  const _SecaoEvolucaoPreco({
    required this.nomeSelecionado,
    required this.onSelecionar,
  });

  final String? nomeSelecionado;
  final ValueChanged<String?> onSelecionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nomesAsync = ref.watch(nomesCompradosProvider);
    return nomesAsync.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(nomesCompradosProvider),
      ),
      data: (nomes) {
        if (nomes.isEmpty) return const _SemDados();
        final selecao =
            nomeSelecionado != null && nomes.contains(nomeSelecionado)
            ? nomeSelecionado
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDropdown<String?>(
                label: AppStrings.evolucaoDePreco,
                valor: selecao,
                expandido: true,
                itens: [
                  for (final nome in nomes)
                    DropdownMenuItem<String?>(
                      value: nome,
                      child: Text(_rotuloNome(nome)),
                    ),
                ],
                onChanged: onSelecionar,
              ),
              if (selecao != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _SeriePreco(nome: selecao),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SeriePreco extends ConsumerWidget {
  const _SeriePreco({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidadeAsync = ref.watch(unidadeRecenteProvider(nome));
    return unidadeAsync.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 32),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(unidadeRecenteProvider(nome)),
      ),
      data: (unidade) {
        if (unidade == null) return const _SemDados();
        final serieAsync = ref.watch(evolucaoPrecoProvider((nome, unidade)));
        return serieAsync.when(
          loading: () => const AppEsqueleto(linhas: 2, altura: 32),
          error: (_, _) => AppEstadoErro(
            mensagem: AppStrings.erroGenerico,
            onRetentar: () =>
                ref.invalidate(evolucaoPrecoProvider((nome, unidade))),
          ),
          data: (pontos) {
            if (pontos.isEmpty) return const _SemDados();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pontos.length >= 2) ...[
                  SizedBox(
                    height: 120,
                    child: _MiniGraficoPreco(pontos: pontos),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final ponto in pontos)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '${_formatarData(ponto.data)} · '
                      '${formatarReais(ponto.precoCentavos)}',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Mini gráfico de linha da evolução de preço (RF-34, F51), com um ponto por
/// compra: eixo X = ordem cronológica, eixo Y = preço em centavos.
class _MiniGraficoPreco extends StatelessWidget {
  const _MiniGraficoPreco({required this.pontos});

  final List<PontoPreco> pontos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      label: AppStrings.semanticaEvolucaoPreco(
        formatarReais(pontos.last.precoCentavos),
      ),
      excludeSemantics: true,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < pontos.length; i++)
                  FlSpot(i.toDouble(), pontos[i].precoCentavos.toDouble()),
              ],
              isCurved: false,
              color: tema.colorScheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => tema.colorScheme.inverseSurface,
              getTooltipItems: (tocados) => [
                for (final toque in tocados)
                  LineTooltipItem(
                    '${_formatarData(pontos[toque.x.toInt()].data)} · '
                    '${formatarReais(toque.y.round())}',
                    (tema.textTheme.labelMedium ?? const TextStyle()).copyWith(
                      color: tema.colorScheme.onInverseSurface,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SemDados extends StatelessWidget {
  const _SemDados();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Text(
        AppStrings.semDadosAinda,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _percentual(int parte, int total) =>
    total == 0 ? '0%' : '${((parte / total) * 100).round()}%';

String _rotuloNome(String nome) =>
    nome.isEmpty ? nome : '${nome[0].toUpperCase()}${nome.substring(1)}';

String _formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
