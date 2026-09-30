import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../listas/domain/preco.dart';
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
        return GraficoGastoMensal(dados: ultimos);
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

class _SecaoItensMaisComprados extends ConsumerWidget {
  const _SecaoItensMaisComprados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(itensMaisCompradosProvider);
    return dados.when(
      loading: () => const AppEsqueleto(linhas: 2, altura: 40),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(itensMaisCompradosProvider),
      ),
      data: (itens) {
        if (itens.isEmpty) return const _SemDados();
        return Column(
          children: [
            for (final item in itens)
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
