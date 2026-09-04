import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/supabase_bootstrap.dart';
import 'package:lista_compras/features/sync/data/supabase_sync_remoto.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servidor em memória com as mesmas regras do SupabaseSyncRemoto (LWW do
/// doc 03 §5 + deduplicação RF-10) — permite simular dois dispositivos
/// compartilhando o mesmo servidor sem PostgREST.
class ServidorSyncFake implements SyncRemoto {
  final dados = <String, Map<String, Map<String, Object?>>>{};
  int falhasRestantes = 0;

  List<Map<String, Object?>> linhas(String tabela) =>
      dados.putIfAbsent(tabela, () => {}).values.toList();

  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    if (falhasRestantes > 0) {
      falhasRestantes--;
      throw Exception('servidor indisponível');
    }
    final tabela = dados.putIfAbsent(mutacao.tabela, () => {});
    final remoto = tabela[mutacao.registroId];
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
    if (mutacao.operacao == 'INSERT') {
      final duplicado = _buscarDuplicado(mutacao, tabela);
      if (duplicado != null) {
        final mesclado = mesclarDuplicado(duplicado, mutacao.payload);
        if (mesclado != null) {
          tabela[duplicado['id'] as String] = mesclado;
          return Duplicado(mesclado);
        }
        return Duplicado(duplicado);
      }
    }
    tabela[mutacao.registroId] = mutacao.payload;
    return const Enviado();
  }

  Map<String, Object?>? _buscarDuplicado(
    MutacaoSync mutacao,
    Map<String, Map<String, Object?>> tabela,
  ) {
    if (mutacao.tabela != 'itens_lista') return null;
    final nomeLocal = (mutacao.payload['nome'] as String).toLowerCase();
    for (final linha in tabela.values) {
      if (linha['id'] == mutacao.registroId) continue;
      if (linha['deletado_em'] != null) continue;
      if ((linha['nome'] as String).toLowerCase() == nomeLocal) {
        return linha;
      }
    }
    return null;
  }
}

/// Um "dispositivo": banco local + repositório + engine + bootstrap ligados
/// ao mesmo servidor fake.
class Dispositivo {
  Dispositivo(this.db, this.servidor, {String? usuarioSalvo})
    : repo = ListasRepository(db) {
    engine = SyncEngine(
      db: db,
      remoto: servidor,
      conectividade: conectividade.stream,
      checarConexao: () async => online,
      esperar: (_) async {},
    );
    bootstrap = SupabaseBootstrap(
      db: db,
      engine: engine,
      client: SupabaseClient('http://127.0.0.1:54321', 'test-key'),
      baixar: (tabela) async => servidor.linhas(tabela),
      mudancasDeUsuario: usuario.stream,
      conectividade: conectividade.stream,
      checarConexao: () async => online,
      lerUsuarioSalvo: () async => usuarioSalvo,
      salvarUsuario: (_) async {},
    );
  }

  final AppDatabase db;
  final ServidorSyncFake servidor;
  final ListasRepository repo;
  final conectividade = StreamController<List<ConnectivityResult>>.broadcast();
  final usuario = StreamController<String?>.broadcast();
  late final SyncEngine engine;
  late final SupabaseBootstrap bootstrap;
  final statusVistos = <SyncStatus>[];
  var online = true;

  /// Visão reativa da UI: itens ativos da lista.
  Future<List<String>> nomesAtivos(String listaId) async {
    final linhas = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())).get();
    return linhas.map((i) => i.nome).toList();
  }

  Future<void> iniciar({String? usuario}) async {
    engine.status.listen(statusVistos.add);
    await engine.iniciar();
    await bootstrap.iniciar();
    if (usuario != null) {
      this.usuario.add(usuario);
    }
    await pumpEventQueue();
  }

  Future<void> sincronizarTudo() => bootstrap.sincronizarTudo();

  Future<void> dispose() async {
    await engine.dispose();
    await bootstrap.dispose();
    await usuario.close();
    await conectividade.close();
  }
}

