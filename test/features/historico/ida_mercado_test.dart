import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<String> listaComConcluido() async {
    final l = await listas.criarLista(titulo: 'X', donoId: 'local');
    final i = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(i.id, concluido: true);
    return l.id;
  }

  test('deve_gravar_mercado_quando_finaliza_com_mercado', () async {
    final id = await listaComConcluido();
    final ida = await historico.finalizar(id, mercado: 'Mercado A');
    expect(ida.mercado, 'Mercado A');
    final lido = await historico.ida(ida.id);
    expect(lido!.mercado, 'Mercado A');
  });

  test('deve_deixar_mercado_nulo_quando_nao_informado', () async {
    final id = await listaComConcluido();
    final ida = await historico.finalizar(id);
    expect(ida.mercado, isNull);
  });

  test('deve_deixar_mercado_nulo_quando_apenas_espacos', () async {
    final id = await listaComConcluido();
    final ida = await historico.finalizar(id, mercado: '   ');
    expect(ida.mercado, isNull);
  });
}
