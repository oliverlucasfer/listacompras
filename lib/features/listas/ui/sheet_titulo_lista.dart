import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';

/// Bottom sheet de título reutilizável (nova lista / renomear).
class SheetTituloLista extends StatefulWidget {
  const SheetTituloLista({
    super.key,
    required this.titulo,
    required this.rotuloBotao,
    required this.onSalvar,
    this.valorInicial,
  });

  final String titulo;
  final String rotuloBotao;
  final Future<void> Function(String nome) onSalvar;
  final String? valorInicial;

  @override
  State<SheetTituloLista> createState() => _SheetTituloListaState();
}

class _SheetTituloListaState extends State<SheetTituloLista> {
  late final _controller = TextEditingController(text: widget.valorInicial);
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = AppStrings.erroNomeVazio);
      return;
    }
    setState(() {
      _erro = null;
      _salvando = true;
    });
    try {
      await widget.onSalvar(nome);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = AppStrings.erroGenerico;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.cancelar,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _salvar(),
              decoration: InputDecoration(
                labelText: AppStrings.nomeDaLista,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_erro != null) ErroInline(mensagem: _erro!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.rotuloBotao),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> abrirSheetTitulo(
  BuildContext context, {
  required String titulo,
  required String rotuloBotao,
  required Future<void> Function(String nome) onSalvar,
  String? valorInicial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SheetTituloLista(
      titulo: titulo,
      rotuloBotao: rotuloBotao,
      valorInicial: valorInicial,
      onSalvar: onSalvar,
    ),
  );
}
