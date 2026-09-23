import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/sync/data/aplicador_remoto.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('deve_aplicar_lista_remota_quando_nao_existe_localmente', () async {
    final aplicador = AplicadorRemoto(db);

    await aplicador.aplicar('listas', {
      'id': 'lista-1',
      'titulo': 'Compras do Mês',
      'dono_id': 'user-a',
      'created_at': '2026-09-04T12:00:00.000Z',
      'updated_at': '2026-09-04T12:05:00.000Z',
      'deletado_em': null,
    });

    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('lista-1'))).getSingle();
    expect(lista.titulo, 'Compras do Mês');
    expect(lista.donoId, 'user-a');
    // Drift devolve DateTime no fuso local — compara o instante.
    expect(lista.updatedAt.toUtc(), DateTime.utc(2026, 9, 4, 12, 5));
    expect(lista.deletadoEm, isNull);
  });

  test(
    'deve_aplicar_item_remoto_com_enum_e_tombstone_quando_removido',
    () async {
      // Remoção remota chega como tombstone → item some da UI (doc 03 §1.4).
      final aplicador = AplicadorRemoto(db);
      await db
          .into(db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: 'lista-1',
              createdAt: DateTime.utc(2026, 9, 4, 12),
              updatedAt: DateTime.utc(2026, 9, 4, 12),
              titulo: 'Compras',
              donoId: 'user-a',
            ),
          );

      await aplicador.aplicar('itens_lista', {
        'id': 'item-1',
        'lista_id': 'lista-1',
        'nome': 'Leite',
        'quantidade': 2.5,
        'unidade': 'l',
        'concluido': true,
        'ordem': 3,
        'created_at': '2026-09-04T12:00:00.000Z',
        'updated_at': '2026-09-04T12:10:00.000Z',
        'deletado_em': '2026-09-04T12:09:00.000Z',
      });

      final item = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals('item-1'))).getSingle();
      expect(item.nome, 'Leite');
      expect(item.quantidade, 2.5);
      expect(Unidade.fromValor(item.unidade), Unidade.l);
      expect(item.concluido, true);
      expect(item.ordem, 3);
      expect(item.deletadoEm!.toUtc(), DateTime.utc(2026, 9, 4, 12, 9));
    },
  );

  test('deve_sobrescrever_linha_local_quando_remoto_aplicado', () async {
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'lista-1',
            createdAt: DateTime.utc(2026, 9, 4, 12),
            updatedAt: DateTime.utc(2026, 9, 4, 12),
            titulo: 'Compras',
            donoId: 'user-a',
          ),
        );
    await db
        .into(db.itemLocal)
        .insert(
          ItemLocalCompanion.insert(
            id: 'item-1',
            createdAt: DateTime.utc(2026, 9, 4, 12),
            updatedAt: DateTime.utc(2026, 9, 4, 12),
            listaId: 'lista-1',
            nome: 'Arroz',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'item-1',
      'lista_id': 'lista-1',
      'nome': 'Arroz parboilizado',
      'quantidade': 2,
      'unidade': 'kg',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-04T12:00:00.000Z',
      'updated_at': '2026-09-04T12:30:00.000Z',
      'deletado_em': null,
    });

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('item-1'))).get();
    expect(itens, hasLength(1));
    expect(itens.single.nome, 'Arroz parboilizado');
    expect(itens.single.quantidade, 2.0);
    expect(itens.single.unidade, 'kg');
  });

  test('deve_aplicar_categoria_remota_quando_item_validado_f6t06', () async {
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'lista-1',
            createdAt: DateTime.utc(2026, 9, 8, 12),
            updatedAt: DateTime.utc(2026, 9, 8, 12),
            titulo: 'Compras',
            donoId: 'user-a',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'item-1',
      'lista_id': 'lista-1',
      'nome': 'Detergente',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'limpeza',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-08T12:00:00.000Z',
      'updated_at': '2026-09-08T12:30:00.000Z',
      'deletado_em': null,
    });

    final item = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('item-1'))).getSingle();
    expect(item.categoria, 'limpeza');
  });

  test('deve_usar_outros_quando_registro_remoto_sem_categoria_f6t06', () async {
    // Compat (spec F6 §7): linha gravada por app antigo (1.0.0+2) chega
    // sem a coluna no bootstrap/Realtime.
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'lista-1',
            createdAt: DateTime.utc(2026, 9, 8, 12),
            updatedAt: DateTime.utc(2026, 9, 8, 12),
            titulo: 'Compras',
            donoId: 'user-a',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'item-2',
      'lista_id': 'lista-1',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'kg',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-08T12:00:00.000Z',
      'updated_at': '2026-09-08T12:30:00.000Z',
      'deletado_em': null,
    });

    final item = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('item-2'))).getSingle();
    expect(item.categoria, 'outros');
  });

  test('deve_mapear_preco_ausente_para_null_quando_linha_antiga', () async {
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'l-preco-1',
            createdAt: DateTime.utc(2026, 9, 21),
            updatedAt: DateTime.utc(2026, 9, 21),
            titulo: 'X',
            donoId: 'u',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'i-preco-1',
      'lista_id': 'l-preco-1',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'outros',
      'concluido': false,
      'ordem': 0,
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });

    final linha = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i-preco-1'))).getSingle();
    expect(linha.precoCentavos, isNull);
  });

  test('deve_mapear_preco_quando_presente', () async {
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'l-preco-2',
            createdAt: DateTime.utc(2026, 9, 21),
            updatedAt: DateTime.utc(2026, 9, 21),
            titulo: 'X',
            donoId: 'u',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'i-preco-2',
      'lista_id': 'l-preco-2',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'outros',
      'concluido': false,
      'ordem': 0,
      'preco_centavos': 549,
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });

    final linha = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i-preco-2'))).getSingle();
    expect(linha.precoCentavos, 549);
  });

  test('deve_mapear_preco_nao_numerico_para_null_quando_tolerancia', () async {
    final aplicador = AplicadorRemoto(db);
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'l-preco-3',
            createdAt: DateTime.utc(2026, 9, 21),
            updatedAt: DateTime.utc(2026, 9, 21),
            titulo: 'X',
            donoId: 'u',
          ),
        );

    await aplicador.aplicar('itens_lista', {
      'id': 'i-preco-3',
      'lista_id': 'l-preco-3',
      'nome': 'Arroz',
      'quantidade': 1,
      'unidade': 'un',
      'categoria': 'outros',
      'concluido': false,
      'ordem': 0,
      'preco_centavos': 'abc',
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });

    final linha = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals('i-preco-3'))).getSingle();
    expect(linha.precoCentavos, isNull);
  });

  test('deve_mapear_arquivo_ausente_para_null_quando_linha_antiga', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-arq-1',
      'titulo': 'X',
      'dono_id': 'u',
      'created_at': '2026-09-21T12:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-arq-1'))).getSingle();
    expect(lista.arquivadaEm, isNull);
  });

  test('deve_mapear_arquivo_quando_presente', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-arq-2',
      'titulo': 'X',
      'dono_id': 'u',
      'arquivada_em': '2026-09-21T12:00:00.000Z',
      'created_at': '2026-09-21T11:00:00.000Z',
      'updated_at': '2026-09-21T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-arq-2'))).getSingle();
    expect(lista.arquivadaEm, isNotNull);
  });

  test('deve_mapear_orcamento_ausente_para_null_quando_linha_antiga', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-orc-1',
      'titulo': 'X',
      'dono_id': 'u',
      'created_at': '2026-09-22T12:00:00.000Z',
      'updated_at': '2026-09-22T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-orc-1'))).getSingle();
    expect(lista.orcamentoCentavos, isNull);
  });

  test('deve_mapear_orcamento_quando_presente', () async {
    final aplicador = AplicadorRemoto(db);
    await aplicador.aplicar('listas', {
      'id': 'l-orc-2',
      'titulo': 'X',
      'dono_id': 'u',
      'orcamento_centavos': 25000,
      'created_at': '2026-09-22T12:00:00.000Z',
      'updated_at': '2026-09-22T12:00:00.000Z',
      'deletado_em': null,
    });
    final lista = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals('l-orc-2'))).getSingle();
    expect(lista.orcamentoCentavos, 25000);
  });

  test(
    'deve_mapear_orcamento_nao_numerico_para_null_quando_tolerancia',
    () async {
      final aplicador = AplicadorRemoto(db);
      await aplicador.aplicar('listas', {
        'id': 'l-orc-3',
        'titulo': 'X',
        'dono_id': 'u',
        'orcamento_centavos': 'abc',
        'created_at': '2026-09-22T12:00:00.000Z',
        'updated_at': '2026-09-22T12:00:00.000Z',
        'deletado_em': null,
      });
      final lista = await (db.select(
        db.listaLocal,
      )..where((l) => l.id.equals('l-orc-3'))).getSingle();
      expect(lista.orcamentoCentavos, isNull);
    },
  );
}
