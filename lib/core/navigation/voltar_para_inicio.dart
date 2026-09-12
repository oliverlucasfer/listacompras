import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Destino de "voltar" quando não há pilha (deep link/aceite de convite):
/// o dono volta às listas próprias; o membro, às compartilhadas.
String inicioDaLista({required bool ehDono}) =>
    ehDono ? '/listas' : '/compartilhadas';

/// Seta do AppBar: `null` deixa a padrão (pop) quando há pilha; sem pilha,
/// navega para [inicio].
Widget? botaoVoltarInicio(BuildContext context, String inicio) {
  if (Navigator.of(context).canPop()) return null;
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.go(inicio),
  );
}

/// Trata o voltar do sistema quando não há pilha, indo para [inicio].
class PopScopeVoltarInicio extends StatelessWidget {
  const PopScopeVoltarInicio({
    super.key,
    required this.inicio,
    required this.child,
  });

  final String inicio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(inicio);
      },
      child: child,
    );
  }
}
