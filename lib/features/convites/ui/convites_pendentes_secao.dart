import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/providers/listas_providers.dart';
import '../../notificacoes/providers/notificacoes_providers.dart';
import '../domain/convite.dart';
import '../domain/convite_pendente.dart';
import '../providers/convites_providers.dart';

int _diasRestantes(DateTime expiraEm) =>
    expiraEm.difference(DateTime.now()).inDays;

/// Seção "Convites pendentes" no topo do painel Minhas Listas.
class ConvitesPendentesSecao extends ConsumerWidget {
  const ConvitesPendentesSecao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentes =
        ref.watch(meusConvitesPendentesProvider).value ?? const [];
    if (pendentes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            AppStrings.convitesPendentes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final convite in pendentes)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.convitePara(convite.listaTitulo)),
                  const SizedBox(height: AppSpacing.sm),
                  AppChip(rotulo: convite.papelOferecido.rotulo),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.expiraEmDias(_diasRestantes(convite.expiraEm)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppBotao(
                          rotulo: AppStrings.aceitar,
                          expandido: false,
                          onPressed: () => _aceitar(context, ref, convite),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppBotao(
                          rotulo: AppStrings.recusar,
                          variante: AppBotaoVariante.outlined,
                          expandido: false,
                          onPressed: () => _recusar(context, ref, convite),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _aceitar(
    BuildContext context,
    WidgetRef ref,
    ConvitePendente convite,
  ) async {
    try {
      final listaId = await ref
          .read(convitesRepositoryProvider)
          .aceitar(convite.token);
      await ref.read(notificacoesServiceProvider).talvezPedirPermissao();
      ref.invalidate(listasComContagemProvider);
      // O card aceito sairia do painel: sem isto, o cache (não autoDispose)
      // ainda exibiria "Aceitar" ao voltar para Minhas Listas.
      ref.invalidate(meusConvitesPendentesProvider);
      if (context.mounted) context.push('/lista/$listaId');
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }

  Future<void> _recusar(
    BuildContext context,
    WidgetRef ref,
    ConvitePendente convite,
  ) async {
    try {
      await ref.read(convitesRepositoryProvider).recusarConvite(convite.id);
      ref.invalidate(meusConvitesPendentesProvider);
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }
}
