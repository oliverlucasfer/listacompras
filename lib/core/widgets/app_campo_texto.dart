import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de formulário padronizado com erro inline (doc 15 §3).
class AppCampoTexto extends StatelessWidget {
  const AppCampoTexto({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.erro,
    this.teclado,
    this.senha = false,
    this.sufixo,
    this.autofillHints,
    this.autofocus = false,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.textInputAction,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? erro;
  final TextInputType? teclado;
  final bool senha;
  final Widget? sufixo;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      obscureText: senha,
      autofillHints: autofillHints,
      autofocus: autofocus,
      // O app mostra o próprio contador e permite exceder o limite para avisar
      // em vermelho; o contador/limite embutidos do Flutter ficam fora.
      maxLength: maxLength,
      maxLengthEnforcement: maxLength == null
          ? null
          : MaxLengthEnforcement.none,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: erro,
        counter: maxLength == null ? null : const SizedBox.shrink(),
        suffixIcon: sufixo,
      ),
    );
  }
}
