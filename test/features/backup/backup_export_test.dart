import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_exportar_listas_e_itens_ativos_quando_ha_dados', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final lista = await listas.criarLista(titulo: 'Mercado', donoId: 'local');
    await listas.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final json = await BackupRepository(db).exportarJson();
    final mapa = jsonDecode(json) as Map<String, dynamic>;

    expect(mapa['versao'], 1);
    expect((mapa['listas'] as List), hasLength(1));
    expect((mapa['itens'] as List), hasLength(1));
    expect((mapa['historicoPrecos'] as List), isEmpty);
  });
}
