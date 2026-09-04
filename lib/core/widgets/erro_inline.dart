import 'package:flutter/material.dart';

/// Estado de erro de formulário inline (wireframe 10 §1: mensagem em
/// vermelho sob o campo correspondente).
class ErroInline extends StatelessWidget {
  const ErroInline({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        mensagem,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
