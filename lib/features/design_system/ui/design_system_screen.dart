import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_estado_erro.dart';
import '../../../core/widgets/app_estado_vazio.dart';

/// Catálogo de revisão do design system (doc 15 §5, rota /design em debug).
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo('Tokens'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Espaçamento',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final v in const <double>[4, 8, 12, 16, 24, 32, 48])
                        Container(
                          width: v,
                          height: v,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Raios', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (final r in const [
                        AppRadius.sm,
                        AppRadius.md,
                        AppRadius.lg,
                        AppRadius.xl,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(r),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const _Titulo('Botões'),
            AppCard(
              child: Column(
                children: [
                  for (final v in AppBotaoVariante.values) ...[
                    AppBotao(rotulo: v.name, variante: v, onPressed: () {}),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const AppBotao(rotulo: 'Carregando', carregando: true),
                ],
              ),
            ),
            const _Titulo('Banners'),
            const AppCard(
              child: Column(
                children: [
                  AppBanner(tipo: AppBannerTipo.info, mensagem: 'Informação'),
                  SizedBox(height: AppSpacing.sm),
                  AppBanner(tipo: AppBannerTipo.aviso, mensagem: 'Aviso'),
                  SizedBox(height: AppSpacing.sm),
                  AppBanner(tipo: AppBannerTipo.erro, mensagem: 'Erro'),
                  SizedBox(height: AppSpacing.sm),
                  AppBanner(tipo: AppBannerTipo.offline, mensagem: 'Offline'),
                  SizedBox(height: AppSpacing.sm),
                  AppBanner(
                    tipo: AppBannerTipo.leitura,
                    mensagem: 'Somente leitura',
                  ),
                ],
              ),
            ),
            const _Titulo('Chips e estados'),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppChip(rotulo: 'Dono', icone: Icons.person_outline),
                  SizedBox(height: AppSpacing.lg),
                  AppEstadoVazio(
                    titulo: 'Nenhuma lista',
                    descricao: 'Crie sua primeira lista.',
                    acao: AppBotao(rotulo: 'Criar', expandido: false),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  AppEstadoErro(mensagem: 'Falha ao carregar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
