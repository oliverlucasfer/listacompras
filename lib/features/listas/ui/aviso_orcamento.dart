import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/item.dart';
import '../domain/orcamento.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Mostra o aviso (e dispara a notificação local) quando marcar/desmarcar um
/// item faz o total cruzar o orçamento. Chamar **antes** da escrita, passando
/// a lista de itens atual e o item alvo.
Future<void> talvezAvisarCruzamento(
  BuildContext context,
  WidgetRef ref,
  String listaId, {
  required List<Item> itens,
  required Item item,
  required bool marcando,
}) async {
  final orcamento = ref
      .read(listaPorIdProvider(listaId))
      .value
      ?.orcamentoCentavos;
  if (orcamento == null) return;
  final antes = totalCarrinho(itens);
  final subtotal = subtotalMarcado(item);
  final depois = marcando ? antes + subtotal : antes - subtotal;
  if (!cruzouLimite(antes: antes, depois: depois, orcamento: orcamento)) return;
  // Ponto de extensão (Task 5, RF-36): disparar a notificação local aqui,
  // quando `notificacaoLocalProvider` existir, antes/junto do SnackBar.
  if (context.mounted) {
    mostrarSnackBar(
      context,
      AppStrings.orcamentoCruzado(formatarReais(depois)),
    );
  }
}
