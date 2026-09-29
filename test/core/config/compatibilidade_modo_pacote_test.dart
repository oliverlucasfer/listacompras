import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/core/config/compatibilidade_modo_pacote.dart';

void main() {
  test('deve_ser_compativel_quando_lite_em_pacote_lite', () {
    expect(
      modoCompativelComPacote(
        AppModo.lite,
        'br.com.oliverlucas.listacompras.lite',
      ),
      isTrue,
    );
  });

  test('nao_deve_ser_compativel_quando_colaborativo_em_pacote_lite', () {
    expect(
      modoCompativelComPacote(
        AppModo.colaborativo,
        'br.com.oliverlucas.listacompras.lite',
      ),
      isFalse,
    );
  });

  test('nao_deve_ser_compativel_quando_lite_em_pacote_prod', () {
    expect(
      modoCompativelComPacote(AppModo.lite, 'br.com.oliverlucas.listacompras'),
      isFalse,
    );
  });

  test('deve_ser_compativel_quando_colaborativo_em_pacote_prod', () {
    expect(
      modoCompativelComPacote(
        AppModo.colaborativo,
        'br.com.oliverlucas.listacompras',
      ),
      isTrue,
    );
  });
}
