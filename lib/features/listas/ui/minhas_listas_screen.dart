import 'package:flutter/material.dart';

import 'painel_listas.dart';

/// Painel "Minhas Listas" (doc 05 §6.2, wireframe 10 §2, RF-02): as listas em
/// que o usuário é dono. As compartilhadas ficam em `CompartilhadasScreen`.
class MinhasListasScreen extends StatelessWidget {
  const MinhasListasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PainelListas(filtro: FiltroListas.minhas);
}
