import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

void main() {
  test('deve_mapear_pt_quando_valor_do_enum', () {
    expect(Unidade.fromValor('pt'), Unidade.pt);
    expect(Unidade.pt.valor, 'pt');
  });

  test('deve_mapear_novas_unidades_quando_valor_do_enum', () {
    expect(Unidade.fromValor('bdj'), Unidade.bandeja);
    expect(Unidade.fromValor('sc'), Unidade.saco);
    expect(Unidade.fromValor('fd'), Unidade.fardo);
    expect(Unidade.fromValor('grf'), Unidade.garrafa);
    expect(Unidade.bandeja.valor, 'bdj');
    expect(Unidade.saco.valor, 'sc');
    expect(Unidade.fardo.valor, 'fd');
    expect(Unidade.garrafa.valor, 'grf');
  });

  test('deve_mapear_unidades_de_porcao_e_embalagem_quando_valor_do_enum', () {
    expect(Unidade.fromValor('ct'), Unidade.cento);
    expect(Unidade.fromValor('cc'), Unidade.cacho);
    expect(Unidade.fromValor('mh'), Unidade.mao);
    expect(Unidade.fromValor('pe'), Unidade.pe);
    expect(Unidade.fromValor('cb'), Unidade.cabeca);
    expect(Unidade.fromValor('mc'), Unidade.maco);
    expect(Unidade.fromValor('rm'), Unidade.ramo);
    expect(Unidade.fromValor('lt'), Unidade.lata);
    expect(Unidade.fromValor('vd'), Unidade.vidro);
    expect(Unidade.fromValor('sch'), Unidade.sache);
    expect(Unidade.fromValor('rl'), Unidade.rolo);
    expect(Unidade.fromValor('br'), Unidade.barra);
    expect(Unidade.fromValor('bsg'), Unidade.bisnaga);
    expect(Unidade.fromValor('gl'), Unidade.galao);
    expect(Unidade.cento.valor, 'ct');
    expect(Unidade.cacho.valor, 'cc');
    expect(Unidade.mao.valor, 'mh');
    expect(Unidade.pe.valor, 'pe');
    expect(Unidade.cabeca.valor, 'cb');
    expect(Unidade.maco.valor, 'mc');
    expect(Unidade.ramo.valor, 'rm');
    expect(Unidade.lata.valor, 'lt');
    expect(Unidade.vidro.valor, 'vd');
    expect(Unidade.sache.valor, 'sch');
    expect(Unidade.rolo.valor, 'rl');
    expect(Unidade.barra.valor, 'br');
    expect(Unidade.bisnaga.valor, 'bsg');
    expect(Unidade.galao.valor, 'gl');
  });
}
