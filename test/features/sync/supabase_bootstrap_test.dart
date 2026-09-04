import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/data/supabase_bootstrap.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemotoFake implements SyncRemoto {
  final recebidas = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    recebidas.add(mutacao);
    return const Enviado();
  }
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
}
