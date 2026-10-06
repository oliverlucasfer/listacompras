import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../notificacoes/providers/notificacao_providers.dart';
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
  await _talvezAvisar(
    context,
    ref,
    antes: antes,
    depois: depois,
    orcamento: orcamento,
  );
}

/// Avisa quando **editar o preço** de um item marcado faz o total dos marcados
/// cruzar o orçamento (RF-36): o editor não passa pelo toggle de concluído.
/// Chamar **antes** da escrita, com os itens atuais e o item (preço antigo).
Future<void> talvezAvisarCruzamentoPreco(
  BuildContext context,
  WidgetRef ref,
  String listaId, {
  required List<Item> itens,
  required Item item,
  required int? novoPreco,
}) async {
  if (!item.concluido) return;
  final orcamento = ref
      .read(listaPorIdProvider(listaId))
      .value
      ?.orcamentoCentavos;
  if (orcamento == null) return;
  final antes = totalCarrinho(itens);
  final subtotalAntigo = subtotalMarcado(item);
  final novoSubtotal = novoPreco == null
      ? 0
      : (item.quantidade * novoPreco).round();
  final depois = antes - subtotalAntigo + novoSubtotal;
  await _talvezAvisar(
    context,
    ref,
    antes: antes,
    depois: depois,
    orcamento: orcamento,
  );
}

Future<void> _talvezAvisar(
  BuildContext context,
  WidgetRef ref, {
  required int antes,
  required int depois,
  required int orcamento,
}) async {
  if (!cruzouLimite(antes: antes, depois: depois, orcamento: orcamento)) return;
  if (context.mounted) {
    mostrarSnackBar(
      context,
      context.l10n.orcamentoCruzado(formatarReais(depois)),
    );
  }
  // Notificação local (RF-36, F53-T05): só onde o SO suporta (Android/iOS).
  // Best-effort — uma falha do plugin nunca pode quebrar o fluxo da lista.
  if (plataformaComNotificacao()) {
    try {
      // Fire-and-forget: não bloqueia a escrita do item esperando a inicialização
      // do plugin e o prompt de permissão do SO (RF-36, F53-T05).
      unawaited(
        ref
            .read(notificacaoLocalProvider)
            .mostrar(
              titulo: context.l10n.orcamento,
              corpo: context.l10n.orcamentoCruzado(formatarReais(depois)),
            )
            .catchError((_) {}),
      );
    } catch (_) {
      // silencioso por design: o aviso in-app (SnackBar) já foi mostrado.
    }
  }
}
