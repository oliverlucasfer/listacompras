import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/supabase_sync_remoto.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../convites/servidor_fake.dart';

const _id = '11111111-1111-2222-3333-444444444444';
const _dono = 'U1';

Map<String, Object?> _payload({required String updatedAt}) => {
  'id': _id,
  'titulo': 'Compras',
  'dono_id': _dono,
  'created_at': '2026-09-04T12:00:00.000Z',
  'updated_at': updatedAt,
  'deletado_em': null,
};

MutacaoSync _mutacao({required String operacao, required String updatedAt}) =>
    MutacaoSync(
      tabela: 'listas',
      operacao: operacao,
      registroId: _id,
      listaId: _id,
      tsLocal: DateTime.utc(2026, 9, 4, 12),
      payload: _payload(updatedAt: updatedAt),
    );

SupabaseSyncRemoto _remotoCom(ServidorFake servidor) => SupabaseSyncRemoto(
  SupabaseClient(
    'http://127.0.0.1:54321',
    'test-key',
    httpClient: servidor,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

void main() {
  test('deve_enviar_insert_quando_nao_ha_registro_remoto', () async {
    // F12-T04: sem linha remota o envio é INSERT puro — nunca upsert, pois o
    // upsert do PostgREST avalia a policy de UPDATE e falhava com 42501.
    final servidor = ServidorFake((req) {
      if (req.method == 'GET') return (200, <Object>[]);
      if (req.method == 'POST') return (201, <Object>[]);
      return (500, {'message': 'inesperado ${req.method} ${req.url.path}'});
    });
    addTearDown(servidor.close);

    final resultado = await _remotoCom(servidor).enviar(
      _mutacao(operacao: 'INSERT', updatedAt: '2026-09-04T13:00:00.000Z'),
    );

    expect(resultado, isA<Enviado>());
    final post = servidor.pedidos.where((p) => p.method == 'POST').toList();
    expect(post, hasLength(1));
    expect(post.single.url.queryParameters.containsKey('on_conflict'), isFalse);
    expect(servidor.pedidos.any((p) => p.method == 'PATCH'), isFalse);
  });

  test(
    'deve_enviar_update_quando_registro_remoto_existe_e_local_vence',
    () async {
      final remota = _payload(updatedAt: '2026-09-04T12:00:00.000Z');
      final servidor = ServidorFake((req) {
        if (req.method == 'GET') return (200, [remota]);
        if (req.method == 'PATCH') return (204, <Object>[]);
        return (500, {'message': 'inesperado ${req.method} ${req.url.path}'});
      });
      addTearDown(servidor.close);

      final resultado = await _remotoCom(servidor).enviar(
        _mutacao(operacao: 'UPDATE', updatedAt: '2026-09-04T13:00:00.000Z'),
      );

      expect(resultado, isA<Enviado>());
      final patch = servidor.pedidos.where((p) => p.method == 'PATCH').toList();
      expect(patch, hasLength(1));
      expect(patch.single.url.queryParameters, containsPair('id', 'eq.$_id'));
      expect(servidor.pedidos.any((p) => p.method == 'POST'), isFalse);
    },
  );

  test('deve_enviar_insert_quando_update_sem_linha_remota', () async {
    // Coalescing pode deixar um UPDATE para um registro criado offline que
    // nunca chegou ao servidor; sem linha remota, o envio precisa ser INSERT.
    final servidor = ServidorFake((req) {
      if (req.method == 'GET') return (200, <Object>[]);
      if (req.method == 'POST') return (201, <Object>[]);
      return (500, {'message': 'inesperado ${req.method} ${req.url.path}'});
    });
    addTearDown(servidor.close);

    final resultado = await _remotoCom(servidor).enviar(
      _mutacao(operacao: 'UPDATE', updatedAt: '2026-09-04T13:00:00.000Z'),
    );

    expect(resultado, isA<Enviado>());
    final post = servidor.pedidos.where((p) => p.method == 'POST').toList();
    expect(post, hasLength(1));
    expect(post.single.url.queryParameters.containsKey('on_conflict'), isFalse);
  });
}
