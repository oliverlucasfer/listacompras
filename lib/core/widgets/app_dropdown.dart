import 'package:flutter/material.dart';

/// Dropdown de formulário padronizado (doc 15 §3, F14-T08): mesma decoração
/// dos demais campos (`AppCampoTexto`), em todos os seletores do app.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.label,
    required this.valor,
    required this.itens,
    required this.onChanged,
    this.compacto = false,
    this.expandido = false,
  });

  final String? label;
  final T valor;
  final List<DropdownMenuItem<T>> itens;
  final ValueChanged<T?> onChanged;
  final bool compacto;

  /// Quando verdadeiro, o botão ocupa toda a largura disponível em vez de
  /// crescer para o item mais largo — evita estouro em colunas estreitas.
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: expandido,
      decoration: InputDecoration(labelText: label, isDense: compacto),
      items: itens,
      onChanged: onChanged,
    );
  }
}
