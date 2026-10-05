import 'package:flutter/material.dart';

import '../../../core/dominio/quantidade.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../domain/lista_compartilhada.dart';

/// Resultado confirmado da pré-visualização: título editado + itens incluídos.
class PrevisaoReceber {
  const PrevisaoReceber({required this.titulo, required this.itens});

  final String titulo;
  final List<ItemCompartilhado> itens;
}

/// Abre a pré-visualização editável do "Receber lista" (RF-33, spec §6):
/// título editável + incluir/excluir itens. `null` quando cancelado.
Future<PrevisaoReceber?> abrirPrevisaoReceber(
  BuildContext context,
  ListaCompartilhada entrada,
) => showDialog<PrevisaoReceber>(
  context: context,
  builder: (_) => ModalPrevisaoReceber(entrada: entrada),
);

class ModalPrevisaoReceber extends StatefulWidget {
  const ModalPrevisaoReceber({super.key, required this.entrada});

  final ListaCompartilhada entrada;

  @override
  State<ModalPrevisaoReceber> createState() => _ModalPrevisaoReceberState();
}

class _ModalPrevisaoReceberState extends State<ModalPrevisaoReceber> {
  late final _titulo = TextEditingController(text: widget.entrada.titulo);
  late final List<bool> _incluir = List<bool>.filled(
    widget.entrada.itens.length,
    true,
  );

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  List<ItemCompartilhado> get _incluidos => [
    for (var i = 0; i < widget.entrada.itens.length; i++)
      if (_incluir[i]) widget.entrada.itens[i],
  ];

  bool get _podeConfirmar =>
      _titulo.text.trim().isNotEmpty && _incluidos.isNotEmpty;

  void _confirmar() {
    if (!_podeConfirmar) return;
    Navigator.pop(
      context,
      PrevisaoReceber(titulo: _titulo.text.trim(), itens: _incluidos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(context.l10n.importConfirmeItens)),
          IconButton(
            tooltip: context.l10n.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCampoTexto(controller: _titulo, label: context.l10n.nomeDaLista),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.entrada.itens.length,
                itemBuilder: (context, i) {
                  final item = widget.entrada.itens[i];
                  return ListTile(
                    leading: Checkbox(
                      value: _incluir[i],
                      onChanged: (v) =>
                          setState(() => _incluir[i] = v ?? false),
                    ),
                    title: Text(item.nome),
                    trailing: Text(
                      '${formatarQuantidade(item.quantidade)} '
                      '${item.unidade.valor}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelar),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titulo,
          builder: (context, value, child) => AppBotao(
            rotulo: context.l10n.receberConfirmar,
            expandido: false,
            onPressed: _podeConfirmar ? _confirmar : null,
          ),
        ),
      ],
    );
  }
}
