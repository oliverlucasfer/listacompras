import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';

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
}
