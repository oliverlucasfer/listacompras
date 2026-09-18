import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

List<String> _linhas(String texto) => texto
    .split('\n')
    .map((linha) => linha.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((linha) => linha.isNotEmpty)
    .toList();

/// Normaliza o HTML para o mesmo formato do texto do app: cada bloco
/// (`h1`, `h2`, `p`, `li`) vira uma linha; `<li>` ganha o marcador `• `.
List<String> _linhasDaPagina(String html) {
  final corpo = html.substring(html.indexOf('<body'), html.indexOf('</body>'));
  final comQuebras = corpo
      .replaceAll(RegExp(r'</(h1|h2|p|li)>'), '\n')
      .replaceAll('<li>', '• ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  return _linhas(comQuebras);
}

void main() {
  test('deve_ter_o_mesmo_texto_do_app_quando_a_politica_for_editada', () {
    final pagina = File('web/privacidade.html');
    expect(
      pagina.existsSync(),
      isTrue,
      reason: 'web/privacidade.html é obrigatória (doc 06 §3.3.2, F19-T01)',
    );

    expect(
      _linhasDaPagina(pagina.readAsStringSync()),
      _linhas(politicaPrivacidadeTexto),
      reason:
          'A página pública e o texto in-app precisam dizer exatamente o mesmo '
          '(edite os dois lados juntos)',
    );
  });
}
