import 'package:flutter/material.dart';

/// Snackbar padronizado, com ação opcional (ex.: desfazer) — doc 15 §3.
void mostrarSnackBar(
  BuildContext context,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        action: rotuloAcao == null
            ? null
            : SnackBarAction(label: rotuloAcao, onPressed: onAcao ?? () {}),
      ),
    );
}
