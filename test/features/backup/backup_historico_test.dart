import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_restaurar_idas_e_itens_quando_backup_v2', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    final listas = ListasRepository(origem);
    final historico = HistoricoComprasRepository(origem);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final item = await listas.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      precoCentavos: 500,
    );
    await listas.editarItem(item.id, concluido: true);
    await historico.finalizar(l.id);
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    final idas = await destino.select(destino.idaCompra).get();
    final itens = await destino.select(destino.itemIda).get();
    expect(idas, hasLength(1));
    expect(idas.single.titulo, 'Semana');
    expect(idas.single.totalCentavos, 1000, reason: '2 × R\$ 5,00');
    expect(itens, hasLength(1));
    expect(itens.single.idaId, idas.single.id);
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.precoCentavos, 500);
  });

  test('deve_importar_backup_v1_sem_idas_quando_retrocompativel', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const json =
        '{"versao":1,"exportadoEm":"2026-01-01T00:00:00Z",'
        '"listas":[],"itens":[],"historicoPrecos":[]}';
    await BackupRepository(db).importarJson(json);
    expect(await db.select(db.idaCompra).get(), isEmpty);
    expect(await db.select(db.itemIda).get(), isEmpty);
  });
}
