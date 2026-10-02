import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/app_politica_privacidade.dart';
import 'package:lista_compras/l10n/app_localizations_pt.dart';

void main() {
  final texto = AppLocalizationsPt().politicaPrivacidadeTexto(
    contatoPrivacidadeEmail,
  );

  test('deve_descrever_app_local_quando_sem_nuvem', () {
    expect(texto, contains('no seu aparelho'));
    expect(texto, contains('voz'));
    expect(texto, isNot(contains('Supabase')));
  });

  test('deve_informar_contato_quando_politica', () {
    expect(texto, contains(contatoPrivacidadeEmail));
  });
}
