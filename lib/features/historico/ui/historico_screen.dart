import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../listas/domain/preco.dart';
import '../domain/ida.dart';
import '../providers/historico_providers.dart';
import 'estatisticas_tab.dart';

/// Aba Histórico de compras (RF-34, F50/F51): resumo das idas finalizadas e a
/// lista de idas, em ordem da mais recente para a mais antiga, além de uma
/// segunda aba com as estatísticas (RF-34, F51).
class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.historico)),
        body: const Column(
          children: [
            _Resumo(),
            Divider(height: 1),
            TabBar(
              tabs: [
                Tab(text: AppStrings.abaIdas),
                Tab(text: AppStrings.estatisticas),
              ],
            ),
            Expanded(
              child: TabBarView(children: [_AbaIdas(), EstatisticasTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbaIdas extends ConsumerWidget {
  const _AbaIdas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idasAsync = ref.watch(idasProvider);
    return idasAsync.when(
      loading: () => const AppEsqueleto(linhas: 4),
      error: (_, _) => AppEstadoErro(
        mensagem: AppStrings.erroGenerico,
        onRetentar: () => ref.invalidate(idasProvider),
      ),
      data: (idas) {
        if (idas.isEmpty) {
          return const AppEstadoVazio(
            icone: Icons.history,
            titulo: AppStrings.historicoVazio,
            descricao: AppStrings.historicoVazioDica,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: idas.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _ItemIda(ida: idas[i]),
        );
      },
    );
  }
}

class _Resumo extends ConsumerWidget {
  const _Resumo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoHistoricoProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _Metrica(
            rotulo: AppStrings.totalGasto,
            valor: resumo.maybeWhen(
              data: (r) => formatarReais(r.totalGeralCentavos),
              orElse: () => AppStrings.semValor,
            ),
          ),
          _Metrica(
            rotulo: AppStrings.ticketMedio,
            valor: resumo.maybeWhen(
              data: (r) => formatarReais(r.ticketMedioCentavos),
              orElse: () => AppStrings.semValor,
            ),
          ),
          _Metrica(
            rotulo: AppStrings.numeroIdas,
            valor: resumo.maybeWhen(
              data: (r) => r.nIdas.toString(),
              orElse: () => AppStrings.semValor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(valor, style: tema.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ItemIda extends StatelessWidget {
  const _ItemIda({required this.ida});

  final Ida ida;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(ida.titulo),
      subtitle: Text(
        '${_formatarData(ida.finalizadaEm)} · ${AppStrings.nItens(ida.itensCount)}',
      ),
      trailing: Text(formatarReais(ida.totalCentavos)),
      onTap: () => context.push('/historico/ida/${ida.id}'),
    );
  }
}

String _formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
