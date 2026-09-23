import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../domain/item.dart';
import '../../../core/dominio/quantidade.dart';
import '../providers/listas_providers.dart';

/// Modal "Adicionar de outra lista" (RF-23): escolhe a origem, marca os
/// pendentes e devolve os selecionados (ou null se cancelado).
Future<List<Item>?> abrirModalAdicionarDeOutraLista(
  BuildContext context, {
  required String listaAtualId,
}) {
  return showDialog<List<Item>>(
    context: context,
    builder: (_) => ModalAdicionarDeOutraLista(listaAtualId: listaAtualId),
  );
}

class ModalAdicionarDeOutraLista extends ConsumerStatefulWidget {
  const ModalAdicionarDeOutraLista({super.key, required this.listaAtualId});

  final String listaAtualId;

  @override
  ConsumerState<ModalAdicionarDeOutraLista> createState() =>
      _ModalAdicionarDeOutraListaState();
}

class _ModalAdicionarDeOutraListaState
    extends ConsumerState<ModalAdicionarDeOutraLista> {
  String? _origemId;
  final _selecionados = <String>{};

  @override
  Widget build(BuildContext context) {
    final listas = (ref.watch(listasComContagemProvider).value ?? const [])
        .where((c) => c.lista.id != widget.listaAtualId)
        .toList();
    if (listas.isEmpty) {
      return AlertDialog(
        title: const Text(AppStrings.adicionarDeOutraLista),
        content: const Text(AppStrings.nenhumaLista),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancelar),
          ),
        ],
      );
    }
    final origemId = _origemId ?? listas.first.lista.id;
    final pendentes =
        (ref.watch(itensDaListaProvider(origemId)).value ?? const <Item>[])
            .where((i) => !i.concluido)
            .toList();
    return AlertDialog(
      title: const Text(AppStrings.adicionarDeOutraLista),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdown<String>(
              label: AppStrings.escolherListaOrigem,
              valor: origemId,
              itens: [
                for (final c in listas)
                  DropdownMenuItem(
                    value: c.lista.id,
                    child: Text(
                      c.lista.arquivadaEm == null
                          ? c.lista.titulo
                          : AppStrings.tituloListaArquivada(c.lista.titulo),
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) {
                  setState(() {
                    _origemId = id;
                    _selecionados.clear();
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (pendentes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(AppStrings.nenhumItemPendenteNaOrigem),
              )
            else ...[
              TextButton(
                onPressed: () => setState(() {
                  if (_selecionados.length == pendentes.length) {
                    _selecionados.clear();
                  } else {
                    _selecionados
                      ..clear()
                      ..addAll(pendentes.map((i) => i.id));
                  }
                }),
                child: const Text(AppStrings.selecionarTodos),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in pendentes)
                        CheckboxListTile(
                          value: _selecionados.contains(item.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selecionados.add(item.id);
                            } else {
                              _selecionados.remove(item.id);
                            }
                          }),
                          title: Text(item.nome),
                          subtitle: Text(
                            '${formatarQuantidade(item.quantidade)} '
                            '${item.unidade.valor}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: AppStrings.adicionarSelecionados,
          expandido: false,
          onPressed: _selecionados.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  pendentes.where((i) => _selecionados.contains(i.id)).toList(),
                ),
        ),
      ],
    );
  }
}
