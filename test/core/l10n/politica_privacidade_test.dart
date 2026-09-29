import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/l10n/politica_privacidade.dart';

void main() {
  test('deve_descrever_lite_quando_sem_nuvem', () {
    final texto = politicaPrivacidadePara(AppCapacidades.lite);
    expect(texto, contains('no seu aparelho'));
    expect(texto, contains('voz'));
    expect(texto, isNot(contains('Supabase')));
  });

  test('deve_descrever_colaborativo_quando_com_nuvem', () {
    final texto = politicaPrivacidadePara(AppCapacidades.colaborativo);
    expect(texto, contains('Supabase'));
  });

  test('deve_ter_o_mesmo_contato_nas_duas_versoes', () {
    expect(
      politicaPrivacidadePara(AppCapacidades.lite),
      contains(contatoPrivacidadeEmail),
    );
    expect(
      politicaPrivacidadePara(AppCapacidades.colaborativo),
      contains(contatoPrivacidadeEmail),
    );
  });
}
