import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/sync_status.dart';
import '../providers/sync_providers.dart';

/// Indicador de sync no topo da tela da lista (doc 03 §6, wireframe
/// 10 §3.2, RF-09): check discreto (Sincronizado), spinner (Sincronizando),
/// contador (Pendente), banner nuvem cortada (Offline) e banner com ação
/// "Tentar novamente" (Erro, após esgotar as 10 tentativas — doc 03 §3).
class IndicadorSync extends ConsumerWidget {
  const IndicadorSync({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? const Sincronizado();
    final cores = Theme.of(context).colorScheme;
    return switch (status) {
      Sincronizado() => _LinhaStatus(
        icone: Icon(Icons.check_circle, size: 14, color: cores.primary),
        texto: AppStrings.syncSincronizado,
      ),
      Sincronizando() => const _LinhaStatus(
        icone: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        texto: AppStrings.syncSincronizando,
      ),
      Pendente(:final total) => _LinhaStatus(
        icone: Icon(
          Icons.cloud_upload_outlined,
          size: 14,
          color: cores.onSurfaceVariant,
        ),
        texto: AppStrings.syncPendentes(total),
      ),
      Offline() => _BannerSync(
        cor: cores.surfaceContainerHighest,
        icone: Icons.cloud_off,
        mensagem: AppStrings.syncSemConexao,
      ),
      ErroSync() => _BannerSync(
        cor: cores.errorContainer,
        icone: Icons.error_outline,
        mensagem: AppStrings.syncErro,
        acao: TextButton(
          onPressed: () => ref.read(syncEngineProvider).reiniciarTentativas(),
          child: const Text(AppStrings.tentarNovamente),
        ),
      ),
    };
  }
}

class _LinhaStatus extends StatelessWidget {
  const _LinhaStatus({required this.icone, required this.texto});

  final Widget icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          icone,
          const SizedBox(width: 4),
          Text(
            texto,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSync extends StatelessWidget {
  const _BannerSync({
    required this.cor,
    required this.icone,
    required this.mensagem,
    this.acao,
  });

  final Color cor;
  final IconData icone;
  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: cor,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(icone, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}
