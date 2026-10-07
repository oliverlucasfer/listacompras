import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/data/orcamento_categoria_repository.dart';

void main() {
  test('deve_exportar_listas_e_itens_ativos_quando_ha_dados', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final lista = await listas.criarLista(titulo: 'Mercado', donoId: 'local');
    await listas.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final json = await BackupRepository(db).exportarJson();
    final mapa = jsonDecode(json) as Map<String, dynamic>;

    expect(mapa['versao'], 2);
    expect((mapa['listas'] as List), hasLength(1));
    expect((mapa['itens'] as List), hasLength(1));
    expect((mapa['historicoPrecos'] as List), isEmpty);
    expect((mapa['idas'] as List), isEmpty);
    expect((mapa['itensIda'] as List), isEmpty);
    expect((mapa['orcamentoCategoria'] as List), isEmpty);
  });

  test('deve_exportar_orcamento_por_categoria_quando_definido', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await LimitesCategoriaRepository(
      db,
    ).definir(CategoriaItem.bebidas, centavos: 5000);

    final json = await BackupRepository(db).exportarJson();
    final mapa = jsonDecode(json) as Map<String, dynamic>;

    final orcamento = (mapa['orcamentoCategoria'] as List).single as Map;
    expect(orcamento['categoria'], 'bebidas');
    expect(orcamento['limite_centavos'], 5000);
  });

  test(
    'deve_exportar_lista_excluida_com_seus_itens_quando_soft_delete',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final listas = ListasRepository(db);
      final lista = await listas.criarLista(titulo: 'Mercado', donoId: 'local');
      await listas.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
      await listas.excluirLista(lista.id);

      final json = await BackupRepository(db).exportarJson();
      final mapa = jsonDecode(json) as Map<String, dynamic>;

      expect((mapa['listas'] as List), hasLength(1));
      expect((mapa['itens'] as List), hasLength(1));
      expect(
        (mapa['listas'] as List).single['deletado_em'],
        isNotNull,
        reason: 'o backup é fiel ao banco',
      );
    },
  );
}
