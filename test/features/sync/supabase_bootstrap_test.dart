import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/data/supabase_bootstrap.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../convites/servidor_fake.dart';

class RemotoFake implements SyncRemoto {
  final recebidas = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    recebidas.add(mutacao);
    return const Enviado();
  }
}

/// Cliente HTTP que responde 403 (RLS) no SELECT de `lista_membros` —
/// erro PostgREST imediato, sem retry com backoff do postgrest.
class HttpPapelFalho implements http.Client {
  final pedidos = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    final bytes = utf8.encode(
      jsonEncode({
        'code': 'P0001',
        'message': 'RLS: sem acesso a lista_membros',
        'details': null,
        'hint': null,
      }),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      403,
      request: request,
      headers: {'content-type': 'application/json'},
      contentLength: bytes.length,
    );
  }

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Canal fake que captura os callbacks de PostgresChanges registrados pelo
/// bootstrap, permitindo simular eventos de realtime no teste.
class CanalFake implements RealtimeChannel {
  final callbacks = <void Function(PostgresChangePayload)>[];

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    callbacks.add(callback);
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) => this;

  void enviar(PostgresChangePayload payload) {
    for (final callback in [...callbacks]) {
      callback(payload);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

/// Auth fake — bootstrap acessa apenas `onAuthStateChange` quando nenhuma
/// stream de usuário é injetada.
class AutenticacaoFake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

/// Cliente fake entregando o [CanalFake] — apenas channel/removeChannel
/// são usados pelo bootstrap quando `baixar` e auth são injetados.
class ClienteFake implements SupabaseClient {
  final canal = CanalFake();
  final _auth = AutenticacaoFake();
  final canaisRemovidos = <RealtimeChannel>[];

  @override
  GoTrueClient get auth => _auth;

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) => canal;

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    canaisRemovidos.add(channel);
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

PostgresChangePayload eventoMembro(
  PostgresChangeEvent evento,
  Map<String, Object?> registro, {
  Map<String, Object?>? oldRecord,
}) {
  return PostgresChangePayload(
    schema: 'public',
    table: 'lista_membros',
    commitTimestamp: DateTime.utc(2026, 9, 10, 12),
    eventType: evento,
    newRecord: evento == PostgresChangeEvent.delete ? const {} : registro,
    oldRecord: evento == PostgresChangeEvent.delete
        ? registro
        : (oldRecord ?? {}),
    errors: null,
  );
}

/// Evento de realtime de tabela genérica (whitelist do callback, F7-T07).
PostgresChangePayload eventoTabela(
  String tabela,
  PostgresChangeEvent evento,
  Map<String, Object?> registro,
) {
  return PostgresChangePayload(
    schema: 'public',
    table: tabela,
    commitTimestamp: DateTime.utc(2026, 9, 10, 12),
    eventType: evento,
    newRecord: evento == PostgresChangeEvent.delete ? const {} : registro,
    oldRecord: evento == PostgresChangeEvent.delete ? registro : const {},
    errors: null,
  );
}

void main() {
  late AppDatabase db;
  late ListasRepository repo;
  late RemotoFake remoto;
  final remotos = <String, List<Map<String, Object?>>>{};

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
    remoto = RemotoFake();
    remotos.clear();
  });

  tearDown(() async {
    await db.close();
  });

  SupabaseBootstrap criarComRealtime({
    required ClienteFake cliente,
    Stream<String?>? usuario,
    String? usuarioSalvo,
    PapelRepository? papelRepo,
  }) {
    return SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: remoto,
        checarConexao: () async => true,
      ),
      client: cliente,
      baixar: (tabela) async => remotos[tabela] ?? const [],
      mudancasDeUsuario: usuario,
      papelRepository: papelRepo,
      checarConexao: () async => true,
      lerUsuarioSalvo: () async => usuarioSalvo,
      salvarUsuario: (id) async {},
    );
  }

  SupabaseBootstrap criar({
    Stream<String?>? usuario,
    Stream<List<ConnectivityResult>>? conectividade,
    String? usuarioSalvo,
    String? Function()? usuarioSalvoCapturado,
  }) {
    return SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: remoto,
        checarConexao: () async => true,
      ),
      client: SupabaseClient('http://127.0.0.1:54321', 'test-key'),
      baixar: (tabela) async => remotos[tabela] ?? const [],
      mudancasDeUsuario: usuario,
      conectividade: conectividade,
      checarConexao: () async => true,
      lerUsuarioSalvo: () async => usuarioSalvo,
      salvarUsuario: (id) async => usuarioSalvoCapturado?.call(),
    );
  }

  Map<String, Object?> listaRemota(
    String id, {
    String donoId = 'U1',
    DateTime? atualizado,
  }) {
    return {
      'id': id,
      'titulo': 'Lista $id',
      'dono_id': donoId,
      'created_at': '2026-09-04T12:00:00.000Z',
      'updated_at': (atualizado ?? DateTime.utc(2026, 9, 4, 12))
          .toIso8601String(),
      'deletado_em': null,
    };
  }

  Map<String, Object?> itemRemota(
    String id,
    String listaId, {
    String nome = 'Arroz',
    DateTime? atualizado,
  }) {
    return {
      'id': id,
      'lista_id': listaId,
      'nome': nome,
      'quantidade': 1,
      'unidade': 'un',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-04T12:00:00.000Z',
      'updated_at': (atualizado ?? DateTime.utc(2026, 9, 4, 12))
          .toIso8601String(),
      'deletado_em': null,
    };
  }

  test('deve_baixar_e_popular_cache_quando_primeiro_login', () async {
    remotos
      ..['listas'] = [listaRemota('l1')]
      ..['itens_lista'] = [itemRemota('i1', 'l1')];
    final usuario = StreamController<String?>();
    final bootstrap = criar(usuario: usuario.stream);
    addTearDown(() async {
      await bootstrap.dispose();
      await usuario.close();
    });
    await bootstrap.iniciar();

    usuario.add('U1');
    await pumpEventQueue();

    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l1'))).getSingle();
    expect(lista.titulo, 'Lista l1');
    final item = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i1'))).getSingle();
    expect(item.nome, 'Arroz');
  });

  test('deve_isolar_contas_quando_trocar_usuario', () async {
    remotos['listas'] = [listaRemota('l1', donoId: 'U1')];
    final usuario = StreamController<String?>();
    final bootstrap = criar(usuario: usuario.stream);
    addTearDown(() async {
      await bootstrap.dispose();
      await usuario.close();
    });
    await bootstrap.iniciar();

    usuario.add('U1');
    await pumpEventQueue();
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );

    remotos.clear();
    remotos['listas'] = [listaRemota('l2', donoId: 'U2')];
    usuario.add('U2');
    await pumpEventQueue();

    // Dados de U1 desaparecem; só os de U2 permanecem.
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isEmpty,
    );
    final l2 = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l2'))).getSingle();
    expect(l2.donoId, 'U2');
  });

  test('deve_limpar_cache_e_fila_quando_logout', () async {
    remotos['listas'] = [listaRemota('l1')];
    final usuario = StreamController<String?>();
    final bootstrap = criar(usuario: usuario.stream);
    addTearDown(() async {
      await bootstrap.dispose();
      await usuario.close();
    });
    await bootstrap.iniciar();
    usuario.add('U1');
    await pumpEventQueue();

    usuario.add(null);
    await pumpEventQueue();

    expect(await (db.select(db.listaLocal)).get(), isEmpty);
    expect(await (db.select(db.itemLocal)).get(), isEmpty);
    expect(await (db.select(db.mutacaoPendente)).get(), isEmpty);
  });

  test('deve_preservar_cache_e_fila_quando_mesmo_usuario_no_restart', () async {
    // Checklist 03 §8: fila pendente sobrevive ao restart do app.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'U1');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final bootstrap = criar(usuarioSalvo: 'U1');
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingleOrNull();
    expect(local, isNotNull);
    expect(remoto.recebidas, isNotEmpty); // fila foi drenada, não descartada
  });

  test('deve_re_sincronizar_quando_reconectar', () async {
    final conectividade = StreamController<List<ConnectivityResult>>();
    final usuario = StreamController<String?>();
    final bootstrap = criar(
      usuario: usuario.stream,
      conectividade: conectividade.stream,
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await usuario.close();
      await conectividade.close();
    });
    await bootstrap.iniciar();
    usuario.add('U1');
    await pumpEventQueue();
    expect(await (db.select(db.listaLocal)).get(), isEmpty);

    // Gap de conexão: remoto ganhou uma lista nova → re-sync na reconexão.
    remotos['listas'] = [listaRemota('l1')];
    conectividade.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );
  });

  test('deve_aplicar_remoto_somente_quando_vencer_lww', () async {
    final bootstrap = criar();
    addTearDown(bootstrap.dispose);
    final lista = await repo.criarLista(titulo: 'Local', donoId: 'U1');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    // Remoto mais antigo que a edição local → local vence, nada muda.
    await bootstrap.aplicarRemoto(
      'itens_lista',
      itemRemota(
        item.id,
        lista.id,
        nome: 'Remoto antigo',
        atualizado: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      ),
    );
    var local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.nome, 'Arroz');

    // Remoto mais novo → vence e sobrescreve o Drift.
    await bootstrap.aplicarRemoto(
      'itens_lista',
      itemRemota(
        item.id,
        lista.id,
        nome: 'Remoto novo',
        atualizado: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
    local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.nome, 'Remoto novo');
  });

  test('deve_seguir_resync_quando_carga_de_papel_falhar', () async {
    // Papel é secundário (doc 03 §7): o SELECT de lista_membros falhar
    // não pode abortar o download de listas/itens nem o flush da fila.
    final httpFalho = HttpPapelFalho();
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: httpFalho,
      ),
    );
    remotos
      ..['listas'] = [listaRemota('l1')]
      ..['itens_lista'] = [itemRemota('i1', 'l1')];
    final usuario = StreamController<String?>();
    final bootstrap = SupabaseBootstrap(
      db: db,
      engine: SyncEngine(
        db: db,
        remoto: remoto,
        checarConexao: () async => true,
      ),
      client: SupabaseClient('http://127.0.0.1:54321', 'test-key'),
      baixar: (tabela) async => remotos[tabela] ?? const [],
      mudancasDeUsuario: usuario.stream,
      checarConexao: () async => true,
      lerUsuarioSalvo: () async => null,
      salvarUsuario: (id) async {},
      papelRepository: papelRepo,
    );
    addTearDown(() async {
      await bootstrap.dispose();
      await usuario.close();
    });
    await bootstrap.iniciar();

    usuario.add('U1');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );
    expect(
      await (db.select(db.itemLocal)..where((i) => i.id.equals('i1'))).get(),
      isNotEmpty,
    );
    expect(httpFalho.pedidos, isNotEmpty); // carga de papel foi tentada
    expect(papelRepo.valores, isEmpty); // papéis seguem vazios sem quebrar
  });

  test('deve_limpar_cache_quando_membro_removido_sou_eu', () async {
    // DELETE com REPLICA IDENTITY FULL traz user_id no old_record (08 §7).
    final cliente = ClienteFake();
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: ServidorFake((req) => (200, <Map<String, Object?>>[])),
      ),
    );
    papelRepo.atualizar('l1', Papel.editor);
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(
      cliente: cliente,
      usuarioSalvo: 'U1',
      papelRepo: papelRepo,
    );
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );

    // RLS revogou o acesso: o re-download não traz mais a lista removida.
    remotos.clear();
    cliente.canal.enviar(
      eventoMembro(PostgresChangeEvent.delete, {'id': 'm1', 'user_id': 'U1'}),
    );
    await pumpEventQueue();
    expect(await (db.select(db.listaLocal)).get(), isEmpty);
    expect(await (db.select(db.itemLocal)).get(), isEmpty);
    expect(await (db.select(db.mutacaoPendente)).get(), isEmpty);
    expect(papelRepo.valores, isEmpty); // papel limpo junto com o cache
  });

  test('deve_atualizar_papel_quando_update_meu_membro', () async {
    final cliente = ClienteFake();
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: ServidorFake((req) {
          return (
            200,
            [
              {'lista_id': 'l1', 'papel': 'leitor'},
            ],
          );
        }),
      ),
    );
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(
      cliente: cliente,
      usuarioSalvo: 'U1',
      papelRepo: papelRepo,
    );
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(papelRepo.papelDe('l1'), Papel.leitor);

    cliente.canal.enviar(
      eventoMembro(PostgresChangeEvent.update, {
        'id': 'm1',
        'lista_id': 'l1',
        'user_id': 'U1',
        'papel': 'editor',
      }),
    );
    await pumpEventQueue();

    expect(papelRepo.papelDe('l1'), Papel.editor);
    // A lista segue no cache — só o papel mudou.
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );
  });

  test('deve_ignorar_tabela_desconhecida_sem_quebrar_cadeia', () async {
    // Whitelist (F7-T07): evento de tabela fora do LWW (convites) é
    // ignorado — sem o filtro, o ArgumentError do aplicador envenenaria
    // a cadeia e o evento seguinte nunca seria aplicado.
    final cliente = ClienteFake();
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(cliente: cliente, usuarioSalvo: 'U1');
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();

    cliente.canal.enviar(
      eventoTabela('convites', PostgresChangeEvent.insert, {
        'id': 'c1',
        'lista_id': 'l1',
        'updated_at': '2026-09-10T12:00:00.000Z',
      }),
    );
    await pumpEventQueue();

    // A cadeia segue viva: o próximo evento de `listas` é aplicado.
    cliente.canal.enviar(
      eventoTabela('listas', PostgresChangeEvent.insert, listaRemota('l2')),
    );
    await pumpEventQueue();
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l2'))).get(),
      isNotEmpty,
    );
  });

  test('deve_limpar_cache_e_re_baixar_quando_perder_acesso_local', () async {
    // Belt-and-suspenders do "sair da lista" (F7-T07): o Realtime pode
    // filtrar o DELETE do próprio usuário — a tela força a limpeza local.
    final cliente = ClienteFake();
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(cliente: cliente, usuarioSalvo: 'U1');
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(await (db.select(db.listaLocal)).get(), isNotEmpty);

    // RLS sem acesso: o re-download não traz mais a lista.
    remotos.clear();
    await bootstrap.perderAcessoLocal();

    expect(await (db.select(db.listaLocal)).get(), isEmpty);
    expect(await (db.select(db.itemLocal)).get(), isEmpty);
    expect(await (db.select(db.mutacaoPendente)).get(), isEmpty);
  });

  test('deve_notificar_entrada_quando_insert_de_outro_membro', () async {
    // Feedback "membro entrou" (doc 08 §7, F7-T07): INSERT de outro
    // usuário sinaliza a lista; o papel do próprio usuário não muda.
    final cliente = ClienteFake();
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: ServidorFake((req) {
          return (
            200,
            [
              {'lista_id': 'l1', 'papel': 'leitor'},
            ],
          );
        }),
      ),
    );
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(
      cliente: cliente,
      usuarioSalvo: 'U1',
      papelRepo: papelRepo,
    );
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(papelRepo.papelDe('l1'), Papel.leitor);

    cliente.canal.enviar(
      eventoMembro(PostgresChangeEvent.insert, {
        'id': 'm2',
        'lista_id': 'l1',
        'user_id': 'U2',
        'papel': 'editor',
      }),
    );
    await pumpEventQueue();

    expect(papelRepo.membroEntrou.value, 'l1');
    expect(papelRepo.papelDe('l1'), Papel.leitor);

    papelRepo.consumirEntrada();
    expect(papelRepo.membroEntrou.value, isNull);
  });

  test('deve_ignorar_membros_de_outros_quando_atualizacao', () async {
    final cliente = ClienteFake();
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: ServidorFake((req) {
          return (
            200,
            [
              {'lista_id': 'l1', 'papel': 'leitor'},
            ],
          );
        }),
      ),
    );
    remotos['listas'] = [listaRemota('l1')];
    final bootstrap = criarComRealtime(
      cliente: cliente,
      usuarioSalvo: 'U1',
      papelRepo: papelRepo,
    );
    addTearDown(bootstrap.dispose);
    await bootstrap.iniciar();
    await pumpEventQueue();
    expect(papelRepo.papelDe('l1'), Papel.leitor);

    // UPDATE do papel de outro membro não deve mexer no meu papel.
    cliente.canal.enviar(
      eventoMembro(PostgresChangeEvent.update, {
        'id': 'm2',
        'lista_id': 'l1',
        'user_id': 'U2',
        'papel': 'dono',
      }),
    );
    await pumpEventQueue();

    expect(papelRepo.papelDe('l1'), Papel.leitor);
    expect(
      await (db.select(db.listaLocal)..where((l) => l.id.equals('l1'))).get(),
      isNotEmpty,
    );
  });
}
