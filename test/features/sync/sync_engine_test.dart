import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/data/supabase_sync_remoto.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';

/// Fake do SyncRemoto (doc 03 §2): registra envios; falha enquanto houver
/// falhas restantes configuradas.
class RemotoFake implements SyncRemoto {
  RemotoFake({this.falhasRestantes = 0});

  int falhasRestantes;
  final recebidas = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    if (falhasRestantes > 0) {
      falhasRestantes--;
      throw http.ClientException('servidor indisponível');
    }
    recebidas.add(mutacao);
    return const Enviado();
  }
}

/// Servidor fake com LWW (doc 03 §5): guarda linhas remotas por id e decide
/// como o SupabaseSyncRemoto faria — empate vence o remoto (servidor).
class RemotoComLwwFake implements SyncRemoto {
  final remotos = <String, Map<String, Object?>>{};
  final enviados = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    final remoto = remotos[mutacao.registroId];
    final atualizadoLocal = DateTime.parse(
      mutacao.payload['updated_at'] as String,
    );
    if (remoto != null &&
        remotoVenceNoLww(
          DateTime.parse(remoto['updated_at'] as String),
          atualizadoLocal,
        )) {
      return RemotoVenceu(remoto);
    }
    remotos[mutacao.registroId] = mutacao.payload;
    enviados.add(mutacao);
    return const Enviado();
  }
}

/// Servidor fake que detecta duplicado (doc 03 §5, RF-10): todo INSERT de
/// item vira `Duplicado` com o registro remoto mesclado informado.
class RemotoDuplicadoFake implements SyncRemoto {
  RemotoDuplicadoFake(this.registroMesclado);

  final Map<String, Object?> registroMesclado;
  final enviados = <MutacaoSync>[];

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    enviados.add(mutacao);
    if (mutacao.tabela == 'itens_lista' && mutacao.operacao == 'INSERT') {
      return Duplicado(registroMesclado);
    }
    return const Enviado();
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

