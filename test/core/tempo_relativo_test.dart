import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/utils/tempo_relativo.dart';

void main() {
  final agora = DateTime(2026, 9, 4, 12, 0, 0).toUtc();

  DateTime segundosAtras(int s) => agora.subtract(Duration(seconds: s));
  DateTime minutosAtras(int m) => agora.subtract(Duration(minutes: m));
  DateTime horasAtras(int h) => agora.subtract(Duration(hours: h));
  DateTime diasAtras(int d) => agora.subtract(Duration(days: d));

  test('deve_exibir_agora_quando_menos_de_um_minuto', () {
    expect(tempoRelativo(segundosAtras(30), agora: agora), 'agora');
  });

  test('deve_exibir_minutos_quando_menos_de_uma_hora', () {
    expect(tempoRelativo(minutosAtras(5), agora: agora), 'há 5 min');
  });

  test('deve_exibir_horas_quando_menos_de_24_horas', () {
    expect(tempoRelativo(horasAtras(3), agora: agora), 'há 3 h');
  });

  test('deve_exibir_ontem_quando_entre_24_e_48_horas', () {
    expect(tempoRelativo(horasAtras(30), agora: agora), 'ontem');
  });

  test('deve_exibir_dias_quando_menos_de_30_dias', () {
    expect(tempoRelativo(diasAtras(5), agora: agora), 'há 5 dias');
  });

  test('deve_exibir_meses_quando_menos_de_um_ano', () {
    expect(tempoRelativo(diasAtras(70), agora: agora), 'há 2 meses');
  });

  test('deve_exibir_anos_quando_mais_de_um_ano', () {
    expect(tempoRelativo(diasAtras(800), agora: agora), 'há 2 anos');
  });
}
