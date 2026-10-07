import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late HistoricoComprasRepository historico;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    historico = HistoricoComprasRepository(db);
  });
  tearDown(() => db.close());

  test('deve_gravar_snapshot_dos_concluidos_quando_finaliza', () async {
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final comprado = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
      precoCentavos: 549,
    );
    await listas.itens.editarItem(comprado.id, concluido: true);
    await listas.itens.adicionarItem(listaId: l.id, nome: 'Pendente');

    final ida = await historico.finalizar(l.id);

    expect(ida.titulo, 'Semana');
    expect(ida.itensCount, 1);
    final itens = await historico.itensDaIda(ida.id);
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.unidade, Unidade.kg);
    expect(itens.single.categoria, CategoriaItem.mercearia);
    expect(itens.single.precoCentavos, 549);
  });

  test('deve_somar_somente_itens_com_preco_quando_calcula_total', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      precoCentavos: 500,
    );
    final b = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Sem preço',
    );
    await listas.itens.editarItem(a.id, concluido: true);
    await listas.itens.editarItem(b.id, concluido: true);

    final ida = await historico.finalizar(l.id);
    expect(ida.itensCount, 2);
    expect(ida.totalCentavos, 1000);
  });

  test('deve_falhar_quando_nao_ha_concluidos', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    await listas.itens.adicionarItem(listaId: l.id, nome: 'Pendente');
    await expectLater(historico.finalizar(l.id), throwsStateError);
    expect(await db.select(db.idaCompra).get(), isEmpty);
  });

  test('deve_listar_idas_mais_recentes_primeiro', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.itens.adicionarItem(listaId: l.id, nome: 'A');
    await listas.itens.editarItem(a.id, concluido: true);
    await historico.finalizar(l.id);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await historico.finalizar(l.id);
    final idas = await historico.watchIdas().first;
    expect(idas, hasLength(2));
    expect(idas.first.finalizadaEm.isAfter(idas.last.finalizadaEm), isTrue);
  });

  test('deve_calcular_resumo_quando_ha_idas', () async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final a = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'A',
      quantidade: 1,
      precoCentavos: 300,
    );
    await listas.itens.editarItem(a.id, concluido: true);
    await historico.finalizar(l.id);
    await historico.finalizar(l.id); // mesma ida, 2 registros
    final r = await historico.resumo();
    expect(r.nIdas, 2);
    expect(r.totalGeralCentavos, 600);
    expect(r.ticketMedioCentavos, 300);
  });
}