  test('deve_aplicar_categoria_do_remoto_quando_lww_vence_f6t06', () async {
    // Cenário "2 dispositivos" (checklist 03 §8, F6): o dispositivo A editou
    // a categoria (categoria: limpeza). O dispositivo B tinha o item com
    // categoria antiga (frios) e uma mutação pendente mais velha — o remoto
    // vence no LWW e o B adota a categoria do A.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Detergente',
      categoria: CategoriaItem.limpeza,
    );
    // Cópia local divergente no "dispositivo B" com ts mais velho.
    await (db.update(db.itemLocal)..where((i) => i.id.equals(item.id))).write(
      ItemLocalCompanion(
        categoria: const Value('frios'),
        updatedAt: Value(
          DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        ),
      ),
    );

    final agora = DateTime.now().toUtc();
    final remoto = RemotoComLwwFake()
      ..remotos[item.id] = {
        'id': item.id,
        'lista_id': lista.id,
        'nome': 'Detergente',
        'quantidade': 1.0,
        'unidade': 'un',
        'categoria': 'limpeza',
        'concluido': false,
        'ordem': 0,
        'created_at': agora.toIso8601String(),
        'updated_at': agora.add(const Duration(minutes: 2)).toIso8601String(),
        'deletado_em': null,
      };
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.categoria, 'limpeza');
  });

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

  test('deve_aplicar_remoto_e_descartar_mutacao_quando_remoto_vence', () async {
    // Caso-limite 03 §5: edição remota mais recente vence a local.
    final agora = DateTime.now().toUtc();
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.editarItem(item.id, concluido: true);

    final remoto = RemotoComLwwFake()
      ..remotos[item.id] = {
        'id': item.id,
        'lista_id': lista.id,
        'nome': 'Arroz integral',
        'quantidade': 2,
        'unidade': 'kg',
        'concluido': false,
        'ordem': 0,
        'created_at': agora.toIso8601String(),
        'updated_at': agora.add(const Duration(minutes: 5)).toIso8601String(),
        'deletado_em': null,
      };

    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.nome, 'Arroz integral');
    expect(local.quantidade, 2.0);
    expect(local.concluido, false);
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_enviar_tombstone_quando_remocao_local_mais_recente', () async {
    // Caso-limite 03 §5: remoção offline vs edição remota — o tombstone
    // local (mais novo) vence e o item não reaparece.
    final agora = DateTime.now().toUtc();
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final remoto = RemotoComLwwFake()
      ..remotos[item.id] = {
        'id': item.id,
        'lista_id': lista.id,
        'nome': 'Arroz editado remotamente',
        'quantidade': 3,
        'unidade': 'un',
        'concluido': false,
        'ordem': 0,
        'created_at': agora.toIso8601String(),
        'updated_at': agora
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
        'deletado_em': null,
      };

    await repo.removerItem(item.id);

    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    expect(remoto.enviados.map((m) => m.operacao), contains('DELETE_SOFT'));
    expect(remoto.remotos[item.id]!['deletado_em'], isNotNull);
    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.deletadoEm, isNotNull);
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_enviar_edicao_com_relogio_adiantado_e_convergir', () async {
    // Caso-limite 03 §5: relógio adiantado — o dispositivo vence até o
    // flush; o servidor registra o ts do cliente (doc 01 §5).
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final futuro = DateTime.utc(2030).toIso8601String();

    await db
        .into(db.mutacaoPendente)
        .insert(
          MutacaoPendenteCompanion.insert(
            tabela: 'itens_lista',
            operacao: 'UPDATE',
            registroId: item.id,
            payload: jsonEncode({
              'id': item.id,
              'lista_id': lista.id,
              'nome': 'Arroz do futuro',
              'quantidade': 1.0,
              'unidade': 'un',
              'concluido': false,
              'ordem': 0,
              'created_at': futuro,
              'updated_at': futuro,
              'deletado_em': null,
            }),
            tsLocal: DateTime.utc(2030),
            listaId: lista.id,
          ),
        );

    final remoto = RemotoComLwwFake()
      ..remotos[item.id] = {
        'id': item.id,
        'lista_id': lista.id,
        'nome': 'Arroz remoto',
        'quantidade': 1,
        'unidade': 'un',
        'concluido': false,
        'ordem': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'deletado_em': null,
      };

    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    expect(remoto.enviados, isNotEmpty);
    expect(remoto.remotos[item.id]!['nome'], 'Arroz do futuro');
    expect(remoto.remotos[item.id]!['updated_at'], futuro);
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_vencer_servidor_quando_updated_at_empata', () async {
    // Caso-limite 03 §5: empate — desempate pelo timestamp do servidor.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.editarItem(item.id, concluido: true);

    // Ts do remoto exatamente igual ao da mutação local (empate exato).
    final mutacoes = await (db.select(
      db.mutacaoPendente,
    )..where((m) => m.registroId.equals(item.id))).get();
    final tsMutacao =
        (jsonDecode(mutacoes.last.payload) as Map)['updated_at'] as String;

    final remoto = RemotoComLwwFake()
      ..remotos[item.id] = {
        'id': item.id,
        'lista_id': lista.id,
        'nome': 'Arroz do servidor',
        'quantidade': 5,
        'unidade': 'un',
        'concluido': false,
        'ordem': 0,
        'created_at': tsMutacao,
        'updated_at': tsMutacao,
        'deletado_em': null,
      };

    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    // Empate aproximado → servidor vence (remoto aplicado).
    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.nome, 'Arroz do servidor');
    expect(local.quantidade, 5.0);
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_tumbar_local_e_somar_quantidade_quando_duplicado', () async {
    // Caso-limite 03 §5 (RF-10): item duplicado offline vira quantidade
    // somada — a linha local é tombstonada e o remoto absorve a soma.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
    );

    // O SupabaseSyncRemoto mescla no servidor (2 + 3 = 5) e devolve a
    // linha remota mesclada — o fake simula exatamente esse resultado.
    final remoto = RemotoDuplicadoFake({
      'id': 'remoto-arroz',
      'lista_id': lista.id,
      'nome': 'Arroz',
      'quantidade': 5,
      'unidade': 'kg',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-04T12:00:00.000Z',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'deletado_em': null,
    });

    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    // Linha local tombstonada — some da UI.
    final localTumbado = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(localTumbado.deletadoEm, isNotNull);

    // Linha remota aparece localmente com a quantidade somada.
    final remotoLocal = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('remoto-arroz'))).getSingle();
    expect(remotoLocal.quantidade, 5.0);
    expect(remotoLocal.deletadoEm, isNull);

    // Fila vazia e sincronizado.
    expect(await mutacoesNaFila(), 0);
    expect(engine.statusAtual, isA<Sincronizado>());
  });

  test('deve_reportar_falha_quando_fila_passa_de_10_mutacoes', () async {
    // doc 07 §4 evento 1: falha de flush com fila > 10 mutações.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    for (var i = 0; i < 10; i++) {
      await repo.adicionarItem(listaId: lista.id, nome: 'Item $i');
    }
    expect(await mutacoesNaFila(), 11); // lista + 10 itens

    final reportes = <String>[];
    final remoto = RemotoFake(falhasRestantes: 1);
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      reportar: (codigo, contexto) => reportes.add(codigo),
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    expect(reportes, contains('sync_falha_fila_grande'));
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_reportar_relogio_adiantado_quando_ts_passa_de_24h', () async {
    // doc 07 §4 evento 2 (03 §5): divergência grosseira de relógio.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final futuro = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 48))
        .toIso8601String();

    await db
        .into(db.mutacaoPendente)
        .insert(
          MutacaoPendenteCompanion.insert(
            tabela: 'itens_lista',
            operacao: 'UPDATE',
            registroId: item.id,
            payload:
                '{"id":"${item.id}","lista_id":"${lista.id}","nome":"Arroz",'
                '"quantidade":1,"unidade":"un","concluido":false,"ordem":0,'
                '"created_at":"$futuro","updated_at":"$futuro","deletado_em":null}',
            tsLocal: DateTime.now().toUtc(),
            listaId: lista.id,
          ),
        );

    final reportes = <String>[];
    final remoto = RemotoFake();
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      reportar: (codigo, contexto) => reportes.add(codigo),
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await aguardarSincronizado(engine);

    expect(reportes, contains('sync_relogio_adiantado'));
    expect(await mutacoesNaFila(), 0);
  });

  test('deve_reportar_erro_persistente_quando_esgotar_tentativas', () async {
    // doc 07 §4: syncStatus = Erro persistente é evento monitorado.
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final reportes = <String>[];
    final remoto = RemotoFake(falhasRestantes: 100);
    final engine = SyncEngine(
      db: db,
      remoto: remoto,
      checarConexao: () async => true,
      maxTentativas: 1,
      reportar: (codigo, contexto) => reportes.add(codigo),
    );
    addTearDown(engine.dispose);
    await engine.iniciar();
    await engine.status.firstWhere((s) => s is ErroSync);

    expect(engine.statusAtual, isA<ErroSync>());
    expect(reportes, contains('sync_erro_persistente'));
  });
}
