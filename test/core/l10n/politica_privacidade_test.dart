import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

void main() {
  test('deve_descrever_app_local_quando_sem_nuvem', () {
    expect(politicaPrivacidadeTextoLite, contains('no seu aparelho'));
    expect(politicaPrivacidadeTextoLite, contains('voz'));
    expect(politicaPrivacidadeTextoLite, isNot(contains('Supabase')));
  });

  test('deve_informar_contato_quando_politica', () {
    expect(politicaPrivacidadeTextoLite, contains(contatoPrivacidadeEmail));
  });
}
