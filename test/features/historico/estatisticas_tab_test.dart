import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
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

  testWidgets('deve_mostrar_estatisticas_quando_ha_idas', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final i = await listas.adicionarItem(
      listaId: l.id,
      nome: 'Arroz',
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
      precoCentavos: 500,
    );
    await listas.editarItem(i.id, concluido: true);
    await historico.finalizar(l.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Gasto por categoria'), findsOneWidget);
    expect(find.text('Itens mais comprados'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget, reason: 'item mais comprado');
    expect(
      find.text('Mercearia'),
      findsOneWidget,
      reason: 'categoria agregada',
    );
    expect(
      find.textContaining('R\$ 10,00'),
      findsWidgets,
      reason: '2 kg × R\$ 5,00 = R\$ 10,00 agregado nas seções',
    );
    await fechar(tester);
  });

  testWidgets('deve_mostrar_grafico_quando_item_tem_2_compras', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);

    Future<void> finalizarIda(String titulo, int centavos) async {
      final l = await listas.criarLista(titulo: titulo, donoId: 'local');
      final i = await listas.adicionarItem(
        listaId: l.id,
        nome: 'Arroz',
        quantidade: 1,
        unidade: Unidade.kg,
        categoria: CategoriaItem.mercearia,
        precoCentavos: centavos,
      );
      await listas.editarItem(i.id, concluido: true);
      await historico.finalizar(l.id);
    }

    await finalizarIda('Semana', 500);
    await finalizarIda('Mes', 700);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arroz').last);
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('R\$ 5,00'), findsWidgets);
    expect(find.textContaining('R\$ 7,00'), findsWidgets);
    await fechar(tester);
  });
}
