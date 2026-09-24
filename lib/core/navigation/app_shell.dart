import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_modo.dart';
import '../l10n/app_strings.dart';

/// Casca de navegação (doc 05 §4, F10): `NavigationBar` inferior em telas
/// estreitas e `NavigationRail` em telas largas (Web/desktop). Preserva o
/// estado de cada aba via `StatefulShellRoute.indexedStack`.
///
/// As abas seguem as capacidades (RF-31): no modo Lite (sem colaboração)
/// sobram "Minhas listas" e "Configurações", na mesma ordem dos branches.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaboracao = ref.watch(capacidadesProvider).colaboracao;
    final icones = [
      (normal: Icons.checklist_outlined, selecionado: Icons.checklist),
      if (colaboracao) (normal: Icons.group_outlined, selecionado: Icons.group),
      (normal: Icons.settings_outlined, selecionado: Icons.settings),
    ];
    final rotulos = [
      AppStrings.abaMinhas,
      if (colaboracao) AppStrings.compartilhadas,
      AppStrings.configuracoes,
    ];
    final largura = MediaQuery.sizeOf(context).width;
    if (largura >= 600) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _irPara,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < rotulos.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icones[i].normal),
                    selectedIcon: Icon(icones[i].selecionado),
                    label: Text(rotulos[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _irPara,
        destinations: [
          for (var i = 0; i < rotulos.length; i++)
            NavigationDestination(
              icon: Icon(icones[i].normal),
              selectedIcon: Icon(icones[i].selecionado),
              label: rotulos[i],
            ),
        ],
      ),
    );
  }

  void _irPara(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
