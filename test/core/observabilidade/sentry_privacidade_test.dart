import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/observabilidade/sentry_privacidade.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('deve_limpar_breadcrumbs_extra_e_contexts_quando_recebe_evento', () {
    // R-13/F21-T02: nenhum payload de Drift/PostgREST pode sair do aparelho —
    // breadcrumbs, `extra` e `contexts` são as vias de conteúdo de item.
    final evento = SentryEvent(
      message: SentryMessage('falha de sync'),
      breadcrumbs: [Breadcrumb(message: 'Arroz')],
      // ignore: deprecated_member_use
      extra: {
        'payload': {'nome': 'Arroz'},
      },
      contexts: Contexts()..['drift'] = {'item': 'Arroz'},
    );

    final resultado = limparDadosDoSentry(evento, Hint());

    expect(resultado, isNotNull);
    expect(resultado!.breadcrumbs, isEmpty);
    // ignore: deprecated_member_use
    expect(resultado.extra, isEmpty);
    expect(resultado.contexts, isEmpty);
  });

  test('deve_preservar_mensagem_quando_limpa_dados_do_evento', () {
    // A limpeza não pode cegar a triagem: tipo/stack/mensagem continuam.
    final evento = SentryEvent(message: SentryMessage('falha de sync'));

    final resultado = limparDadosDoSentry(evento, Hint());

    expect(resultado?.message?.formatted, 'falha de sync');
  });
}
