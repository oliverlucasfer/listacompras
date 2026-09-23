import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;

/// CP F3-T02 (doc 14): migração v1 criada; CRUD local funciona.
/// O sqlite3 3.x resolve a biblioteca nativa via native assets.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final agora = DateTime.now().toUtc();

  test('deve_inserir_e_ler_lista_quando_crud_valido', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: '11111111-1111-1111-1111-111111111111',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Compras da semana',
            donoId: 'user-a',
          ),
        );

    final lista =
        await (db.select(db.listaLocal)..where(
              (l) => l.id.equals('11111111-1111-1111-1111-111111111111'),
            ))
            .getSingle();
    expect(lista.titulo, 'Compras da semana');
    expect(lista.deletadoEm, isNull);
  });

  test('deve_atualizar_titulo_e_soft_delete_quando_editado', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: '22222222-2222-2222-2222-222222222222',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Antigo',
            donoId: 'user-a',
          ),
        );

    await (db.update(
      db.listaLocal,
    )..where((l) => l.id.equals('22222222-2222-2222-2222-222222222222'))).write(
      ListaLocalCompanion(
        titulo: const Value('Novo'),
        updatedAt: Value(agora.add(const Duration(minutes: 1))),
      ),
    );

    await (db.update(
      db.listaLocal,
    )..where((l) => l.id.equals('22222222-2222-2222-2222-222222222222'))).write(
      ListaLocalCompanion(
        deletadoEm: Value(agora.add(const Duration(minutes: 2))),
      ),
    );

    final lista =
        await (db.select(db.listaLocal)..where(
              (l) => l.id.equals('22222222-2222-2222-2222-222222222222'),
            ))
            .getSingle();
    expect(lista.titulo, 'Novo');
    expect(lista.deletadoEm, isNotNull);
  });

  test(
    'deve_inserir_item_vinculado_e_filtrar_por_lista_quando_consulta',
    () async {
      await db.batch((b) {
        b.insert(
          db.listaLocal,
          ListaLocalCompanion.insert(
            id: '33333333-3333-3333-3333-333333333333',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Lista',
            donoId: 'user-a',
          ),
        );
        b.insert(
          db.itemLocal,
          ItemLocalCompanion.insert(
            id: '44444444-4444-4444-4444-444444444444',
            createdAt: agora,
            updatedAt: agora,
            listaId: '33333333-3333-3333-3333-333333333333',
            nome: 'Arroz',
            quantidade: const Value(0.5),
            unidade: const Value('kg'),
          ),
        );
        b.insert(
          db.itemLocal,
          ItemLocalCompanion.insert(
            id: '55555555-5555-5555-5555-555555555555',
            createdAt: agora,
            updatedAt: agora,
            listaId: '33333333-3333-3333-3333-333333333333',
            nome: 'Leite',
          ),
        );
      });

      final itens =
          await (db.select(db.itemLocal)
                ..where(
                  (i) =>
                      i.listaId.equals('33333333-3333-3333-3333-333333333333'),
                )
                ..orderBy([(i) => OrderingTerm.asc(i.nome)]))
              .get();

      expect(itens.length, 2);
      expect(itens.first.nome, 'Arroz');
      expect(itens.first.quantidade, 0.5);
      expect(itens.first.unidade, 'kg');
      expect(itens.last.concluido, false);
    },
  );

  test('deve_enfileirar_e_remover_mutacao_quando_escrita_pendente', () async {
    await db
        .into(db.mutacaoPendente)
        .insert(
          MutacaoPendenteCompanion.insert(
            tabela: 'itens_lista',
            operacao: 'INSERT',
            registroId: '44444444-4444-4444-4444-444444444444',
            payload: '{"nome":"Arroz","quantidade":0.5,"unidade":"kg"}',
            tsLocal: agora,
            listaId: '33333333-3333-3333-3333-333333333333',
          ),
        );

    final fila = await db.select(db.mutacaoPendente).get();
    expect(fila.length, 1);
    expect(fila.single.tabela, 'itens_lista');
    expect(fila.single.tentativas, 0);

    await (db.delete(
      db.mutacaoPendente,
    )..where((m) => m.id.equals(fila.single.id))).go();
    expect(await db.select(db.mutacaoPendente).get(), isEmpty);
  });

  test('deve_cascata_item_quando_lista_excluida_localmente', () async {
    await db.batch((b) {
      b.insert(
        db.listaLocal,
        ListaLocalCompanion.insert(
          id: '66666666-6666-6666-6666-666666666666',
          createdAt: agora,
          updatedAt: agora,
          titulo: 'Sera apagada',
          donoId: 'user-a',
        ),
      );
      b.insert(
        db.itemLocal,
        ItemLocalCompanion.insert(
          id: '77777777-7777-7777-7777-777777777777',
          createdAt: agora,
          updatedAt: agora,
          listaId: '66666666-6666-6666-6666-666666666666',
          nome: 'Café',
        ),
      );
    });

    await (db.delete(
      db.listaLocal,
    )..where((l) => l.id.equals('66666666-6666-6666-6666-666666666666'))).go();

    expect(
      await (db.select(db.itemLocal)..where(
            (i) => i.listaId.equals('66666666-6666-6666-6666-666666666666'),
          ))
          .get(),
      isEmpty,
    );
  });

  test('deve_gravar_outros_quando_item_sem_categoria_f6t02', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: '99999999-8888-8888-8888-888888888888',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Com categoria',
            donoId: 'user-a',
          ),
        );
    await db
        .into(db.itemLocal)
        .insert(
          ItemLocalCompanion.insert(
            id: '88888888-8888-8888-8888-888888888888',
            createdAt: agora,
            updatedAt: agora,
            listaId: '99999999-8888-8888-8888-888888888888',
            nome: 'Sem categoria',
          ),
        );

    final item =
        await (db.select(db.itemLocal)..where(
              (i) => i.id.equals('88888888-8888-8888-8888-888888888888'),
            ))
            .getSingle();
    expect(item.categoria, 'outros');
  });

  test(
    'deve_migrar_v2_para_v3_preservando_itens_com_outros_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v2 (sem coluna categoria): DDL espelhando o
      // schema v2 gerado, dados gravados e user_version = 2.
      final arquivo = File(
        '${Directory.systemTemp.path}/v2_para_v3_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 2;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('99999999-9999-9999-9999-999999999999', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, concluido, ordem) VALUES "
        "('aaaa9999-9999-9999-9999-999999999999', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'99999999-9999-9999-9999-999999999999', 'Detergente', 2.0, 'un', 0, 3)",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final item =
          await (migrado.select(migrado.itemLocal)..where(
                (i) => i.id.equals('aaaa9999-9999-9999-9999-999999999999'),
              ))
              .getSingle();
      expect(item.nome, 'Detergente');
      expect(item.quantidade, 2.0);
      expect(item.ordem, 3);
      expect(item.categoria, 'outros');
      expect(item.deletadoEm, isNull);
    },
  );

  test(
    'deve_migrar_v3_para_v4_adicionando_preco_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v3 (com categoria, sem preco_centavos): DDL
      // espelhando o schema v3 gerado, dados gravados e user_version = 3.
      final arquivo = File(
        '${Directory.systemTemp.path}/v3_para_v4_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 3;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('99999999-9999-9999-9999-999999999999', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, categoria, concluido, ordem) VALUES "
        "('bbbb9999-9999-9999-9999-999999999999', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'99999999-9999-9999-9999-999999999999', 'Detergente', 2.0, 'un', "
        "'outros', 0, 3)",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final item =
          await (migrado.select(migrado.itemLocal)..where(
                (i) => i.id.equals('bbbb9999-9999-9999-9999-999999999999'),
              ))
              .getSingle();
      expect(item.nome, 'Detergente');
      expect(item.quantidade, 2.0);
      expect(item.ordem, 3);
      expect(item.categoria, 'outros');
      expect(item.precoCentavos, isNull);

      // Escrita/leitura da coluna nova após a migração.
      await (migrado.update(migrado.itemLocal)
            ..where((i) => i.id.equals('bbbb9999-9999-9999-9999-999999999999')))
          .write(const ItemLocalCompanion(precoCentavos: Value(549)));
      final atualizado =
          await (migrado.select(migrado.itemLocal)..where(
                (i) => i.id.equals('bbbb9999-9999-9999-9999-999999999999'),
              ))
              .getSingle();
      expect(atualizado.precoCentavos, 549);
    },
  );

  test(
    'deve_migrar_v4_para_v5_adicionando_arquivada_em_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v4 (com preco_centavos, sem arquivada_em): DDL
      // espelhando o schema v4 gerado, dados gravados e user_version = 4.
      final arquivo = File(
        '${Directory.systemTemp.path}/v4_para_v5_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 4;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('88888888-8888-8888-8888-888888888888', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final lista =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('88888888-8888-8888-8888-888888888888'),
              ))
              .getSingle();
      expect(lista.titulo, 'Antiga');
      expect(lista.arquivadaEm, isNull);

      // Escrita/leitura da coluna nova após a migração.
      final agora = DateTime.utc(2026, 9, 21, 12);
      await (migrado.update(migrado.listaLocal)
            ..where((l) => l.id.equals('88888888-8888-8888-8888-888888888888')))
          .write(ListaLocalCompanion(arquivadaEm: Value(agora)));
      final atualizada =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('88888888-8888-8888-8888-888888888888'),
              ))
              .getSingle();
      expect(atualizada.arquivadaEm?.toUtc(), agora);
    },
  );

  test(
    'deve_migrar_v5_para_v6_adicionando_orcamento_centavos_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v5 (com arquivada_em, sem orcamento_centavos): DDL
      // espelhando o schema v5 gerado, dados gravados e user_version = 5.
      final arquivo = File(
        '${Directory.systemTemp.path}/v5_para_v6_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          arquivada_em TEXT NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 5;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('99999999-9999-9999-9999-999999999999', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final lista =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('99999999-9999-9999-9999-999999999999'),
              ))
              .getSingle();
      expect(lista.titulo, 'Antiga');
      expect(lista.orcamentoCentavos, isNull);

      // Escrita/leitura da coluna nova após a migração.
      await (migrado.update(migrado.listaLocal)
            ..where((l) => l.id.equals('99999999-9999-9999-9999-999999999999')))
          .write(const ListaLocalCompanion(orcamentoCentavos: Value(25000)));
      final atualizada =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('99999999-9999-9999-9999-999999999999'),
              ))
              .getSingle();
      expect(atualizada.orcamentoCentavos, 25000);
    },
  );

  test('deve_criar_historico_preco_quando_migrar_v6_para_v7', () async {
    // Banco real na versão v6 (com orcamento_centavos, sem
    // historico_preco_local): DDL espelhando o schema v6 gerado, dados
    // gravados e user_version = 6.
    final arquivo = File(
      '${Directory.systemTemp.path}/v6_para_v7_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (arquivo.existsSync()) arquivo.deleteSync();
    });

    final antigo = sq3.sqlite3.open(arquivo.path);
    antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          arquivada_em TEXT NULL,
          orcamento_centavos INTEGER NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        PRAGMA user_version = 6;
      ''');
    antigo.execute(
      "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
      "VALUES ('77777777-7777-7777-7777-777777777777', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
      "'Antiga', 'user-a')",
    );
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    final lista =
        await (migrado.select(migrado.listaLocal)..where(
              (l) => l.id.equals('77777777-7777-7777-7777-777777777777'),
            ))
            .getSingle();
    expect(lista.titulo, 'Antiga');

    // Tabela nova existe e aceita escrita/leitura após a migração.
    final quando = DateTime.utc(2026, 9, 20, 12);
    await migrado
        .into(migrado.historicoPrecoLocal)
        .insert(
          HistoricoPrecoLocalCompanion.insert(
            nomeNormalizado: 'cafe',
            precoCentavos: 1850,
            unidade: 'pacote',
            registradoEm: quando,
          ),
        );
    final hist = await migrado.select(migrado.historicoPrecoLocal).getSingle();
    expect(hist.nomeNormalizado, 'cafe');
    expect(hist.precoCentavos, 1850);
    expect(hist.unidade, 'pacote');
    expect(hist.registradoEm.toUtc(), quando);
  });

  test('deve_rejeitar_quantidade_zero_quando_check_local_v8', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'aaaaaaaa-0000-0000-0000-000000000001',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Lista',
            donoId: 'user-a',
          ),
        );
    expect(
      () => db
          .into(db.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'aaaaaaaa-0000-0000-0000-000000000002',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'aaaaaaaa-0000-0000-0000-000000000001',
              nome: 'Zero',
              quantidade: const Value(0),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('deve_rejeitar_unidade_fora_do_enum_quando_check_local_v8', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'bbbbbbbb-0000-0000-0000-000000000001',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Lista',
            donoId: 'user-a',
          ),
        );
    expect(
      () => db
          .into(db.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'bbbbbbbb-0000-0000-0000-000000000002',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'bbbbbbbb-0000-0000-0000-000000000001',
              nome: 'Estranho',
              unidade: const Value('litros'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('deve_criar_indice_uq_item_ativo_quando_instalacao_nova', () async {
    final indice = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'uq_item_ativo'",
        )
        .get();
    expect(indice, isNotEmpty);
  });

  test('deve_deduplicar_e_criar_indice_quando_migrar_v7_para_v8', () async {
    final arquivo = File(
      '${Directory.systemTemp.path}/v7_para_v8_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (arquivo.existsSync()) arquivo.deleteSync();
    });

    final antigo = sq3.sqlite3.open(arquivo.path);
    antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          arquivada_em TEXT NULL,
          orcamento_centavos INTEGER NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        PRAGMA user_version = 7;
      ''');
    antigo.execute(
      "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
      "VALUES ('cccccccc-0000-0000-0000-000000000001', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
      "'Antiga', 'user-a')",
    );
    // Duplicatas ativas: 'Arroz' duas vezes (mesma lista, mesmo nome).
    antigo.execute(
      "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
      "quantidade, unidade, categoria, concluido, ordem) VALUES "
      "('dddddddd-0000-0000-0000-000000000001', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-02T00:00:00.000000Z', "
      "'cccccccc-0000-0000-0000-000000000001', 'Arroz', 1.0, 'kg', 'mercearia', 0, 0)",
    );
    antigo.execute(
      "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
      "quantidade, unidade, categoria, concluido, ordem) VALUES "
      "('dddddddd-0000-0000-0000-000000000002', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
      "'cccccccc-0000-0000-0000-000000000001', 'arroz', 2.0, 'kg', 'mercearia', 0, 1)",
    );
    // A duplicata mais ANTIGA (...002) tem DUAS mutações pendentes e a mais
    // NOVA (...001) tem uma: a prioridade por fila (COUNT) mantém ...002,
    // sobrepondo o `updated_at` mais recente de ...001.
    antigo.execute(
      "INSERT INTO mutacao_pendente (tabela, operacao, registro_id, payload, "
      "ts_local, lista_id) VALUES ('itens_lista', 'INSERT', "
      "'dddddddd-0000-0000-0000-000000000002', '{}', "
      "'2026-01-01T00:00:00.000000Z', 'cccccccc-0000-0000-0000-000000000001')",
    );
    antigo.execute(
      "INSERT INTO mutacao_pendente (tabela, operacao, registro_id, payload, "
      "ts_local, lista_id) VALUES ('itens_lista', 'UPDATE', "
      "'dddddddd-0000-0000-0000-000000000002', '{}', "
      "'2026-01-01T01:00:00.000000Z', 'cccccccc-0000-0000-0000-000000000001')",
    );
    // A perdedora também tem fila: ela precisa ser apagada junto do item.
    antigo.execute(
      "INSERT INTO mutacao_pendente (tabela, operacao, registro_id, payload, "
      "ts_local, lista_id) VALUES ('itens_lista', 'INSERT', "
      "'dddddddd-0000-0000-0000-000000000001', '{}', "
      "'2026-01-02T00:00:00.000000Z', 'cccccccc-0000-0000-0000-000000000001')",
    );
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    final itens = await migrado.select(migrado.itemLocal).get();
    expect(itens.length, 1);
    expect(itens.single.id, 'dddddddd-0000-0000-0000-000000000002');

    final fila = await migrado.select(migrado.mutacaoPendente).get();
    expect(fila.length, 2);
    expect(fila.map((m) => m.registroId).toSet(), {
      'dddddddd-0000-0000-0000-000000000002',
    });

    final indice = await migrado
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'uq_item_ativo'",
        )
        .get();
    expect(indice, isNotEmpty);

    // Caminho MIGRADO: `alterTable` precisa reaplicar os `customConstraints`
    // (senão instalações antigas perderiam as CHECKs silenciosamente).
    expect(
      () => migrado
          .into(migrado.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'dddddddd-0000-0000-0000-000000000003',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'cccccccc-0000-0000-0000-000000000001',
              nome: 'Zero',
              quantidade: const Value(0),
            ),
          ),
      throwsA(isA<Exception>()),
    );
    expect(
      () => migrado
          .into(migrado.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'dddddddd-0000-0000-0000-000000000004',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'cccccccc-0000-0000-0000-000000000001',
              nome: 'Estranho',
              unidade: const Value('litros'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
