import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/ui/modal_finalizar_compra.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  testWidgets('deve_finalizar_e_registrar_quando_confirmado', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final item = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(item.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // A tela real observa o provider (botão de rodapé); sem o
                  // watch o stream do Drift não emite sob o pump do teste.
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
    // Dialogo pos-finalizar: manter a lista.
    await tester.tap(find.text('Manter a lista'));
    await tester.pumpAndSettle();

    expect((await db.select(db.idaCompra).get()), hasLength(1));
    expect((await db.select(db.itemIda).get()), hasLength(1));

    // Desmonta para cancelar o timer do snackbar (padrão dos testes da tela).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
