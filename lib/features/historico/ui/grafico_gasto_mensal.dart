import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../listas/domain/preco.dart';
import '../domain/estatisticas.dart';

/// Gráfico de barras do gasto mensal (RF-34, F51): uma barra por mês, com o
/// rótulo `MM/yy` no eixo X e o valor em reais no topo de cada barra.
class GraficoGastoMensal extends StatelessWidget {
  const GraficoGastoMensal({super.key, required this.dados});

  final List<GastoPorMes> dados;

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) {
      return Center(child: Text(context.l10n.semDadosAinda));
    }
    final tema = Theme.of(context);
    final maiorTotal = dados
        .map((d) => d.totalCentavos)
        .reduce((a, b) => a > b ? a : b);
    var indiceMaior = 0;
    for (var i = 1; i < dados.length; i++) {
      if (dados[i].totalCentavos > dados[indiceMaior].totalCentavos) {
        indiceMaior = i;
      }
    }
    final totalPeriodo = dados.fold<int>(0, (s, d) => s + d.totalCentavos);
    final estiloRotulo = tema.textTheme.labelSmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label: context.l10n.semanticaGastoMensal(formatarReais(totalPeriodo)),
      excludeSemantics: true,
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maiorTotal == 0 ? 1 : maiorTotal * 1.2,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < dados.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dados[i].totalCentavos.toDouble(),
                        color: tema.colorScheme.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.sm),
                        ),
                        label: i == indiceMaior
                            ? BarChartRodLabel(
                                text: formatarReais(dados[i].totalCentavos),
                                style: estiloRotulo,
                              )
                            : const BarChartRodLabel(show: false),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= dados.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _rotuloMes(dados[i].mes),
                          style: estiloRotulo,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => tema.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        formatarReais(rod.toY.round()),
                        (tema.textTheme.labelMedium ?? const TextStyle())
                            .copyWith(color: tema.colorScheme.onInverseSurface),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _rotuloMes(DateTime mes) {
  final mesDoisDigitos = mes.month.toString().padLeft(2, '0');
  final anoDoisDigitos = (mes.year % 100).toString().padLeft(2, '0');
  return '$mesDoisDigitos/$anoDoisDigitos';
}
