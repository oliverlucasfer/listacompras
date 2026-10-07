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
  ScaffoldMessengerState? messenger,
}) {
  final alvo = messenger ?? ScaffoldMessenger.of(context);
  _exibir(
    alvo,
    mensagem,
    rotuloAcao: rotuloAcao,
    onAcao: onAcao,
    duracao: duracao,
  );
}

/// Variante sem `BuildContext` para callbacks cujo contexto já foi desmontado
/// (ex.: "Desfazer" de um item removido): usa um `ScaffoldMessengerState`
/// capturado antes da lacuna assíncrona.
void mostrarSnackBarComMessenger(
  ScaffoldMessengerState messenger,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
  Duration? duracao,
}) {
  _exibir(
    messenger,
    mensagem,
    rotuloAcao: rotuloAcao,
    onAcao: onAcao,
    duracao: duracao,
  );
}

void _exibir(
  ScaffoldMessengerState alvo,
  String mensagem, {
  String? rotuloAcao,
  VoidCallback? onAcao,
  Duration? duracao,
}) {
  final efetiva =
      duracao ??
      (rotuloAcao == null
          ? const Duration(seconds: 2)
          : const Duration(seconds: 3));
  alvo
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
