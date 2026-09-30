import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  /// Desmonta a árvore dentro do teste: o dispose do StreamProvider cancela
  /// streams do Drift, que agendam um Timer(0) — o pump seguinte o consome,
  /// evitando "Timer is still pending" no teardown do binding.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_mostrar_vazio_quando_sem_idas', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma compra finalizada ainda.'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_listar_ida_quando_existe', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final i = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(i.id, concluido: true);
    await historico.finalizar(l.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Semana'), findsOneWidget);
    expect(find.textContaining(RegExp(r'· 1 item$')), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_atualizar_resumo_quando_nova_ida_finalizada', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final i = await listas.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 1,
      precoCentavos: 300,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('R\$ 0,00'),
      findsNWidgets(2),
      reason: 'total e ticket zerados antes de qualquer ida',
    );

    await listas.editarItem(i.id, concluido: true);
    await historico.finalizar(l.id);
    await tester.pumpAndSettle();

    expect(
      find.text('R\$ 3,00'),
      findsNWidgets(3),
      reason:
          'o resumo (total + ticket) acompanha a nova ida sem recarregar a '
          'tela; a lista também mostra o total da ida',
    );
    expect(find.text('1'), findsOneWidget, reason: 'nº de idas atualizado');
    await fechar(tester);
  });
}