void main() {
  // Checklist de validação da Fase 4 (doc 03 §8) — F4-T09.
  // Dois bancos em memória (dispositivo A e B) — warning do drift é esperado.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase dbA;
  late AppDatabase dbB;
  late ServidorSyncFake servidor;

  setUp(() {
    dbA = AppDatabase(NativeDatabase.memory());
    dbB = AppDatabase(NativeDatabase.memory());
    servidor = ServidorSyncFake();
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  test('checklist_1_deve_acumular_fila_quando_modo_aviao', () async {
    final a = Dispositivo(dbA, servidor);
    addTearDown(a.dispose);
    a.online = false;
    await a.iniciar(usuario: 'U1');

    final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
    final item = await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await a.repo.editarItem(item.id, quantidade: 3);
    await a.repo.editarItem(item.id, concluido: true);
    await a.repo.removerItem(item.id);

    final fila = await (dbA.select(dbA.mutacaoPendente)).get();
    expect(fila, isNotEmpty); // criar/editar/concluir/remover acumularam
    expect(servidor.linhas('listas'), isEmpty); // nada saiu do dispositivo
    expect(servidor.linhas('itens_lista'), isEmpty);
  });

  test(
    'checklist_2_deve_esvaziar_fila_e_refletir_no_servidor_quando_reconectar',
    () async {
      final a = Dispositivo(dbA, servidor);
      addTearDown(a.dispose);
      a.online = false;
      await a.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await a.repo.adicionarItem(
        listaId: lista.id,
        nome: 'arroz', // mesmo nome do item ativo → deduplicado ao sincronizar
        quantidade: 2,
      );

      a.online = true;
      a.conectividade.add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      final itensRemotos = servidor.linhas('itens_lista');
      expect(itensRemotos, hasLength(1)); // sem duplicatas no servidor
      expect(itensRemotos.single['quantidade'], 3); // 1 + 2 somados
      expect(await (dbA.select(dbA.mutacaoPendente)).get(), isEmpty);
      expect(await a.nomesAtivos(lista.id), hasLength(1));
    },
  );

  test(
    'checklist_3_deve_levar_mudancas_ao_outro_dispositivo_quando_re_sincronizar',
    () async {
      final a = Dispositivo(dbA, servidor);
      final b = Dispositivo(dbB, servidor);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.iniciar(usuario: 'U1');
      await b.iniciar(usuario: 'U1');

      // Realtime (< 1s) é representado pela aplicação imediata do remoto
      // (bootstrap.aplicarRemoto); aqui validamos a convergência dos caches.
      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await a.engine.flush();
      await pumpEventQueue();

      await b.sincronizarTudo();
      final listaB = await (dbB.select(
        dbB.listaLocal,
      )..where((l) => l.id.equals(lista.id))).getSingleOrNull();
      expect(listaB, isNotNull);
      expect(await b.nomesAtivos(lista.id), ['Arroz']);

      // B escreve e A re-sincroniza → bidirecional.
      await b.repo.adicionarItem(listaId: lista.id, nome: 'Leite');
      await b.engine.flush();
      await a.sincronizarTudo();
      expect(await a.nomesAtivos(lista.id), containsAll(['Arroz', 'Leite']));
    },
  );

  test(
    'checklist_4_deve_resolver_conflito_por_lww_quando_edicao_simultanea',
    () async {
      final a = Dispositivo(dbA, servidor);
      final b = Dispositivo(dbB, servidor);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.iniciar(usuario: 'U1');
      await b.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      final item = await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await a.engine.flush();
      await b.sincronizarTudo();

      // Edição simultânea offline: A conclui, B renomeia (mais recente).
      await a.repo.editarItem(item.id, concluido: true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await b.repo.editarItem(item.id, nome: 'Arroz integral');
      await a.engine.flush();
      await b.engine.flush();

      // Ambos convergem para a versão vencedora (B) sem erro visível.
      await a.sincronizarTudo();
      final localA = await (dbA.select(
        dbA.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(localA.nome, 'Arroz integral');
      expect(localA.concluido, isFalse);
      expect(a.engine.statusAtual, isA<Sincronizado>());
      expect(b.engine.statusAtual, isA<Sincronizado>());
    },
  );

  test(
    'checklist_5_deve_manter_item_removido_offline_quando_re_sincronizar',
    () async {
      final a = Dispositivo(dbA, servidor);
      final b = Dispositivo(dbB, servidor);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.iniciar(usuario: 'U1');
      await b.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      final item = await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await a.engine.flush();
      await b.sincronizarTudo();
      expect(await b.nomesAtivos(lista.id), ['Arroz']);

      // A remove offline e sincroniza (tombstone vence no servidor).
      await a.repo.removerItem(item.id);
      await a.engine.flush();

      // B re-sincroniza: o item não reaparece em nenhum dispositivo.
      await b.sincronizarTudo();
      await a.sincronizarTudo();
      expect(await a.nomesAtivos(lista.id), isEmpty);
      expect(await b.nomesAtivos(lista.id), isEmpty);
    },
  );

  test(
    'checklist_6_deve_convergir_quando_relogio_adiantado_uma_hora',
    () async {
      final a = Dispositivo(dbA, servidor);
      final b = Dispositivo(dbB, servidor);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.iniciar(usuario: 'U1');
      await b.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      final item = await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await a.engine.flush();
      await b.sincronizarTudo();

      // Relógio de A adiantado 1h: a mutação sai com ts no futuro.
      final futuro = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String();
      await dbA
          .into(dbA.mutacaoPendente)
          .insert(
            MutacaoPendenteCompanion.insert(
              tabela: 'itens_lista',
              operacao: 'UPDATE',
              registroId: item.id,
              payload:
                  '{"id":"${item.id}","lista_id":"${lista.id}",'
                  '"nome":"Arroz do futuro","quantidade":1,"unidade":"un",'
                  '"concluido":false,"ordem":0,"created_at":"$futuro",'
                  '"updated_at":"$futuro","deletado_em":null}',
              tsLocal: DateTime.now().toUtc().add(const Duration(hours: 1)),
              listaId: lista.id,
            ),
          );
      await a.engine.flush();
      expect(servidor.linhas('itens_lista').single['nome'], 'Arroz do futuro');

      // B edita com relógio normal (ts mais antigo) → A vence; convergem.
      await b.repo.editarItem(item.id, nome: 'Arroz do presente');
      await b.engine.flush();
      await a.sincronizarTudo();
      await b.sincronizarTudo();

      final localA = await (dbA.select(
        dbA.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      final localB = await (dbB.select(
        dbB.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(localA.nome, 'Arroz do futuro');
      expect(localB.nome, 'Arroz do futuro');
    },
  );

  test(
    'checklist_7_deve_sobreviver_com_fila_pendente_quando_app_reinicia',
    () async {
      final a = Dispositivo(dbA, servidor);
      a.online = false;
      await a.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      final filaAntes = await (dbA.select(dbA.mutacaoPendente)).get();
      expect(filaAntes, isNotEmpty);
      await a.dispose();

      // App reinicia: novos engine/bootstrap sobre o MESMO banco local.
      final a2 = Dispositivo(dbA, servidor, usuarioSalvo: 'U1');
      addTearDown(a2.dispose);
      await a2.iniciar();

      // A fila sobreviveu e foi drenada; o cache não foi limpo.
      expect(await (dbA.select(dbA.mutacaoPendente)).get(), isEmpty);
      expect(
        await (dbA.select(
          dbA.listaLocal,
        )..where((l) => l.id.equals(lista.id))).getSingleOrNull(),
        isNotNull,
      );
      expect(servidor.linhas('listas'), hasLength(1));
    },
  );

  test(
    'checklist_8_deve_refletir_estados_do_status_quando_sincroniza',
    () async {
      final a = Dispositivo(dbA, servidor);
      addTearDown(a.dispose);
      a.online = false;
      await a.iniciar(usuario: 'U1');

      final lista = await a.repo.criarLista(titulo: 'Compras', donoId: 'U1');
      await a.repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

      // Reconexão com 1 falha → Pendente antes de resolver.
      a.online = true;
      servidor.falhasRestantes = 1;
      a.conectividade.add([ConnectivityResult.none]);
      await pumpEventQueue();
      a.conectividade.add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      final tipos = a.statusVistos.map((s) => s.runtimeType).toSet();
      expect(tipos, containsAll([Offline, Sincronizando, Pendente]));
      expect(a.engine.statusAtual, isA<Sincronizado>());
      // ErroSync (após 10 tentativas) é coberto em sync_engine_test.dart e
      // a renderização dos 5 estados em indicador_sync_test.dart.
    },
  );
}
