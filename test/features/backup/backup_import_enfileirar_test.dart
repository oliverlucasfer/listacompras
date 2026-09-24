import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

String _backupJson({
  List<Map<String, Object?>> listas = const [],
  List<Map<String, Object?>> itens = const [],
  List<Map<String, Object?>> historico = const [],
}) => jsonEncode({
  'versao': 1,
  'exportadoEm': '2026-01-01T00:00:00.000Z',
  'listas': listas,
  'itens': itens,
  'historicoPrecos': historico,
});

Map<String, Object?> _lista({
  required String id,
  String titulo = 'Mercado',
  String updatedAt = '2100-01-01T00:00:00Z',
  String? arquivadaEm,
}) => {
  'id': id,
  'titulo': titulo,
  'dono_id': 'user-a',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': updatedAt,
  'deletado_em': null,
  'arquivada_em': arquivadaEm,
  'orcamento_centavos': null,
};

Map<String, Object?> _item({
  required String id,
  required String listaId,
  String nome = 'Arroz',
  String updatedAt = '2100-01-01T00:00:00Z',
}) => {
  'id': id,
  'lista_id': listaId,
  'nome': nome,
  'quantidade': 1.0,
  'unidade': 'un',
  'categoria': 'outros',
  'preco_centavos': null,
  'concluido': false,
  'ordem': 0,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': updatedAt,
  'deletado_em': null,
};

void main() {
  test(
    'deve_enfileirar_mutacao_por_registro_quando_enfileirar_ligado',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await BackupRepository(db, enfileirar: true).importarJson(
        _backupJson(
          listas: [_lista(id: 'lista-1', arquivadaEm: '2026-02-01T00:00:00Z')],
          itens: [_item(id: 'item-1', listaId: 'lista-1')],
        ),
      );

      final pendentes = await db.select(db.mutacaoPendente).get();
      expect(pendentes, hasLength(2));

      final listaMut = pendentes.singleWhere((m) => m.tabela == 'listas');
      expect(listaMut.registroId, 'lista-1');
      expect(listaMut.listaId, 'lista-1');
      expect(listaMut.operacao, 'INSERT');
      final listaPayload = jsonDecode(listaMut.payload) as Map<String, Object?>;
      expect(
        DateTime.parse(listaPayload['updated_at'] as String).toUtc(),
        DateTime.parse('2100-01-01T00:00:00Z').toUtc(),
      );
      expect(listaPayload['arquivada_em'], isNotNull);

      final itemMut = pendentes.singleWhere((m) => m.tabela == 'itens_lista');
      expect(itemMut.registroId, 'item-1');
      expect(itemMut.listaId, 'lista-1');
      expect(itemMut.operacao, 'INSERT');
      final itemPayload = jsonDecode(itemMut.payload) as Map<String, Object?>;
      expect(
        DateTime.parse(itemPayload['updated_at'] as String).toUtc(),
        DateTime.parse('2100-01-01T00:00:00Z').toUtc(),
      );
    },
  );

  test('deve_nao_enfileirar_quando_enfileirar_desligado', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await BackupRepository(db).importarJson(
      _backupJson(
        listas: [_lista(id: 'lista-1')],
        itens: [_item(id: 'item-1', listaId: 'lista-1')],
      ),
    );

    expect(await db.select(db.listaLocal).get(), hasLength(1));
    expect(await db.select(db.mutacaoPendente).get(), isEmpty);
  });

  test('deve_nao_enfileirar_registro_pulado_pelo_lww', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await ListasRepository(
      db,
      enfileirarMutacoes: false,
    ).criarLista(titulo: 'Local', donoId: 'user-a');
    final local = (await db.select(db.listaLocal).get()).single;

    await BackupRepository(db, enfileirar: true).importarJson(
      _backupJson(
        listas: [
          _lista(
            id: local.id,
            titulo: 'Antigo',
            updatedAt: '2000-01-01T00:00:00Z',
          ),
        ],
      ),
    );

    expect(
      (await db.select(db.listaLocal).get()).single.titulo,
      'Local',
      reason: 'backup mais antigo não deve sobrescrever o local',
    );
    expect(await db.select(db.mutacaoPendente).get(), isEmpty);
  });

  test('deve_nunca_enfileirar_historico_precos', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await BackupRepository(db, enfileirar: true).importarJson(
      _backupJson(
        historico: [
          {
            'nome_normalizado': 'arroz',
            'preco_centavos': 1200,
            'unidade': 'un',
            'registrado_em': '2026-01-01T00:00:00Z',
          },
        ],
      ),
    );

    expect(await db.select(db.historicoPrecoLocal).get(), hasLength(1));
    expect(await db.select(db.mutacaoPendente).get(), isEmpty);
  });
}
