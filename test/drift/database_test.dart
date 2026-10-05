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
    // Linhas legadas de `mutacao_pendente` (schema v7): inertes para o dedup,
    // que agora decide só por `updated_at` — ...001 (mais recente) vence — e
    // a tabela precisa ser removida no upgrade v10 → v11.
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
    // A vencedora também tinha fila (legado inerte para o dedup); a tabela
    // inteira é removida no upgrade v10 → v11.
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
    expect(itens.single.id, 'dddddddd-0000-0000-0000-000000000001');

    final tabelas = await migrado
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(
      tabelas.map((r) => r.data['name']),
      isNot(contains('mutacao_pendente')),
    );

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

  test(
    'deve_rejeitar_quantidade_acima_do_teto_quando_check_local_v9',
    () async {
      await db
          .into(db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: 'eeeeeeee-0000-0000-0000-000000000001',
              createdAt: agora,
              updatedAt: agora,
              titulo: 'Lista teto',
              donoId: 'user-a',
            ),
          );
      expect(
        () => db
            .into(db.itemLocal)
            .insert(
              ItemLocalCompanion.insert(
                id: 'eeeeeeee-0000-0000-0000-000000000002',
                createdAt: agora,
                updatedAt: agora,
                listaId: 'eeeeeeee-0000-0000-0000-000000000001',
                nome: 'Acima do teto',
                quantidade: const Value(1000001),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'deve_migrar_v8_para_v9_repondo_check_de_teto_quando_abrir_banco_antigo',
    () async {
      // Banco real na versão v8 (com as barreiras da F39, sem o teto de
      // quantidade): DDL espelhando o schema v8 gerado + índice manual
      // `uq_item_ativo`, dados gravados e user_version = 8.
      final arquivo = File(
        '${Directory.systemTemp.path}/v8_para_v9_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
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
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 8;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('ffffffff-0000-0000-0000-000000000001', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga v8', 'user-a')",
      );
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, categoria, concluido, ordem) VALUES "
        "('ffffffff-0000-0000-0000-000000000002', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'ffffffff-0000-0000-0000-000000000001', 'Detergente', 2.0, 'un', "
        "'outros', 0, 3)",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final item =
          await (migrado.select(migrado.itemLocal)..where(
                (i) => i.id.equals('ffffffff-0000-0000-0000-000000000002'),
              ))
              .getSingle();
      expect(item.nome, 'Detergente');
      expect(item.quantidade, 2.0);

      // O índice manual precisa sobreviver à recriação da tabela.
      final indice = await migrado
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND name = 'uq_item_ativo'",
          )
          .get();
      expect(indice, isNotEmpty);

      // O CHECK de teto passa a valer no banco migrado.
      expect(
        () => migrado
            .into(migrado.itemLocal)
            .insert(
              ItemLocalCompanion.insert(
                id: 'ffffffff-0000-0000-0000-000000000003',
                createdAt: agora,
                updatedAt: agora,
                listaId: 'ffffffff-0000-0000-0000-000000000001',
                nome: 'Acima do teto',
                quantidade: const Value(1000001),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'deve_sanitizar_quantidade_acima_do_teto_quando_migrar_base_legada_v7',
    () async {
      // Banco real na versão v7 (sem CHECKs locais): `quantidade` é entrada do
      // usuário e uma base antiga pode ter valor acima do teto. O upgrade
      // precisa abrir e clampar o valor no teto (G-29, F43-T08) — os passos
      // `de < 8` e `de < 9` recriam `item_local` com a definição atual.
      final arquivo = File(
        '${Directory.systemTemp.path}/v7_teto_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
        "VALUES ('eeeeeeee-0000-0000-0000-000000000011', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Legada v7', 'user-a')",
      );
      // Valor legado acima do teto, sem CHECK no v7.
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, categoria, concluido, ordem) VALUES "
        "('eeeeeeee-0000-0000-0000-000000000012', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'eeeeeeee-0000-0000-0000-000000000011', 'Legado', 5000000.0, 'un', "
        "'outros', 0, 0)",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final item =
          await (migrado.select(migrado.itemLocal)..where(
                (i) => i.id.equals('eeeeeeee-0000-0000-0000-000000000012'),
              ))
              .getSingle();
      expect(item.nome, 'Legado');
      expect(item.quantidade, 1000000);

      final indice = await migrado
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND name = 'uq_item_ativo'",
          )
          .get();
      expect(indice, isNotEmpty);
    },
  );

  test('deve_criar_tabelas_de_ida_quando_migrar_v11_para_v12', () async {
    // Banco real na versão v11 (sem ida_compra/item_ida e sem
    // mutacao_pendente): DDL espelhando o schema v11 gerado + índice manual
    // `uq_item_ativo`, dados gravados e user_version = 11.
    final arquivo = File(
      '${Directory.systemTemp.path}/v11_para_v12_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (quantidade <= 1000000),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 11;
      ''');
    antigo.execute(
      "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
      "VALUES ('dddddddd-0000-0000-0000-000000000001', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
      "'Antiga v11', 'user-a')",
    );
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    final lista =
        await (migrado.select(migrado.listaLocal)..where(
              (l) => l.id.equals('dddddddd-0000-0000-0000-000000000001'),
            ))
            .getSingle();
    expect(lista.titulo, 'Antiga v11');

    // Tabelas novas existem e aceitam escrita/leitura após a migração.
    await migrado
        .into(migrado.idaCompra)
        .insert(
          IdaCompraCompanion.insert(
            id: 'dddddddd-0000-0000-0000-000000000010',
            titulo: 'Semana',
            finalizadaEm: DateTime.utc(2026, 9, 30),
          ),
        );
    await migrado
        .into(migrado.itemIda)
        .insert(
          ItemIdaCompanion.insert(
            id: 'dddddddd-0000-0000-0000-000000000011',
            idaId: 'dddddddd-0000-0000-0000-000000000010',
            nome: 'Arroz',
            precoCentavos: const Value(549),
          ),
        );
    final itens = await migrado.select(migrado.itemIda).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 1.0);

    // Excluir a ida apaga os itens (FK ON DELETE CASCADE).
    await (migrado.delete(
      migrado.idaCompra,
    )..where((t) => t.id.equals('dddddddd-0000-0000-0000-000000000010'))).go();
    expect(await migrado.select(migrado.itemIda).get(), isEmpty);
  });

  test('deve_adicionar_mercado_quando_migrar_v12_para_v13', () async {
    // Banco real na versão v12 (com ida_compra/item_ida, sem a coluna
    // `mercado`): DDL espelhando o schema v12 gerado + índice manual
    // `uq_item_ativo`, dados gravados e user_version = 12.
    final arquivo = File(
      '${Directory.systemTemp.path}/v12_para_v13_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (quantidade <= 1000000),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        CREATE TABLE ida_compra (
          id TEXT NOT NULL PRIMARY KEY,
          lista_id TEXT NULL,
          titulo TEXT NOT NULL,
          finalizada_em TEXT NOT NULL,
          total_centavos INTEGER NOT NULL DEFAULT 0,
          itens_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE item_ida (
          id TEXT NOT NULL PRIMARY KEY,
          ida_id TEXT NOT NULL REFERENCES ida_compra (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios','congelados',
            'padaria','bebidas','pet','limpeza','higiene','outros'))
        );
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 12;
      ''');
    antigo.execute(
      "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
      "VALUES ('cccccccc-0000-0000-0000-000000000001', "
      "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
      "'Antiga v12', 'user-a')",
    );
    antigo.execute(
      "INSERT INTO ida_compra (id, lista_id, titulo, finalizada_em, "
      "total_centavos, itens_count) VALUES "
      "('cccccccc-0000-0000-0000-000000000010', NULL, 'Antiga v12', "
      "'2026-01-01T00:00:00.000000Z', 1000, 1)",
    );
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    // Linha existente migra com `mercado` nulo (coluna aditiva).
    final idaAntiga =
        await (migrado.select(migrado.idaCompra)..where(
              (t) => t.id.equals('cccccccc-0000-0000-0000-000000000010'),
            ))
            .getSingle();
    expect(idaAntiga.titulo, 'Antiga v12');
    expect(idaAntiga.mercado, isNull);

    // Escrita/leitura da coluna nova após a migração.
    await (migrado.update(migrado.idaCompra)
          ..where((t) => t.id.equals('cccccccc-0000-0000-0000-000000000010')))
        .write(const IdaCompraCompanion(mercado: Value('Mercado B')));
    final atualizada =
        await (migrado.select(migrado.idaCompra)..where(
              (t) => t.id.equals('cccccccc-0000-0000-0000-000000000010'),
            ))
            .getSingle();
    expect(atualizada.mercado, 'Mercado B');
  });

  test(
    'deve_criar_tabela_orcamento_categoria_quando_migrar_v13_para_v14',
    () async {
      // Banco real na versão v13 (com ida_compra.mercado, sem a tabela
      // `orcamento_categoria`): DDL espelhando o schema v13 gerado + índice
      // manual `uq_item_ativo`, dados gravados e user_version = 13.
      final arquivo = File(
        '${Directory.systemTemp.path}/v13_para_v14_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (quantidade <= 1000000),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        CREATE TABLE ida_compra (
          id TEXT NOT NULL PRIMARY KEY,
          lista_id TEXT NULL,
          titulo TEXT NOT NULL,
          finalizada_em TEXT NOT NULL,
          total_centavos INTEGER NOT NULL DEFAULT 0,
          itens_count INTEGER NOT NULL DEFAULT 0,
          mercado TEXT NULL
        );
        CREATE TABLE item_ida (
          id TEXT NOT NULL PRIMARY KEY,
          ida_id TEXT NOT NULL REFERENCES ida_compra (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios','congelados',
            'padaria','bebidas','pet','limpeza','higiene','outros'))
        );
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 13;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('eeeeeeee-0000-0000-0000-000000000001', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga v13', 'user-a')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final lista =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('eeeeeeee-0000-0000-0000-000000000001'),
              ))
              .getSingle();
      expect(lista.titulo, 'Antiga v13');

      // Tabela nova existe e aceita escrita/leitura após a migração.
      await migrado
          .into(migrado.orcamentoCategoria)
          .insert(
            OrcamentoCategoriaCompanion.insert(
              categoria: 'mercearia',
              limiteCentavos: const Value(15000),
            ),
          );
      final orcamento = await migrado
          .select(migrado.orcamentoCategoria)
          .getSingle();
      expect(orcamento.categoria, 'mercearia');
      expect(orcamento.limiteCentavos, 15000);
    },
  );

  test(
    'deve_criar_tabela_orcamento_categoria_quando_migrar_v12_para_v14',
    () async {
      // Banco real na versão v12 (sem ida_compra.mercado e sem
      // `orcamento_categoria`): prova o guard ACUMULATIVO da tabela NOVA — um
      // banco bem abaixo do v13 precisa ganhar a tabela ao subir para o v14.
      // DDL espelhando o schema v12 gerado + índice manual `uq_item_ativo`,
      // dados gravados e user_version = 12.
      final arquivo = File(
        '${Directory.systemTemp.path}/v12_para_v14_${DateTime.now().microsecondsSinceEpoch}.sqlite',
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
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (quantidade <= 1000000),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        CREATE TABLE ida_compra (
          id TEXT NOT NULL PRIMARY KEY,
          lista_id TEXT NULL,
          titulo TEXT NOT NULL,
          finalizada_em TEXT NOT NULL,
          total_centavos INTEGER NOT NULL DEFAULT 0,
          itens_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE item_ida (
          id TEXT NOT NULL PRIMARY KEY,
          ida_id TEXT NOT NULL REFERENCES ida_compra (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios','congelados',
            'padaria','bebidas','pet','limpeza','higiene','outros'))
        );
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 12;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('dddddddd-0000-0000-0000-000000000001', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga v12', 'user-a')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final lista =
          await (migrado.select(migrado.listaLocal)..where(
                (l) => l.id.equals('dddddddd-0000-0000-0000-000000000001'),
              ))
              .getSingle();
      expect(lista.titulo, 'Antiga v12');

      // O guard acumulativo (`de < 14`) cria a tabela NOVA também a partir do
      // v12; sem ele a feature seria no-op silencioso nessas instalações.
      await migrado
          .into(migrado.orcamentoCategoria)
          .insert(
            OrcamentoCategoriaCompanion.insert(
              categoria: 'bebidas',
              limiteCentavos: const Value(5000),
            ),
          );
      final orcamento = await migrado
          .select(migrado.orcamentoCategoria)
          .getSingle();
      expect(orcamento.categoria, 'bebidas');
      expect(orcamento.limiteCentavos, 5000);
    },
  );

  test('deve_criar_indices_de_desempenho_quando_instalacao_nova', () async {
    final linhas = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND name IN ("
          "'idx_item_ida_ida_id','idx_ida_compra_finalizada_em',"
          "'idx_lista_local_ativa','idx_item_local_nome_lower')",
        )
        .get();
    final sql = {
      for (final r in linhas) r.read<String>('name'): r.read<String>('sql'),
    };
    expect(sql.keys.toSet(), {
      'idx_item_ida_ida_id',
      'idx_ida_compra_finalizada_em',
      'idx_lista_local_ativa',
      'idx_item_local_nome_lower',
    });
    expect(sql['idx_item_ida_ida_id'], contains('ida_id'));
    expect(sql['idx_ida_compra_finalizada_em'], contains('finalizada_em'));
    expect(sql['idx_lista_local_ativa'], contains('deletado_em IS NULL'));
    expect(sql['idx_item_local_nome_lower'], contains('lower(nome)'));
    expect(sql['idx_item_local_nome_lower'], contains('deletado_em IS NULL'));
  });

  test('deve_criar_indices_de_desempenho_quando_migrar_v14_para_v15', () async {
    final arquivo = File(
      '${Directory.systemTemp.path}/v14_para_v15_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (arquivo.existsSync()) arquivo.deleteSync();
    });

    final antigo = sq3.sqlite3.open(arquivo.path);
    antigo.execute('''
      CREATE TABLE lista_local (
        id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL, titulo TEXT NOT NULL, dono_id TEXT NOT NULL,
        deletado_em TEXT NULL, arquivada_em TEXT NULL,
        orcamento_centavos INTEGER NULL
      );
      CREATE TABLE item_local (
        id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL, lista_id TEXT NOT NULL,
        nome TEXT NOT NULL, quantidade REAL NOT NULL DEFAULT 1.0,
        unidade TEXT NOT NULL DEFAULT 'un',
        categoria TEXT NOT NULL DEFAULT 'outros',
        preco_centavos INTEGER NULL,
        concluido INTEGER NOT NULL DEFAULT 0,
        ordem INTEGER NOT NULL DEFAULT 0, deletado_em TEXT NULL
      );
      CREATE TABLE ida_compra (
        id TEXT NOT NULL PRIMARY KEY, lista_id TEXT NULL,
        titulo TEXT NOT NULL, finalizada_em TEXT NOT NULL,
        total_centavos INTEGER NOT NULL DEFAULT 0,
        itens_count INTEGER NOT NULL DEFAULT 0, mercado TEXT NULL
      );
      CREATE TABLE item_ida (
        id TEXT NOT NULL PRIMARY KEY, ida_id TEXT NOT NULL,
        nome TEXT NOT NULL, quantidade REAL NOT NULL DEFAULT 1.0,
        unidade TEXT NOT NULL DEFAULT 'un',
        categoria TEXT NOT NULL DEFAULT 'outros',
        preco_centavos INTEGER NULL
      );
      PRAGMA user_version = 14;
    ''');
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    final indices = await migrado
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ("
          "'idx_item_ida_ida_id','idx_ida_compra_finalizada_em',"
          "'idx_lista_local_ativa')",
        )
        .get();
    expect(indices.map((r) => r.data['name']).toSet(), {
      'idx_item_ida_ida_id',
      'idx_ida_compra_finalizada_em',
      'idx_lista_local_ativa',
    });
  });

  test('deve_migrar_v11_para_v16_criando_indices_e_preservando_dados', () async {
    final arquivo = File(
      '${Directory.systemTemp.path}/v11_para_v16_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (arquivo.existsSync()) arquivo.deleteSync();
    });

    final antigo = sq3.sqlite3.open(arquivo.path);
    antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL, titulo TEXT NOT NULL, dono_id TEXT NOT NULL,
          deletado_em TEXT NULL, arquivada_em TEXT NULL,
          orcamento_centavos INTEGER NULL
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY, created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL, quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0, deletado_em TEXT NULL,
          preco_centavos INTEGER NULL,
          CHECK (quantidade > 0),
          CHECK (quantidade <= 1000000),
          CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','pt','dz')),
          CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',
            'congelados','padaria','bebidas','pet','limpeza','higiene','outros')),
          CHECK (preco_centavos IS NULL OR
            (preco_centavos >= 0 AND preco_centavos <= 99999999))
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL, registrado_em TEXT NOT NULL
        );
        CREATE UNIQUE INDEX uq_item_ativo
          ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL;
        PRAGMA user_version = 11;
      ''');
    antigo.execute(
      "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
      "VALUES ('11111111-0000-0000-0000-000000000001', "
      "'2026-01-01T00:00:00.000000Z','2026-01-01T00:00:00.000000Z','Antiga','local')",
    );
    antigo.execute(
      "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
      "quantidade, unidade, categoria, concluido, ordem) VALUES "
      "('11111111-0000-0000-0000-000000000002', "
      "'2026-01-01T00:00:00.000000Z','2026-01-01T00:00:00.000000Z',"
      "'11111111-0000-0000-0000-000000000001','Café',2.0,'kg','mercearia',0,0)",
    );
    antigo.close();

    final migrado = AppDatabase(NativeDatabase(arquivo));
    addTearDown(migrado.close);

    expect(migrado.schemaVersion, 16);
    final item = await migrado.select(migrado.itemLocal).getSingle();
    expect(item.nome, 'Café');
    expect(item.quantidade, 2.0);

    final nomes = await migrado
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ("
          "'idx_item_ida_ida_id','idx_ida_compra_finalizada_em',"
          "'idx_lista_local_ativa','idx_item_local_nome_lower')",
        )
        .get();
    expect(nomes.map((r) => r.read<String>('name')).toSet(), {
      'idx_item_ida_ida_id',
      'idx_ida_compra_finalizada_em',
      'idx_lista_local_ativa',
      'idx_item_local_nome_lower',
    });
  });
}
