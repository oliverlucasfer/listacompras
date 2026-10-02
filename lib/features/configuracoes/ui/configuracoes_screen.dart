import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/seletor_tema.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_politica_privacidade.dart';
import '../../../core/widgets/seletor_idioma.dart';
import '../../backup/ui/secao_backup.dart';
import '../../tour/tour_controller.dart';

/// Tela Configurações (doc 06 §3, wireframe 10 §5, RF-11): aparência, ordem das
/// categorias, política de privacidade, versão, tour e backup local.
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  /// Reabre o tour ignorando as flags de conclusão (RF-27, F46).
  ///
  /// Os alvos da etapa 1 vivem na home de listas; por isso o botão **navega**
  /// para lá e inicia a etapa 1. A etapa 2 segue o fluxo normal: dispara sozinha
  /// ao abrir uma lista com itens pendentes, se ainda não tiver sido vista.
  void _abrirTour(WidgetRef ref, BuildContext context) {
    final tour = ref.read(tourControllerProvider.notifier);
    context.go('/listas');
    _iniciarEtapa1(tour);
  }

  static const _tentativasEtapa1 = 5;

  /// Tenta iniciar a etapa 1 nos próximos frames: a home precisa montar e
  /// visibilizar os alvos antes de o motor conseguir enfileirá-los.
  void _iniciarEtapa1(TourController tour, [int tentativa = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tour.iniciar(TourEtapa.primeira)) return;
      if (tentativa >= _tentativasEtapa1) return;
      _iniciarEtapa1(tour, tentativa + 1);
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.configuracoes)),
      body: ListView(
        children: [
          const AppCabecalhoSecao(AppStrings.aparencia),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SeletorTema(),
          ),
          AppCabecalhoSecao(context.l10n.idiomaTitulo),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SeletorIdioma(),
          ),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text(AppStrings.ordenarCategorias),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categorias'),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text(AppStrings.orcamentoPorCategoria),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/orcamento-categorias'),
          ),
          const AppCabecalhoSecao(AppStrings.sobre),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(AppStrings.politicaPrivacidade),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrirPoliticaPrivacidade(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppStrings.versao),
            trailing: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) =>
                  Text(snapshot.data?.version ?? AppStrings.semValor),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text(AppStrings.tourAbrir),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirTour(ref, context),
          ),
          const SecaoBackup(),
        ],
      ),
    );
  }
}
