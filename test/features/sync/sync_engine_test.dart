import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';

/// Fake do SyncRemoto (doc 03 §2): registra envios; falha enquanto houver
/// falhas restantes configuradas.
class RemotoFake implements SyncRemoto {
  RemotoFake({this.falhasRestantes = 0});

  int falhasRestantes;
  final recebidas = <MutacaoSync>[];

  @override
  Future<void> enviar(MutacaoSync mutacao) async {
    if (falhasRestantes > 0) {
      falhasRestantes--;
      throw http.ClientException('servidor indisponível');
    }
    recebidas.add(mutacao);
  }
}

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Espera o engine terminar o flush corrente.
  Future<void> aguardarSincronizado(SyncEngine engine) =>
      engine.status.firstWhere((s) => s is Sincronizado);

  Future<int> mutacoesNaFila() async =>
      (await (db.select(db.mutacaoPendente)).get()).length;

  test('deve_esvaziar_fila_ao_reconectar', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    expect(await mutacoesNaFila(), 2);

    var online = false;
    final conectividade = StreamController<List<ConnectivityResult>>();
    final remoto = RemotoFake();
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => online,
      conectividade: conectividade.stream,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();

    expect(engine.statusAtual, isA<Offline>());
    expect(remoto.recebidas, isEmpty);
    expect(await mutacoesNaFila(), 2);

    online = true;
    conectividade.add([ConnectivityResult.wifi]);
    await aguardarSincronizado(engine);

    expect(remoto.recebidas, hasLength(2));
    expect(await mutacoesNaFila(), 0);
  });

  test(
    'deve_enviar_apenas_ultima_mutacao_do_registro_quando_coalescer',
    () async {
      final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
      final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await repo.editarItem(item.id, nome: 'Arroz parboilizado');
      await repo.editarItem(item.id, concluido: true);
      expect(await mutacoesNaFila(), 4); // lista + 3 mutações do item

      final remoto = RemotoFake();
      final engine = SyncEngine(
        db: db,
        remoto: remoto,
        checarConexao: () async => true,
      );
      addTearDown(engine.dispose);
      await engine.iniciar();
      await aguardarSincronizado(engine);

      final doItem = remoto.recebidas
          .where((m) => m.registroId == item.id)
          .toList();
      expect(doItem, hasLength(1));
      expect(doItem.single.operacao, 'UPDATE');
      expect(doItem.single.payload['nome'], 'Arroz parboilizado');
      expect(doItem.single.payload['concluido'], true);
      expect(remoto.recebidas, hasLength(2)); // lista + item coalescido
    },
  );

  test(
    'deve_manter_apenas_delete_soft_quando_criar_e_remover_offline',
    () async {
      final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
      final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await repo.removerItem(item.id);

      final remoto = RemotoFake();
      final engine = SyncEngine(
        db: db,
        remoto: remoto,
        checarConexao: () async => true,
      );
      addTearDown(engine.dispose);
      await engine.iniciar();
      await aguardarSincronizado(engine);

      final doItem = remoto.recebidas
          .where((m) => m.registroId == item.id)
          .toList();
      expect(doItem, hasLength(1));
      expect(doItem.single.operacao, 'DELETE_SOFT');
      expect(doItem.single.payload['deletado_em'], isNotNull);
    },
  );

  test('deve_drenar_por_lista_em_ordem_quando_varias_listas', () async {
    final listaA = await repo.criarLista(titulo: 'A', donoId: 'user-a');
    final listaB = await repo.criarLista(titulo: 'B', donoId: 'user-a');
    final itemA1 = await repo.adicionarItem(listaId: listaA.id, nome: 'A1');
    final itemB1 = await repo.adicionarItem(listaId: listaB.id, nome: 'B1');
    final itemA2 = await repo.adicionarItem(listaId: listaA.id, nome: 'A2');

    final remoto = RemotoFake();
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    final ordem = remoto.recebidas.map((m) => m.registroId).toList();
    expect(ordem, hasLength(5));
    // Grupo da lista A (mais antiga) vem antes: lista, item A1, item A2.
    expect(ordem.indexOf(listaA.id), lessThan(ordem.indexOf(itemA1.id)));
    expect(ordem.indexOf(itemA1.id), lessThan(ordem.indexOf(itemA2.id)));
    // Grupo B depois: lista, item B1.
    expect(ordem.indexOf(itemA2.id), lessThan(ordem.indexOf(listaB.id)));
    expect(ordem.indexOf(listaB.id), lessThan(ordem.indexOf(itemB1.id)));
  });

  test('deve_aplicar_backoff_exponencial_quando_falha', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final remoto = RemotoFake(falhasRestantes: 2);
    final esperas = <Duration>[];
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      esperar: (duracao) async => esperas.add(duracao),
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    expect(esperas, const [Duration(seconds: 1), Duration(seconds: 2)]);
    expect(remoto.recebidas, hasLength(2));
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_entrar_em_erro_e_parar_quando_esgotar_10_tentativas', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final remoto = RemotoFake(falhasRestantes: 100);
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      esperar: (_) async {},
    );
    addTearDown(engine.dispose);
    await engine.iniciar();

    await engine.status.firstWhere((s) => s is ErroSync);

    expect(engine.statusAtual, isA<ErroSync>());
    expect(remoto.recebidas, isEmpty);
    final linhas = await (db.select(db.mutacaoPendente)).get();
    expect(linhas, isNotEmpty);
    expect(linhas.every((l) => l.tentativas == 10), isTrue);
  });

  test('deve_nao_queimar_tentativas_quando_offline', () async {
    var online = false;
    final remoto = RemotoFake();
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => online,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();

    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await pumpEventQueue();

    expect(engine.statusAtual, isA<Offline>());
    expect(remoto.recebidas, isEmpty);
    final linhas = await (db.select(db.mutacaoPendente)).get();
    expect(linhas, isNotEmpty);
    expect(linhas.every((l) => l.tentativas == 0), isTrue);
  });

  test('deve_enviar_e_sincronizar_quando_escrita_com_online', () async {
    final remoto = RemotoFake();
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();

    await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await aguardarSincronizado(engine);

    expect(remoto.recebidas, hasLength(1));
    expect(await mutacoesNaFila(), 0);
    expect(engine.statusAtual, isA<Sincronizado>());
  });

  test('deve_limpar_tentativas_e_enviar_quando_reiniciar_apos_erro', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final remoto = RemotoFake(falhasRestantes: 100);
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      esperar: (_) async {},
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await engine.status.firstWhere((s) => s is ErroSync);

    remoto.falhasRestantes = 0;
    await engine.reiniciarTentativas();

    expect(remoto.recebidas, hasLength(2));
    expect(await mutacoesNaFila(), 0);
    expect(engine.statusAtual, isA<Sincronizado>());
  });
}
