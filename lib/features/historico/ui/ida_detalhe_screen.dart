import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dominio/quantidade.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';
import '../../listas/domain/preco.dart';
import '../domain/ida.dart';
import '../providers/historico_providers.dart';

/// Detalhe de uma ida finalizada (RF-34, F50): os itens comprados e o total.
class IdaDetalheScreen extends ConsumerWidget {
  const IdaDetalheScreen({super.key, required this.idaId});

  final String idaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idaAsync = ref.watch(idaProvider(idaId));
    final itensAsync = ref.watch(itensDaIdaProvider(idaId));
    return Scaffold(
      appBar: AppBar(
        title: Text(idaAsync.value?.titulo ?? AppStrings.historico),
      ),
      body: idaAsync.when(
        loading: () => const AppEsqueleto(linhas: 4),
        error: (_, _) => AppEstadoErro(
          mensagem: AppStrings.erroGenerico,
          onRetentar: () => ref.invalidate(idaProvider(idaId)),
        ),
        data: (ida) {
          if (ida == null) {
            return const AppEstadoVazio(
              icone: Icons.search_off,
              titulo: AppStrings.listaNaoEncontrada,
            );
          }
          return Column(
            children: [
              Expanded(
                child: itensAsync.when(
                  loading: () => const AppEsqueleto(linhas: 4),
                  error: (_, _) => AppEstadoErro(
                    mensagem: AppStrings.erroGenerico,
                    onRetentar: () => ref.invalidate(itensDaIdaProvider(idaId)),
                  ),
                  data: (itens) => ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: itens.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _Item(daIda: itens[i]),
                  ),
                ),
              ),
              _RodapeTotal(totalCentavos: ida.totalCentavos),
            ],
          );
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.daIda});

  final ItemDaIda daIda;

  @override
  Widget build(BuildContext context) {
    final preco = daIda.precoCentavos;
    return ListTile(
      title: Text(daIda.nome),
      subtitle: Text(
        '${formatarQuantidade(daIda.quantidade)} ${daIda.unidade.valor} · '
        '${daIda.categoria.rotulo}',
      ),
      trailing: Text(
        preco == null ? AppStrings.semValor : formatarReais(preco),
      ),
    );
  }
}

class _RodapeTotal extends StatelessWidget {
  const _RodapeTotal({required this.totalCentavos});

  final int totalCentavos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.totalGasto, style: tema.textTheme.titleMedium),
              Text(
                formatarReais(totalCentavos),
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
