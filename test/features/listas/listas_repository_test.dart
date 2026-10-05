import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/resultado_dedup.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
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

  test('deve_criar_lista_local_quando_criar_lista', () async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.titulo, 'Compras');
    expect(local.donoId, 'user-a');
    expect(local.deletadoEm, isNull);
  });

  test('deve_gerar_id_uuid_v4_quando_criar_lista', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuidV4.hasMatch(lista.id), isTrue);
  });

  test('deve_renomear_localmente_quando_renomear', () async {
    final lista = await repo.criarLista(titulo: 'Antigo', donoId: 'user-a');

    await repo.renomearLista(id: lista.id, titulo: 'Novo');

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.titulo, 'Novo');
  });

  test('deve_soft_delete_quando_excluir_lista', () async {
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
  });

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
  });

  test('deve_expor_orcamento_quando_watch_listas_com_contagem', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirOrcamento(lista.id, centavos: 25000);

    final contagens = await repo.watchListasComContagem().first.timeout(
      const Duration(seconds: 2),
    );

    expect(contagens.single.orcamentoCentavos, 25000);
    expect(contagens.single.lista.orcamentoCentavos, 25000);
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

    expect(
      () => repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 0),
      throwsArgumentError,
    );
    expect(await db.select(db.itemLocal).get(), isEmpty);
  });

  test('deve_rejeitar_unidade_fora_do_enum_quando_converter_valor', () {
    expect(() => Unidade.fromValor('quilos'), throwsArgumentError);
    expect(Unidade.fromValor('kg'), Unidade.kg);
    expect(Unidade.fromValor('pt'), Unidade.pt);
  });

  test('deve_gravar_unidade_pt_quando_adicionar_item', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Sorvete',
      quantidade: 2,
      unidade: Unidade.pt,
    );

    final gravado = await (db.select(
      db.itemLocal,
    )..where((t) => t.id.equals(item.id))).getSingle();
    expect(gravado.unidade, 'pt');
    expect(Unidade.fromValor(gravado.unidade), Unidade.pt);
  });

  test('deve_editar_campos_quando_editar_item', () async {
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
  });

  test('deve_marcar_concluido_quando_alternar_item', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Café');

    await repo.editarItem(item.id, concluido: true);

    final local = await (db.select(
      db.itemLocal,
    )..where((i) => i.id.equals(item.id))).getSingle();
    expect(local.concluido, isTrue);
  });

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
    },
  );

  test('deve_restaurar_item_quando_undo', () async {
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

      await repo.desmarcarTodos(lista.id);

      final itens = await (db.select(
        db.itemLocal,
      )..where((i) => i.listaId.equals(lista.id))).get();
      expect(itens.where((i) => i.concluido), isEmpty);
      expect(itens, hasLength(3));
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

  test('deve_reordenar_apenas_mudancas_quando_drag', () async {
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

  test('deve_gravar_preco_quando_adicionar_item_com_preco', () async {
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
  });

  test('deve_gravar_preco_zero_quando_adicionar_item_com_preco_zero', () async {
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
  });

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
  });

  test('deve_gravar_arquivo_quando_arquivar', () async {
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
  });

  test('deve_gravar_orcamento_quando_definir', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirOrcamento(lista.id, centavos: 25000);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, 25000);
  });

  test('deve_limpar_orcamento_quando_definir_null', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.definirOrcamento(lista.id, centavos: 25000);

    await repo.definirOrcamento(lista.id, centavos: null);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, isNull);
  });

  test('deve_gravar_orcamento_zero_quando_definir_zero', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    await repo.definirOrcamento(lista.id, centavos: 0);

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, 0);
  });

  test('deve_rejeitar_orcamento_negativo_quando_definir', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    expect(
      () => repo.definirOrcamento(lista.id, centavos: -1),
      throwsArgumentError,
    );

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, isNull);
  });

  test('deve_rejeitar_orcamento_acima_do_teto_quando_definir', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');

    expect(
      () => repo.definirOrcamento(lista.id, centavos: 100000000),
      throwsArgumentError,
    );

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.orcamentoCentavos, isNull);
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

  test('deve_registrar_historico_quando_concluir_item_com_preco', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Café',
      unidade: Unidade.pacote,
      precoCentavos: 1850,
    );

    await repo.editarItem(item.id, concluido: true);

    final rows = await db.select(db.historicoPrecoLocal).get();
    expect(rows, hasLength(1));
    expect(rows.single.nomeNormalizado, 'cafe');
    expect(rows.single.precoCentavos, 1850);
    expect(rows.single.unidade, 'pacote');
  });

  test('deve_nao_registrar_historico_quando_concluir_item_sem_preco', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(listaId: lista.id, nome: 'Café');

    await repo.editarItem(item.id, concluido: true);

    expect(await db.select(db.historicoPrecoLocal).get(), isEmpty);
  });

  test('deve_manter_historico_quando_desmarcar_item_concluido', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Café',
      precoCentavos: 1850,
    );

    await repo.editarItem(item.id, concluido: true);
    await repo.editarItem(item.id, concluido: false);

    final rows = await db.select(db.historicoPrecoLocal).get();
    expect(rows, hasLength(1));
    expect(rows.single.precoCentavos, 1850);
  });

  test(
    'deve_manter_registradoEm_quando_editar_item_ja_concluido_sem_mudar_preco',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Café',
        precoCentavos: 1850,
      );

      await repo.editarItem(item.id, concluido: true);
      final registrado =
          (await db.select(db.historicoPrecoLocal).get()).single.registradoEm;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Edição não relacionada (quantidade) num item já concluído com preço
      // não deve re-registrar o histórico (RF-29, F37).
      await repo.editarItem(item.id, quantidade: 3);

      final rows = await db.select(db.historicoPrecoLocal).get();
      expect(rows, hasLength(1));
      expect(rows.single.registradoEm, registrado);
    },
  );

  test(
    'deve_atualizar_historico_quando_preco_muda_com_item_concluido',
    () async {
      final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Café',
        precoCentavos: 1850,
      );

      await repo.editarItem(item.id, concluido: true);
      // Corrigir o preço de um item já concluído atualiza o histórico.
      await repo.editarItem(item.id, precoCentavos: 2000);

      final rows = await db.select(db.historicoPrecoLocal).get();
      expect(rows, hasLength(1));
      expect(rows.single.precoCentavos, 2000);
    },
  );

  test(
    'deve_ignorar_sem_erro_quando_remove_ou_restaura_id_inexistente',
    () async {
      // Operação idempotente: id inexistente afeta 0 linhas e não lança.
      await repo.removerItem('id-inexistente');
      await repo.restaurarItem('id-inexistente');

      expect(await db.select(db.itemLocal).get(), isEmpty);
    },
  );

  Item itemLote(
    String nome, {
    double quantidade = 1,
    Unidade unidade = Unidade.un,
  }) {
    final agora = DateTime.now().toUtc();
    return Item(
      id: 'lote-$nome',
      listaId: 'l',
      nome: nome,
      quantidade: quantidade,
      unidade: unidade,
      categoria: CategoriaItem.mercearia,
      concluido: true,
      ordem: 0,
      criadoEm: agora,
      atualizadoEm: agora,
    );
  }

  test(
    'deve_somar_quando_unidade_igual_e_inserir_quando_novo_no_lote',
    () async {
      final lista = await repo.criarLista(titulo: 'Lote', donoId: 'user-a');
      await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 2);

      await repo.adicionarItensDedup(lista.id, [
        itemLote('arroz'),
        itemLote('Feijão', quantidade: 3, unidade: Unidade.kg),
      ]);

      final itens = await repo.watchItensDaLista(lista.id).first;
      expect(itens.length, 2);
      final arroz = itens.firstWhere((i) => i.nome.toLowerCase() == 'arroz');
      expect(arroz.quantidade, 3);
      final feijao = itens.firstWhere((i) => i.nome == 'Feijão');
      expect(feijao.concluido, isFalse);
      expect(feijao.quantidade, 3);
    },
  );

  test('deve_substituir_quando_unidade_diferente_no_lote', () async {
    final lista = await repo.criarLista(titulo: 'Lote2', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 2);

    await repo.adicionarItensDedup(lista.id, [
      itemLote('arroz', quantidade: 1, unidade: Unidade.kg),
    ]);

    final itens = await repo.watchItensDaLista(lista.id).first;
    final arroz = itens.single;
    expect(arroz.quantidade, 1);
    expect(arroz.unidade, Unidade.kg);
  });

  test(
    'deve_copiar_pendentes_com_ordem_sequencial_quando_duplicar_lista',
    () async {
      final origem = await repo.criarLista(titulo: 'Origem', donoId: 'user-a');
      await repo.adicionarItem(listaId: origem.id, nome: 'A');
      await repo.adicionarItem(listaId: origem.id, nome: 'B');
      await repo.adicionarItem(
        listaId: origem.id,
        nome: 'C',
        precoCentavos: 500,
      );

      final nova = await repo.duplicarLista(
        origemId: origem.id,
        titulo: 'Copia',
        donoId: 'user-a',
      );

      final itens = await repo.watchItensDaLista(nova.id).first;
      expect(itens.map((i) => i.nome), ['A', 'B', 'C']);
      expect(itens.map((i) => i.ordem), [0, 1, 2]);
      expect(itens.last.precoCentavos, 500);
    },
  );
}
