import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaves de mensagem de um ARB, ignorando metadados (`@...`).
Set<String> _chaves(String caminho) {
  final mapa = jsonDecode(File(caminho).readAsStringSync());
  return (mapa as Map<String, dynamic>).keys
      .where((chave) => !chave.startsWith('@'))
      .toSet();
}

void main() {
  test('deve_ter_as_mesmas_chaves_nos_tres_arb', () {
    final pt = _chaves('lib/l10n/app_pt.arb');
    final en = _chaves('lib/l10n/app_en.arb');
    final es = _chaves('lib/l10n/app_es.arb');

    expect(en, equals(pt), reason: 'EN tem chaves diferentes do PT');
    expect(es, equals(pt), reason: 'ES tem chaves diferentes do PT');
  });
}
