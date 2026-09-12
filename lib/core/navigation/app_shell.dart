import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';

/// Casca de navegação (doc 05 §4, F10): `NavigationBar` inferior em telas
/// estreitas e `NavigationRail` em telas largas (Web/desktop). Preserva o
/// estado de cada aba via `StatefulShellRoute.indexedStack`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _icones = [
    (normal: Icons.checklist_outlined, selecionado: Icons.checklist),
    (normal: Icons.group_outlined, selecionado: Icons.group),
    (normal: Icons.settings_outlined, selecionado: Icons.settings),
  ];

  static const _rotulos = [
    AppStrings.abaMinhas,
    AppStrings.compartilhadas,
    AppStrings.configuracoes,
  ];

  @override
  Widget build(BuildContext context) {
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
                for (var i = 0; i < _rotulos.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icones[i].normal),
                    selectedIcon: Icon(_icones[i].selecionado),
                    label: Text(_rotulos[i]),
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
          for (var i = 0; i < _rotulos.length; i++)
            NavigationDestination(
              icon: Icon(_icones[i].normal),
              selectedIcon: Icon(_icones[i].selecionado),
              label: _rotulos[i],
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
