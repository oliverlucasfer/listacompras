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
  });

  final String? label;
  final T valor;
  final List<DropdownMenuItem<T>> itens;
  final ValueChanged<T?> onChanged;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: valor,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: compacto,
      ),
      items: itens,
      onChanged: onChanged,
    );
  }
}
