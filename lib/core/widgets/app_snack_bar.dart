import 'package:flutter/material.dart';

/// Snackbar padronizado, com ação opcional (ex.: desfazer) — doc 15 §3.
/// Duração curta por padrão (F12-T07): 2s sem ação, 3s com ação (o usuário
/// precisa de tempo para o "Desfazer"); [duracao] sobrescreve.
void mostrarSnackBar(
  BuildContext context,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
  Duration? duracao,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final efetiva =
      duracao ??
      (rotuloAcao == null
          ? const Duration(seconds: 2)
          : const Duration(seconds: 3));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: efetiva,
        content: Text(mensagem),
        action: rotuloAcao == null
            ? null
            : SnackBarAction(label: rotuloAcao, onPressed: onAcao ?? () {}),
      ),
    );
}
