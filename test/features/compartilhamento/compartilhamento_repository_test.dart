import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/data/compartilhamento_repository.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late CompartilhamentoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    repo = CompartilhamentoRepository(db);
  });

  tearDown(() => db.close());

  test('deve_exportar_titulo_e_todos_os_itens_quando_exporta', () async {
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    await listas.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
    );
    final comprado = await listas.adicionarItem(listaId: l.id, nome: 'Leite');
    await listas.editarItem(comprado.id, concluido: true);

    final compartilhada = await repo.exportarLista(l.id);
    expect(compartilhada.titulo, 'Semana');
    expect(compartilhada.itens.map((i) => i.nome), ['Arroz', 'Leite']);
    expect(compartilhada.itens.last.concluido, isTrue);
  });

  test('deve_criar_lista_nova_com_uuids_novos_quando_importa', () async {
    final origem = const ListaCompartilhada(
      titulo: 'Recebida',
      itens: [
        ItemCompartilhado(
          nome: 'Arroz',
          quantidade: 2,
          unidade: Unidade.kg,
          categoria: CategoriaItem.mercearia,
          concluido: false,
          ordem: 0,
        ),
      ],
    );

    final nova = await repo.importarLista(origem, titulo: 'Recebida');

    final listas0 = await db.select(db.listaLocal).get();
    expect(listas0, hasLength(1));
    expect(nova.id, isNotEmpty);
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.id, isNotEmpty);
    expect(itens.single.listaId, nova.id);
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.concluido, isFalse);
  });

  test('deve_preservar_concluido_e_preco_quando_importa', () async {
    final origem = const ListaCompartilhada(
      titulo: 'X',
      itens: [
        ItemCompartilhado(
          nome: 'Leite',
          quantidade: 1,
          unidade: Unidade.un,
          categoria: CategoriaItem.laticinios,
          concluido: true,
          ordem: 0,
          precoCentavos: 549,
        ),
      ],
    );
    final nova = await repo.importarLista(origem, titulo: 'X');
    final item = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(nova.id))).getSingle();
    expect(item.concluido, isTrue);
    expect(item.precoCentavos, 549);
    expect(item.categoria, 'laticinios');
  });

  test('deve_usar_o_dono_local_quando_importa', () async {
    final nova = await repo.importarLista(
      const ListaCompartilhada(titulo: 'X', itens: []),
      titulo: 'X',
    );
    expect(nova.donoId, 'local');
  });
}
