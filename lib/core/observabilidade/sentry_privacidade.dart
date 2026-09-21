import 'package:sentry_flutter/sentry_flutter.dart';

/// Sanitiza o evento antes do envio ao Sentry (doc 07 §4, R-13/F21-T02).
///
/// Remove as vias pelas quais conteúdo de listas/itens poderia sair do
/// dispositivo: `breadcrumbs`, `extra` (Additional Data, frequentemente o
/// payload do Drift/PostgREST) e `contexts`. O tipo, a mensagem e o stack da
/// exceção permanecem — o suficiente para triagem, sem dado de item.
SentryEvent? limparDadosDoSentry(SentryEvent event, Hint hint) {
  event.breadcrumbs?.clear();
  // `extra` é deprecado pelo SDK, mas ainda aceito por integrações e é
  // justamente a via de "Additional Data" que precisa ser limpa.
  // ignore: deprecated_member_use
  event.extra?.clear();
  event.contexts.clear();
  return event;
}
