import 'package:flutter/material.dart';

/// Placeholder da Tela da Lista — implementação completa na F3-T07.
class TelaListaPlaceholder extends StatelessWidget {
  const TelaListaPlaceholder({super.key, required this.listaId});

  final String listaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Tela da lista: $listaId (F3-T07)')),
    );
  }
}
