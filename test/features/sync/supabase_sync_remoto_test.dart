import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/sync/data/supabase_sync_remoto.dart';

void main() {
  final agora = DateTime.utc(2026, 9, 4, 12);

  test('deve_vencer_local_quando_nao_ha_registro_remoto', () {
    expect(remotoVenceNoLww(null, agora), isFalse);
  });

  test('deve_vencer_remoto_quando_updated_at_maior', () {
    expect(
      remotoVenceNoLww(agora.add(const Duration(seconds: 1)), agora),
      isTrue,
    );
  });

  test('deve_vencer_local_quando_updated_at_remoto_menor', () {
    expect(
      remotoVenceNoLww(agora.subtract(const Duration(seconds: 1)), agora),
      isFalse,
    );
  });

  test('deve_vencer_servidor_quando_updated_at_empata', () {
    // Empate desempata pelo servidor (doc 03 §5).
    expect(remotoVenceNoLww(agora, agora), isTrue);
  });

  test('deve_vencer_local_quando_tombstone_mais_recente_que_edicao_remota', () {
    // Caso-limite 03 §5: remoção offline não deixa o item reaparecer.
    final edicaoRemota = agora.subtract(const Duration(minutes: 5));
    final tombstoneLocal = agora.add(const Duration(seconds: 10));
    expect(remotoVenceNoLww(edicaoRemota, tombstoneLocal), isFalse);
  });

  test('deve_vencer_local_quando_relogio_adiantado', () {
    // Caso-limite 03 §5: dispositivo com relógio adiantado vence até o
    // flush; o servidor aceita o ts do cliente (doc 01 §5).
    final remotoAgora = DateTime.utc(2026, 9, 4, 12);
    final localFuturo = DateTime.utc(2030);
    expect(remotoVenceNoLww(remotoAgora, localFuturo), isFalse);
  });

  test('deve_comparar_instantes_independente_de_fuso_quando_parse', () {
    // 'Z' e '+00:00' representam o mesmo instante → empate.
    final zulu = DateTime.parse('2026-09-04T12:00:00.000Z');
    final offset = DateTime.parse('2026-09-04T12:00:00.000+00:00');
    expect(remotoVenceNoLww(zulu, offset), isTrue);
    expect(remotoVenceNoLww(offset, zulu), isTrue);
  });
}
