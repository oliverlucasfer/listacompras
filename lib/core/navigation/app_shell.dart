import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import 'tour_keys.dart';

/// Casca de navegação (doc 05 §4, F10): `NavigationBar` inferior em telas
/// estreitas e `NavigationRail` em telas largas (Web/desktop). Preserva o
/// estado de cada aba via `StatefulShellRoute.indexedStack`.
///
/// As abas do app local (RF-31) são "Minhas listas", "Histórico" e
/// "Configurações", na mesma ordem dos branches.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icones = [
      (normal: Icons.checklist_outlined, selecionado: Icons.checklist),
      (normal: Icons.history_outlined, selecionado: Icons.history),
      (normal: Icons.settings_outlined, selecionado: Icons.settings),
    ];
    final rotulos = [
      context.l10n.abaMinhas,
      context.l10n.historico,
      context.l10n.configuracoes,
    ];
    // Aba Configurações é o alvo do passo "Configurações e backup" (F46).
    final indiceConfig = rotulos.length - 1;
    GlobalKey? chaveAba(int i) => switch (i) {
      _ when i == indiceConfig => TourKeys.abaConfiguracoes,
      1 => TourKeys.abaHistorico,
      _ => null,
    };
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
                    icon: Icon(icones[i].normal, key: chaveAba(i)),
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
              key: chaveAba(i),
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
