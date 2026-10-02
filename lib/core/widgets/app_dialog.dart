import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_botao.dart';

/// Diálogos padronizados (doc 15 §3).
abstract final class AppDialog {
  /// Confirmação de ação destrutiva; retorna `true` apenas se confirmado.
  static Future<bool> confirmarDestrutivo(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    String? confirmar,
    String? cancelar,
  }) async {
    final rotuloConfirmar = confirmar ?? context.l10n.excluir;
    final rotuloCancelar = cancelar ?? context.l10n.cancelar;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(rotuloCancelar),
          ),
          AppBotao(
            rotulo: rotuloConfirmar,
            variante: AppBotaoVariante.destrutivo,
            expandido: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }
}
