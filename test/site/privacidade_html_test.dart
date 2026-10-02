import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/app_politica_privacidade.dart';

void main() {
  test('deve_conter_frases_chave_do_lite_na_pagina_publica', () {
    final html = File('site/privacidade.html').readAsStringSync();
    expect(html, contains('no seu aparelho'));
    expect(html, contains('voz'));
    expect(html, contains(contatoPrivacidadeEmail));
  });
}
