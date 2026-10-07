import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/historico/ui/modal_finalizar_compra.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

import '../../support/app_teste.dart';

void main() {
  /// Cria uma lista com 1 item concluído e monta um botão que abre o modal.
  /// O `ref.watch` imita a tela real (botão de rodapé): sem ele o stream do
  /// Drift não emite sob o pump do teste.
  Future<({AppDatabase db, String listaId})> subir(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final item = await listas.itens.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.itens.editarItem(item.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(
          Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(itensDaListaProvider(l.id));
                  return TextButton(
                    onPressed: () => abrirFinalizarCompra(context, ref, l.id),
                    child: const Text('abrir'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar compra'));
    await tester.pumpAndSettle();
    return (db: db, listaId: l.id);
  }

  /// Desmonta para cancelar o timer do snackbar (padrão dos testes da tela).
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_finalizar_e_registrar_quando_confirmado', (tester) async {
    final r = await subir(tester);

    // Dialogo pos-finalizar: manter a lista.
    await tester.tap(find.text('Manter a lista'));
    await tester.pumpAndSettle();

    expect((await r.db.select(r.db.idaCompra).get()), hasLength(1));
    expect((await r.db.select(r.db.itemIda).get()), hasLength(1));

    // "Manter a lista" não mexe na lista: o item concluído segue ativo.
    final ativos = (await r.db.select(r.db.itemLocal).get()).where(
      (i) => i.listaId == r.listaId && i.deletadoEm == null,
    );
    expect(ativos, hasLength(1));
    expect(ativos.single.concluido, isTrue);

    await fechar(tester);
  });

  testWidgets('deve_limpar_concluidos_quando_escolhe_limpar', (tester) async {
    final r = await subir(tester);

    await tester.tap(find.text('Limpar concluídos'));
    await tester.pumpAndSettle();

    // A ida é registrada antes de limpar a lista.
    expect((await r.db.select(r.db.idaCompra).get()), hasLength(1));
    expect((await r.db.select(r.db.itemIda).get()), hasLength(1));

    // `limparConcluidos` faz soft delete: nenhum item ativo (deletado_em NULL)
    // resta na lista.
    final linhas = await r.db.select(r.db.itemLocal).get();
    final ativos = linhas.where(
      (i) => i.listaId == r.listaId && i.deletadoEm == null,
    );
    expect(ativos, isEmpty);

    await fechar(tester);
  });

  test('deve_gravar_todos_os_itens_quando_finalizar', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);

    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final a = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      precoCentavos: 500,
    );
    final b = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Feijão',
      quantidade: 1,
      precoCentavos: 800,
    );
    final c = await listas.itens.adicionarItem(
      listaId: l.id,
      nome: 'Café',
      quantidade: 3,
      precoCentavos: 200,
    );
    await listas.itens.editarItem(a.id, concluido: true);
    await listas.itens.editarItem(b.id, concluido: true);
    await listas.itens.editarItem(c.id, concluido: true);

    final ida = await historico.finalizar(l.id);

    final itens = await historico.itensDaIda(ida.id);
    expect(itens, hasLength(3));
    expect(itens.map((i) => i.nome).toSet(), {'Arroz', 'Feijão', 'Café'});
    expect(ida.itensCount, 3);
    expect(ida.totalCentavos, 2400);
  });
}
