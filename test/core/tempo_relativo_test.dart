import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/utils/tempo_relativo.dart';

void main() {
  final agora = DateTime(2026, 9, 4, 12, 0, 0).toUtc();

  DateTime segundosAtras(int s) => agora.subtract(Duration(seconds: s));
  DateTime minutosAtras(int m) => agora.subtract(Duration(minutes: m));
  DateTime horasAtras(int h) => agora.subtract(Duration(hours: h));
  DateTime diasAtras(int d) => agora.subtract(Duration(days: d));

  test('deve_descrever_agora_quando_menos_de_um_minuto', () {
    final t = tempoRelativo(segundosAtras(30), agora: agora);
    expect(t.tipo, TempoRelativoTipo.agora);
  });

  test('deve_descrever_minutos_quando_menos_de_uma_hora', () {
    final t = tempoRelativo(minutosAtras(5), agora: agora);
    expect(t.tipo, TempoRelativoTipo.minutos);
    expect(t.valor, 5);
  });

  test('deve_descrever_horas_quando_menos_de_24_horas', () {
    final t = tempoRelativo(horasAtras(3), agora: agora);
    expect(t.tipo, TempoRelativoTipo.horas);
    expect(t.valor, 3);
  });

  test('deve_descrever_ontem_quando_entre_24_e_48_horas', () {
    final t = tempoRelativo(horasAtras(30), agora: agora);
    expect(t.tipo, TempoRelativoTipo.ontem);
  });

  test('deve_descrever_dias_quando_menos_de_30_dias', () {
    final t = tempoRelativo(diasAtras(5), agora: agora);
    expect(t.tipo, TempoRelativoTipo.dias);
    expect(t.valor, 5);
  });

  test('deve_descrever_meses_quando_menos_de_um_ano', () {
    final t = tempoRelativo(diasAtras(70), agora: agora);
    expect(t.tipo, TempoRelativoTipo.meses);
    expect(t.valor, 2);
  });

  test('deve_descrever_anos_quando_mais_de_um_ano', () {
    final t = tempoRelativo(diasAtras(800), agora: agora);
    expect(t.tipo, TempoRelativoTipo.anos);
    expect(t.valor, 2);
  });
}
