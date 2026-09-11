import 'package:flutter/material.dart';

/// Campo de formulário padronizado com erro inline (doc 15 §3).
class AppCampoTexto extends StatelessWidget {
  const AppCampoTexto({
    super.key,
    this.controller,
    this.label,
    this.erro,
    this.teclado,
    this.senha = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? erro;
  final TextInputType? teclado;
  final bool senha;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: senha,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(labelText: label, errorText: erro),
    );
  }
}
