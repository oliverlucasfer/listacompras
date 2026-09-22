import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/resultado_dedup.dart';
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

  test('deve_contar_itens_ativos_e_concluidos_quando_watch_contagem', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final arroz = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    await repo.editarItem(arroz.id, concluido: true);
    final leite = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.removerItem(leite.id);

    final contagens = await repo.watchListasComContagem().first.timeout(
      const Duration(seconds: 2),
    );
    expect(contagens, hasLength(1));
    expect(contagens.single.totalItens, 2);
    expect(contagens.single.concluidos, 1);
    expect(contagens.single.contagem, '1/2 itens concluídos');
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

  test('deve_restaurar_item_e_enfileirar_update_quando_undo', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Café');
    await repo.removerItem(item.id);

    await repo.restaurarItem(item.id);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.deletadoEm, isNull);

    final ativos = await repo
        .watchItensDaLista(lista.id)
        .first
        .timeout(const Duration(seconds: 2));
    expect(ativos, hasLength(1));

    final mutacoes = await fila();
    expect(mutacoes.last['operacao'], 'UPDATE');
    final payload = mutacoes.last['payload'] as Map<String, Object?>;
    expect(payload['deletado_em'], isNull);
  });

  test(
    'deve_desmarcar_todos_os_concluidos_quando_reaproveitar_lista',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
      final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
      await repo.editarItem(i1.id, concluido: true);
      await repo.editarItem(i3.id, concluido: true);
      final antes = await fila();

      await repo.desmarcarTodos(lista.id);

      final itens = await (db.select(
        db.itemLocal,
      )..where((i) => i.listaId.equals(lista.id))).get();
      expect(itens.where((i) => i.concluido), isEmpty);
      expect(itens, hasLength(3));

      final novas = (await fila()).skip(antes.length).toList();
      expect(novas, hasLength(2));
      expect(novas.every((m) => m['operacao'] == 'UPDATE'), isTrue);
      expect(novas.map((m) => m['registro_id']).toSet(), {i1.id, i3.id});
    },
  );

  test('deve_soft_delete_dos_concluidos_quando_limpar_concluidos', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.editarItem(i2.id, concluido: true);
    await repo.editarItem(i3.id, concluido: true);

    await repo.limparConcluidos(lista.id);

    final ativos = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id) & i.deletadoEm.isNull())).get();
    expect(ativos.single.id, i1.id);

    final mutacoes = await fila();
    final deletes = mutacoes
        .where((m) => m['operacao'] == 'DELETE_SOFT')
        .toList();
    expect(deletes, hasLength(2));
    expect(deletes.map((m) => m['registro_id']).toSet(), {i2.id, i3.id});
  });

  test('deve_devolver_itens_removidos_quando_limpar_concluidos', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.editarItem(i1.id, concluido: true);
    await repo.editarItem(i3.id, concluido: true);

    final removidos = await repo.limparConcluidos(lista.id);

    expect(removidos.map((i) => i.id).toSet(), {i1.id, i3.id});
    expect(removidos.map((i) => i.ordem).toSet(), {i1.ordem, i3.ordem});
    expect(removidos, hasLength(2));
    expect(removidos.every((i) => i.listaId == lista.id), isTrue);
    expect(removidos.map((i) => i.id), isNot(contains(i2.id)));
  });

  test('deve_restaurar_id_e_ordem_quando_undo_do_limpar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final i1 = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final i2 = await repo.adicionarItem(listaId: lista.id, nome: 'Feijão');
    final i3 = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    await repo.editarItem(i1.id, concluido: true);
    await repo.editarItem(i3.id, concluido: true);

    final removidos = await repo.limparConcluidos(lista.id);
    for (final item in removidos) {
      await repo.restaurarItem(item.id);
    }

    final ativos = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id) & i.deletadoEm.isNull())).get();
    final ordens = {for (final i in ativos) i.id: i.ordem};
    expect(ordens, {i1.id: i1.ordem, i2.id: i2.ordem, i3.id: i3.ordem});
  });

  test('deve_reordenar_e_enfileirar_apenas_mudancas_quando_drag', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final arroz = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final leite = await repo.adicionarItem(listaId: lista.id, nome: 'Leite');
    final cafe = await repo.adicionarItem(listaId: lista.id, nome: 'Café');

    // Nova ordem: Leite (0), Arroz (1), Café (2) — Café não muda.
    await repo.reordenarItens(lista.id, [leite.id, arroz.id, cafe.id]);

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id) & i.deletadoEm.isNull())).get();
    final ordens = {for (final i in itens) i.id: i.ordem};
    expect(ordens, {leite.id: 0, arroz.id: 1, cafe.id: 2});

    final mutacoes = await fila();
    final updates = mutacoes
        .where((m) => m['operacao'] == 'UPDATE' && m['tabela'] == 'itens_lista')
        .toList();
    expect(updates, hasLength(2)); // Café mantém a ordem → sem mutação
    final ids = updates.map((m) => m['registro_id']).toSet();
    expect(ids, {leite.id, arroz.id});
    final leitePayload = updates
        .map((m) => m['payload'] as Map<String, Object?>)
        .firstWhere((p) => p['id'] == leite.id);
    expect(leitePayload['ordem'], 0);
  });

  test('deve_gravar_categoria_informada_quando_adicionar_item_f6t02', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Queijo prato',
      categoria: CategoriaItem.frios,
    );

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.categoria, 'frios');
    expect(item.categoria, CategoriaItem.frios);
  });

  test(
    'deve_gravar_outros_quando_adicionar_item_sem_categoria_f6t02',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

      final item = await repo.adicionarItem(listaId: lista.id, nome: 'Coisa');

      expect(item.categoria, CategoriaItem.outros);
    },
  );

  test(
    'deve_incluir_categoria_no_payload_quando_enfileirar_item_f6t02',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Leite',
        categoria: CategoriaItem.laticinios,
      );

      final mutacoes = await fila();
      final inserts = mutacoes
          .where(
            (m) => m['tabela'] == 'itens_lista' && m['operacao'] == 'INSERT',
          )
          .toList();
      final payload = inserts.single['payload'] as Map<String, Object?>;
      expect(payload['categoria'], 'laticinios');

      await repo.editarItem(item.id, categoria: CategoriaItem.frios);

      final local = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(local.categoria, 'frios');

      final updates = (await fila())
          .where(
            (m) => m['tabela'] == 'itens_lista' && m['operacao'] == 'UPDATE',
          )
          .toList();
      expect(updates, hasLength(1));
      expect(
        (updates.single['payload'] as Map<String, Object?>)['categoria'],
        'frios',
      );
    },
  );

  test(
    'deve_gravar_e_enfileirar_preco_quando_adicionar_item_com_preco',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Arroz',
        precoCentavos: 549,
      );

      final local = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(local.precoCentavos, 549);

      final mutacoes = await fila();
      final payload = mutacoes.last['payload'] as Map<String, Object?>;
      expect(payload['preco_centavos'], 549);
    },
  );

  test(
    'deve_gravar_e_enfileirar_preco_quando_adicionar_item_com_preco_zero',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Arroz',
        precoCentavos: 0,
      );

      final local = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(item.id))).getSingle();
      expect(local.precoCentavos, 0);

      final payload = (await fila()).last['payload'] as Map<String, Object?>;
      expect(payload['preco_centavos'], 0);
    },
  );

  test('deve_preservar_preco_quando_editar_outro_campo', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    await repo.editarItem(item.id, nome: 'Arroz Tio João');

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, 549);
  });

  test('deve_limpar_preco_quando_editar_com_limparPreco', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    await repo.editarItem(item.id, limparPreco: true);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, isNull);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['preco_centavos'], isNull);
  });

  test('deve_preferir_preco_quando_presente_e_limparPreco_ambos', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );

    await repo.editarItem(item.id, precoCentavos: 0, limparPreco: true);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.precoCentavos, 0);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['preco_centavos'], 0);
  });

  test('deve_gravar_e_enfileirar_arquivo_quando_arquivar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final antes = DateTime.now().toUtc();

    await repo.definirArquivada(lista.id, arquivada: true);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.arquivadaEm, isNotNull);
    // Valor exato gravado: arquivada_em == updated_at do mesmo write.
    expect(local.arquivadaEm!.toUtc(), local.updatedAt.toUtc());
    // E dentro de uma janela estreita em torno de "agora".
    expect(local.arquivadaEm!.toUtc().isBefore(antes), isFalse);
    expect(
      local.arquivadaEm!.toUtc().difference(DateTime.now().toUtc()).abs(),
      lessThan(const Duration(minutes: 1)),
    );
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(
      payload['arquivada_em'],
      local.arquivadaEm!.toUtc().toIso8601String(),
    );
  });

  test('deve_limpar_arquivo_quando_desarquivar', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirArquivada(lista.id, arquivada: true);
    final arquivada = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(arquivada.arquivadaEm!.toUtc(), arquivada.updatedAt.toUtc());

    await repo.definirArquivada(lista.id, arquivada: false);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.arquivadaEm, isNull);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['arquivada_em'], isNull);
  });

  test('deve_gravar_e_enfileirar_orcamento_quando_definir', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirOrcamento(lista.id, centavos: 25000);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, 25000);
    final mutacoes = await fila();
    expect(mutacoes.last['operacao'], 'UPDATE');
    expect(mutacoes.last['tabela'], 'listas');
    final payload = mutacoes.last['payload'] as Map<String, Object?>;
    expect(payload['orcamento_centavos'], 25000);
  });

  test('deve_limpar_orcamento_quando_definir_null', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirOrcamento(lista.id, centavos: 25000);

    await repo.definirOrcamento(lista.id, centavos: null);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, isNull);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['orcamento_centavos'], isNull);
  });

  test('deve_gravar_orcamento_zero_quando_definir_zero', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirOrcamento(lista.id, centavos: 0);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, 0);
    final payload = (await fila()).last['payload'] as Map<String, Object?>;
    expect(payload['orcamento_centavos'], 0);
  });

  test('deve_incluir_orcamento_nulo_no_payload_quando_criar_lista', () async {
    await repo.criarLista(titulo: 'X', donoId: 'user-a');

    final payload = (await fila()).single['payload'] as Map<String, Object?>;
    expect(payload.containsKey('orcamento_centavos'), isTrue);
    expect(payload['orcamento_centavos'], isNull);
  });

  test('deve_expor_orcamento_no_stream_quando_definir', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirOrcamento(lista.id, centavos: 12345);

    final lida = await repo
        .watchLista(lista.id)
        .first
        .timeout(const Duration(seconds: 2));
    expect(lida?.orcamentoCentavos, 12345);
  });

  test('nao_deve_enviar_arquivo_quando_renomear', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.renomearLista(id: lista.id, titulo: 'Y');

    final rename = (await fila()).last['payload'] as Map<String, Object?>;
    expect(rename.containsKey('arquivada_em'), isFalse);

    await repo.definirArquivada(lista.id, arquivada: true);
    final arquivar = (await fila()).last['payload'] as Map<String, Object?>;
    expect(arquivar.containsKey('arquivada_em'), isTrue);
    expect(arquivar['arquivada_em'], isA<String>());

    await repo.definirArquivada(lista.id, arquivada: false);
    final desarquivar = (await fila()).last['payload'] as Map<String, Object?>;
    expect(desarquivar.containsKey('arquivada_em'), isTrue);
    expect(desarquivar['arquivada_em'], isNull);
  });

  test('nao_deve_arquivar_lista_nova_quando_duplicar', () async {
    final origem = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz');
    await repo.definirArquivada(origem.id, arquivada: true);

    final nova = await repo.duplicarLista(
      origemId: origem.id,
      titulo: 'Y',
      donoId: 'user-a',
    );

    expect(nova.arquivadaEm, isNull);
  });

  test('deve_refletir_arquivo_no_painel_quando_watch_contagem', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirArquivada(lista.id, arquivada: true);
    final arquivada = await repo.watchListasComContagem().first.timeout(
      const Duration(seconds: 2),
    );
    expect(arquivada.single.lista.arquivadaEm, isNotNull);
    expect(arquivada.single.lista.id, lista.id);

    await repo.definirArquivada(lista.id, arquivada: false);
    final desarquivada = await repo.watchListasComContagem().first.timeout(
      const Duration(seconds: 2),
    );
    expect(desarquivada.single.lista.arquivadaEm, isNull);
  });

  test('deve_adicionar_quando_nome_nao_existe', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
    );
    expect(r, ResultadoDedup.adicionado);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 2);
  });

  test('deve_somar_quando_mesmo_nome_e_unidade', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
    );
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'ARROZ',
      quantidade: 1,
      unidade: Unidade.kg,
      categoria: CategoriaItem.outros,
    );
    expect(r, ResultadoDedup.somado);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens, hasLength(1));
    expect(itens.single.quantidade, 3);
  });

  test('deve_substituir_quando_mesmo_nome_e_unidade_diferente', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
    );
    final r = await repo.adicionarItemDedup(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 5,
      unidade: Unidade.un,
      categoria: CategoriaItem.outros,
    );
    expect(r, ResultadoDedup.substituido);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens.single.quantidade, 5);
    expect(itens.single.unidade, 'un');
  });

  test('deve_ignorar_preco_e_concluido_quando_adicionar_lote', () async {
    final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
    final destino = await repo.criarLista(titulo: 'Destino', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Queijo',
      quantidade: 0.5,
      unidade: Unidade.kg,
      categoria: CategoriaItem.frios,
      precoCentavos: 4990,
    );
    await repo.editarItem(item.id, concluido: true);

    final fonte = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    await repo.adicionarItensDedup(destino.id, [Item.fromLocal(fonte)]);

    final novo = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(destino.id))).getSingle();
    expect(novo.nome, 'Queijo');
    expect(novo.quantidade, 0.5);
    expect(novo.unidade, 'kg');
    expect(novo.categoria, 'frios');
    expect(novo.concluido, isFalse);
    expect(novo.precoCentavos, isNull);
  });

  test(
    'deve_aplicar_dedup_por_nome_normalizado_quando_adicionar_lote',
    () async {
      final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
      final destino = await repo.criarLista(
        titulo: 'Destino',
        donoId: 'user-a',
      );
      await repo.adicionarItem(listaId: destino.id, nome: 'Café');
      final itemOrigem = await repo.adicionarItem(
        listaId: origem.id,
        nome: 'CAFE',
        quantidade: 2,
      );

      final fonte = await (db.select(
        db.itemLocal,
      )..where((i) => i.id.equals(itemOrigem.id))).getSingle();
      await repo.adicionarItensDedup(destino.id, [Item.fromLocal(fonte)]);

      final itens = await (db.select(
        db.itemLocal,
      )..where((i) => i.listaId.equals(destino.id))).get();
      expect(itens, hasLength(1));
      expect(itens.single.quantidade, 3);
    },
  );
}
