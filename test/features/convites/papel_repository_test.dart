import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/supabase_bootstrap.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

class _RemotoNenhum implements SyncRemoto {
  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    return const Enviado();
  }
}

SupabaseClient _cliente(ServidorFake servidor) {
  return SupabaseClient(
    'http://127.0.0.1:54321',
    'test-key',
    httpClient: servidor,
  );
}

void main() {
  test('deve_carregar_papeis_quando_bootstrap_carrega', () async {
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (caminho.contains('/lista_membros')) {
        return (
          200,
          [
            {'lista_id': 'l1', 'papel': 'editor'},
            {'lista_id': 'l2', 'papel': 'dono'},
          ],
        );
      }
      if (caminho.contains('/listas') || caminho.contains('/itens_lista')) {
        return (200, []);
      }
      return (500, {'mensagem': 'requisicao inesperada: $caminho'});
    });
    final papelRepository = PapelRepository(_cliente(servidor));
    final db = AppDatabase(NativeDatabase.memory());
    final bootstrap = SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: _RemotoNenhum(),
        checarConexao: () async => true,
      ),
      client: _cliente(servidor),
      papelRepository: papelRepository,
      lerUsuarioSalvo: () async => 'U1',
      salvarUsuario: (id) async {},
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await db.close();
    });

    await bootstrap.iniciar();
    await pumpEventQueue();

    expect(papelRepository.papelDe('l1'), Papel.editor);
    expect(papelRepository.papelDe('l2'), Papel.dono);
  });

  test('deve_limpar_papeis_quando_cache_limpo', () async {
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (caminho.contains('/lista_membros')) {
        return (
          200,
          [
            {'lista_id': 'l1', 'papel': 'editor'},
          ],
        );
      }
      if (caminho.contains('/listas') || caminho.contains('/itens_lista')) {
        return (200, []);
      }
      return (500, {'mensagem': 'requisicao inesperada: $caminho'});
    });
    final papelRepository = PapelRepository(_cliente(servidor));
    final db = AppDatabase(NativeDatabase.memory());
    final usuario = StreamController<String?>();
    final bootstrap = SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: _RemotoNenhum(),
        checarConexao: () async => true,
      ),
      client: _cliente(servidor),
      papelRepository: papelRepository,
      mudancasDeUsuario: usuario.stream,
      lerUsuarioSalvo: () async => null,
      salvarUsuario: (id) async {},
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await db.close();
      await usuario.close();
    });
    usuario.add('U1');
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(papelRepository.papelDe('l1'), Papel.editor);

    usuario.add(null);
    await pumpEventQueue();

    expect(papelRepository.papelDe('l1'), isNull);
  });

  test('deve_pular_carga_quando_papel_repository_ausente', () async {
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (caminho.contains('/lista_membros')) {
        return (500, {'mensagem': 'nao deveria consultar lista_membros'});
      }
      if (caminho.contains('/listas') || caminho.contains('/itens_lista')) {
        return (200, []);
      }
      return (500, {'mensagem': 'requisicao inesperada: $caminho'});
    });
    final db = AppDatabase(NativeDatabase.memory());
    final bootstrap = SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: _RemotoNenhum(),
        checarConexao: () async => true,
      ),
      client: _cliente(servidor),
      papelRepository: null,
      lerUsuarioSalvo: () async => 'U1',
      salvarUsuario: (id) async {},
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await db.close();
    });

    await bootstrap.iniciar();
    await pumpEventQueue();

    expect(await (db.select(db.listaLocal)).get(), isEmpty);
  });

  test('deve_emitir_mudancas_pelo_watch_quando_carregar', () async {
    final servidor = ServidorFake((req) {
      return (
        200,
        [
          {'lista_id': 'l1', 'papel': 'leitor'},
        ],
      );
    });
    final papelRepository = PapelRepository(_cliente(servidor));

    final futuroEventos = papelRepository.watch().take(2).toList();
    await papelRepository.carregar('U1');
    final eventos = await futuroEventos;

    expect(eventos.first, isEmpty);
    expect(eventos.last, {'l1': Papel.leitor});
  });

  test('deve_atualizar_e_remover_papel_localmente', () {
    final papelRepository = PapelRepository(
      _cliente(ServidorFake((req) => (200, []))),
    );

    papelRepository.atualizar('l1', Papel.editor);
    expect(papelRepository.papelDe('l1'), Papel.editor);

    papelRepository.remover('l1');
    expect(papelRepository.papelDe('l1'), isNull);
  });

  test('deve_sinalizar_e_consumir_entrada_quando_outro_membro_entrar', () {
    final papelRepository = PapelRepository(
      _cliente(ServidorFake((req) => (200, []))),
    );

    papelRepository.notificarEntrada('l1');
    expect(papelRepository.membroEntrou.value, 'l1');

    papelRepository.consumirEntrada();
    expect(papelRepository.membroEntrou.value, isNull);

    papelRepository.notificarEntrada('l2');
    papelRepository.limpar();
    expect(papelRepository.membroEntrou.value, isNull);
  });

  test('deve_refletir_papel_na_ui_quando_realtime_muda', () async {
    // papelNaListaStreamProvider assiste o repository — o realtime da
    // F7-T06 (via PapelRepository.atualizar) precisa re-render na UI.
    final papelRepository = PapelRepository(
      _cliente(ServidorFake((req) => (200, <Map<String, Object?>>[]))),
    );
    final container = ProviderContainer(
      overrides: [papelRepositoryProvider.overrideWithValue(papelRepository)],
    );
    addTearDown(container.dispose);

    final eventos = <AsyncValue<Papel?>>[];
    container.listen(
      papelNaListaStreamProvider('l1'),
      (anterior, atual) => eventos.add(atual),
    );
    await pumpEventQueue();
    expect(eventos.last.value, isNull);

    papelRepository.atualizar('l1', Papel.editor);
    await pumpEventQueue();

    expect(eventos.last.value, Papel.editor);
  });
}
