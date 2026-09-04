import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/drift/database.dart';

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

  Future<List<Map<String, Object?>>> fila() async {
    final mutacoes = await db.select(db.mutacaoPendente).get();
    return mutacoes
        .map(
          (m) => {
            'tabela': m.tabela,
            'operacao': m.operacao,
            'registro_id': m.registroId,
            'payload': jsonDecode(m.payload) as Map<String, Object?>,
            'lista_id': m.listaId,
          },
        )
        .toList();
  }

  test(
    'deve_criar_lista_local_e_enfileirar_insert_quando_criar_lista',
    () async {
      final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');

      final local = await (db.select(
        db.listaLocal,
      )..where((l) => l.id.equals(lista.id))).getSingle();
      expect(local.titulo, 'Compras');
      expect(local.donoId, 'user-a');
      expect(local.deletadoEm, isNull);

      final mutacoes = await fila();
      expect(mutacoes, hasLength(1));
      expect(mutacoes.single['tabela'], 'listas');
      expect(mutacoes.single['operacao'], 'INSERT');
      expect(mutacoes.single['registro_id'], lista.id);
      expect(mutacoes.single['lista_id'], lista.id);
      final payload = mutacoes.single['payload'] as Map<String, Object?>;
      expect(payload['titulo'], 'Compras');
      expect(payload['dono_id'], 'user-a');
      expect(payload['updated_at'], isA<String>());
    },
  );

  test('deve_gerar_id_uuid_v4_quando_criar_lista', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuidV4.hasMatch(lista.id), isTrue);
  });

  test(
    'deve_renomear_localmente_e_enfileirar_update_quando_renomear',
    () async {
      final lista = await repo.criarLista(titulo: 'Antigo', donoId: 'user-a');

      await repo.renomearLista(id: lista.id, titulo: 'Novo');

      final local = await (db.select(
        db.listaLocal,
      )..where((l) => l.id.equals(lista.id))).getSingle();
      expect(local.titulo, 'Novo');

      final mutacoes = await fila();
      expect(mutacoes, hasLength(2));
      expect(mutacoes.last['operacao'], 'UPDATE');
      final payload = mutacoes.last['payload'] as Map<String, Object?>;
      expect(payload['titulo'], 'Novo');
      expect(payload['dono_id'], 'user-a');
    },
  );

  test(
    'deve_soft_delete_e_enfileirar_delete_soft_quando_excluir_lista',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

      await repo.excluirLista(lista.id);

      final local = await (db.select(
        db.listaLocal,
      )..where((l) => l.id.equals(lista.id))).getSingle();
      expect(local.deletadoEm, isNotNull);
      final ativas = await (db.select(
        db.listaLocal,
      )..where((l) => l.deletadoEm.isNull())).get();
      expect(ativas, isEmpty);

      final mutacoes = await fila();
      expect(mutacoes.last['operacao'], 'DELETE_SOFT');
      final payload = mutacoes.last['payload'] as Map<String, Object?>;
      expect(payload['deletado_em'], isNotNull);
    },
  );

  test('deve_notificar_stream_quando_criar_lista', () async {
    final fut = repo.watchListas().firstWhere((l) => l.isNotEmpty);
    await repo.criarLista(titulo: 'Reativa', donoId: 'user-a');
    final listas = await fut.timeout(const Duration(seconds: 2));
    expect(listas.single.titulo, 'Reativa');
  });

  test('deve_adicionar_ordem_sequencial_quando_adicionar_tres_itens', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      quantidade: 2,
      unidade: Unidade.l,
    );

    expect(i1.ordem, 0);
    expect(i2.ordem, 1);
    expect(i3.ordem, 2);
    expect(i3.quantidade, 2);
    expect(i3.unidade, Unidade.l);
  });

  test('deve_rejeitar_quantidade_nao_positiva_quando_adicionar_item', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final antes = await fila();

    expect(
      () => repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 0),
      throwsArgumentError,
    );
    expect(await fila(), hasLength(antes.length));
  });

  test('deve_rejeitar_unidade_fora_do_enum_quando_converter_valor', () {
    expect(() => Unidade.fromValor('quilos'), throwsArgumentError);
    expect(Unidade.fromValor('kg'), Unidade.kg);
  });

  test('deve_editar_campos_e_enfileirar_update_quando_editar_item', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await repo.editarItem(
      item.id,
      nome: 'Arroz integral',
      quantidade: 5,
      unidade: Unidade.kg,
    );

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.nome, 'Arroz integral');
    expect(local.quantidade, 5);
    expect(local.unidade, 'kg');

    final mutacoes = await fila();
    expect(mutacoes, hasLength(3));
    expect(mutacoes.last['operacao'], 'UPDATE');
    expect(mutacoes.last['tabela'], 'itens_lista');
    final payload = mutacoes.last['payload'] as Map<String, Object?>;
    expect(payload['nome'], 'Arroz integral');
    expect(payload['lista_id'], lista.id);
    expect(payload['unidade'], 'kg');
  });

  test(
    'deve_marcar_concluido_e_enfileirar_update_quando_alternar_item',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(listaId: lista.id, nome: 'Café');

      await repo.editarItem(item.id, concluido: true);

      final local = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(local.concluido, isTrue);
      expect((await fila()).last['operacao'], 'UPDATE');
    },
  );

  test(
    'deve_soft_delete_item_e_remover_do_stream_quando_remover_item',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(listaId: lista.id, nome: 'Café');

      await repo.removerItem(item.id);

      final local = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(local.deletadoEm, isNotNull);

      final ativos = await repo
          .watchItensDaLista(lista.id)
          .first
          .timeout(const Duration(seconds: 2));
      expect(ativos, isEmpty);

      final mutacoes = await fila();
      expect(mutacoes.last['operacao'], 'DELETE_SOFT');
      expect(mutacoes.last['tabela'], 'itens_lista');
    },
  );
}
