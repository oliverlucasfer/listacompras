import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';
import '../domain/resposta_parse.dart';
import '../providers/ia_providers.dart';

/// Abre o modal de entrada da importação por IA (doc 05 §6.4, wireframe
/// 10 §4.1, RF-06). Retorna os itens extraídos, ou null se cancelado/erro.
/// O resultado segue para o modal de pré-visualização (F4-T02).
Future<RespostaParse?> abrirModalImportarIa(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) {
  return showDialog<RespostaParse>(
    context: context,
    builder: (_) => ModalImportarIa(listaId: listaId),
  );
}

class ModalImportarIa extends ConsumerStatefulWidget {
  const ModalImportarIa({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<ModalImportarIa> createState() => _ModalImportarIaState();
}

class _ModalImportarIaState extends ConsumerState<ModalImportarIa> {
  final _controller = TextEditingController();
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _erro = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _caracteres => _controller.text.length;

  bool get _podeExtrair =>
      !_carregando &&
      _controller.text.trim().isNotEmpty &&
      _caracteres <= maxCaracteresEntradaIa;

  Future<void> _extrair() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await ref
          .read(parseListaClientProvider)
          .parse(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroIa catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.mensagem;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final excedeu = _caracteres > maxCaracteresEntradaIa;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(AppStrings.importarPorIa)),
          IconButton(
            tooltip: AppStrings.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(AppStrings.iaColeOuDigite),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '1kg de arroz, 2 leites, 500g de queijo prato...',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_caracteres/$maxCaracteresEntradaIa',
              style: excedeu
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
          ),
          if (_erro != null) ErroInline(mensagem: _erro!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _podeExtrair ? _extrair : null,
            icon: _carregando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _carregando ? AppStrings.iaLendo : AppStrings.iaExtrairItens,
            ),
          ),
        ],
      ),
    );
  }
}
