import 'package:flutter/material.dart';

import 'painel_listas.dart';

/// Painel "Compartilhadas" (doc 05 §6.2, F10): listas em que o usuário é
/// membro (não dono). Aceita convite por código e leva aos membros no
/// long-press (para sair da lista).
class CompartilhadasScreen extends StatelessWidget {
  const CompartilhadasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PainelListas(filtro: FiltroListas.compartilhadas);
}
