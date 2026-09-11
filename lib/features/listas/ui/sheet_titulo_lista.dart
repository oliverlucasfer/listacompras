import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_sheet.dart';

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
    return SingleChildScrollView(
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
          const SizedBox(height: AppSpacing.lg),
          AppCampoTexto(
            controller: _controller,
            label: AppStrings.nomeDaLista,
            erro: _erro,
            autofocus: true,
            onSubmitted: _salvar,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppBotao(
            rotulo: widget.rotuloBotao,
            carregando: _salvando,
            onPressed: _salvar,
          ),
        ],
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
  return AppSheet.mostrar<void>(
    context,
    child: SheetTituloLista(
      titulo: titulo,
      rotuloBotao: rotuloBotao,
      valorInicial: valorInicial,
      onSalvar: onSalvar,
    ),
  );
}
