import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/sync/data/aplicador_remoto.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

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
}
